# Copyright (c) 2015 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

from io import BytesIO
from lxml import etree
import os
import re
import requests
import sys
try:
    import configparser
except ImportError:
    import ConfigParser as configparser
try:
    from urllib.parse import urljoin
except ImportError:
    from urlparse import urljoin


class IniConfig:
    """Object that stores zanata.ini configuration

    Read zanata.ini and make its values available.

    Attributes:
    inifile: The path to the ini file to load values from.

    """
    def __init__(self, inifile):
        self.inifile = inifile
        self._load_config()

    def _load_config(self):
        """Load configuration from the zanata.ini file

        Parses the ini file and stores its data.

        """
        if not os.path.isfile(self.inifile):
            sys.exit('zanata.ini file not found.')
        config = configparser.ConfigParser()
        try:
            config.read(self.inifile)
        except configparser.Error:
            sys.exit('zanata.ini could not be parsed, please check format.')
        for item in config.items('servers'):
            item_type = item[0].split('.')[1]
            if item_type in ('username', 'key', 'url'):
                setattr(self, item_type, item[1])


class ProjectConfig:
    """Object that stores zanata.xml per-project configuration.

    Given an existing zanata.xml, read in the values and make
    them accessible. Otherwise, write out a zanata.xml file
    for the project given the supplied values.

    Attributes:
    zconfig (IniConfig): zanata.ini values
    xmlfile (str): path to zanata.xml to read or write
    rules (list): list of two-ples with pattern and rules
    """
    def __init__(self, zconfig, xmlfile, rules, **kwargs):
        self.zc = zconfig
        self.url = zconfig.url
        self.username = zconfig.username
        self.key = zconfig.key
        self.xmlfile = xmlfile
        self.rules = self._parse_rules(rules)
        if os.path.isfile(os.path.abspath(xmlfile)):
            self._load_config()
        else:
            for key, value in kwargs.items():
                setattr(self, key, value)
            self._create_config()

    def _get_tag_prefix(self, root):
        """XML utility method

        Get the namespace of the XML file so we can
        use it to search for tags.

        """
        return '{%s}' % etree.QName(root).namespace

    def _parse_rules(self, rules):
        """Parse a two-ple of pattern, rule.

        Returns a list of dictionaries with 'pattern' and 'rule' keys.
        """
        return [{'pattern': rule[0], 'rule': rule[1]} for rule in rules]

    def _load_config(self):
        """Load configuration from an existing zanata.xml

        Load and store project configuration from zanata.xml

        """
        try:
            with open(self.xmlfile, 'r') as f:
                xml = etree.parse(f)
        except IOError:
            sys.exit('Cannot load zanata.xml for this project')
        except etree.ParseError:
            sys.exit('Cannot parse zanata.xml for this project')
        root = xml.getroot()
        tag_prefix = self._get_tag_prefix(root)
        self.project = root.find('%sproject' % tag_prefix).text
        self.version = root.find('%sproject-version' % tag_prefix).text
        self.srcdir = root.find('%ssrc-dir' % tag_prefix).text
        self.txdir = root.find('%strans-dir' % tag_prefix).text
        rules = root.find('%srules' % tag_prefix)
        self.rules = self._parse_rules([(tag.get('pattern', tag.text))
                                       for tag in rules.getchildren()])

    def _create_config(self):
        """Create zanata.xml

        Use the supplied parameters to create zanata.xml by downloading
        a base version of the file and adding customizations.

        """
        xml = self._fetch_zanata_xml()
        self._add_configuration(xml)
        self._write_xml(xml)

    def _query_zanata_api(self, url_fragment, verify=False):
        """Fetch a URL from Zanata

        Attributes:
        url_fragment: A URL fragment that will be joined to the server URL.
        verify (bool): Verify the SSL certificate from the Zanata server.
        """
        request_url = urljoin(self.url, url_fragment)
        try:
            headers = {'Accept': 'application/xml',
                       'X-Auth-User': self.username,
                       'X-Auth-Token': self.key}
            r = requests.get(request_url, verify=verify, headers=headers)
        except requests.exceptions.ConnectionError:
            sys.exit("Connection error")
        if r.status_code != 200:
            sys.exit('Got status code %s for %s' %
                    (r.status_code, request_url))
        if not r.content:
            sys.exit('Did not recieve any data from %s' % request_url)
        return r.content

    def _fetch_zanata_xml(self, verify=False):
        """Get base zanata.xml

        Download a basic version of the configuration for the project
        using Zanata's REST API.

        Attributes:
        verify (bool): Verify the SSL certificate from the Zanata server.
                       Default false.
        """
        project_config = self._query_zanata_api(
            '/rest/projects/p/%s/iterations/i/%s/config'
            % (self.project, self.version), verify=verify)
        p = etree.XMLParser(remove_blank_text=True)
        try:
            xml = etree.parse(BytesIO(project_config), p)
        except etree.ParseError:
            sys.exit('Error parsing xml output')
        return xml

    def _add_configuration(self, xml):
        """
        Insert additional configuration

        Add locale mapping rules to the base zanata.xml retrieved from
        the server.

        Args:
        xml (etree): zanata.xml file contents

        """
        root = xml.getroot()
        s = etree.SubElement(root, 'src-dir')
        s.text = self.srcdir
        t = etree.SubElement(root, 'trans-dir')
        t.text = self.txdir
        rules = etree.SubElement(root, 'rules')
        for rule in self.rules:
            new_rule = etree.SubElement(rules, 'rule')
            new_rule.attrib['pattern'] = rule['pattern']
            new_rule.text = rule['rule']
        tag_prefix = self._get_tag_prefix(root)
        locale_sub = root.find('%slocales' % tag_prefix)
        locale_elements = locale_sub.findall('%slocale' % tag_prefix)
        locales = [x.text for x in locale_elements]
        # Work out which locales are trivially mappable to the names we
        # typically use (for example, en-gb vs en_GB) and add these mappings
        # to the configuration.
        for l in locales:
            parts = l.split('-')
            if len(parts) > 1:
                parts[1] = parts[1].upper()
                e = etree.SubElement(locale_sub, 'locale')
                e.attrib['map-from'] = '_'.join(parts)
                e.text = l
        # TODO - add hardcoded mappings for additional
        # language names (for example zh-hans-*) ?
        # Work around https://bugzilla.redhat.com/show_bug.cgi?id=1219624
        # by removing port number in URL if it's there
        url = root.find('%surl' % tag_prefix)
        url.text = re.sub(':443', '', url.text)

    def _write_xml(self, xml):
        """Write xml

        Write out xml to zanata.xml.

        """
        try:
            xml.write(self.xmlfile, pretty_print=True)
        except IOError:
            sys.exit('Error writing zanata.xml.')
