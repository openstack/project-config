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
import json
from lxml import etree
import os
import re
import requests
try:
    import configparser
except ImportError:
    import ConfigParser as configparser
try:
    from urllib.parse import urljoin
except ImportError:
    from urlparse import urljoin


class IniConfig(object):
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
            raise ValueError('zanata.ini file not found.')
        config = configparser.ConfigParser()
        try:
            config.read(self.inifile)
        except configparser.Error:
            raise ValueError('zanata.ini could not be parsed, please check '
                             'format.')
        for item in config.items('servers'):
            item_type = item[0].split('.')[1]
            if item_type in ('username', 'key', 'url'):
                setattr(self, item_type, item[1])


class ZanataRestService(object):
    def __init__(self, zconfig, accept='application/xml',
                 content_type='application/xml', verify=True):
        self.url = zconfig.url
        if "charset" not in content_type:
            content_type = "%s;charset=utf8" % content_type
        self.headers = {'Accept': accept,
                        'Content-Type': content_type,
                        'X-Auth-User': zconfig.username,
                        'X-Auth-Token': zconfig.key}
        self.verify = verify

    def _construct_url(self, url_fragment):
        return urljoin(self.url, url_fragment)

    def query(self, url_fragment, raise_errors=True):
        request_url = self._construct_url(url_fragment)
        try:
            r = requests.get(request_url, verify=self.verify,
                             headers=self.headers)
        except requests.exceptions.ConnectionError:
            raise ValueError('Connection error')
        if raise_errors and r.status_code != 200:
            raise ValueError('Got status code %s for %s' %
                             (r.status_code, request_url))
        if raise_errors and not r.content:
            raise ValueError('Did not receive any data from %s' % request_url)
        return r

    def push(self, url_fragment, data):
        request_url = self._construct_url(url_fragment)
        try:
            return requests.put(request_url, verify=self.verify,
                                headers=self.headers, data=json.dumps(data))
        except requests.exceptions.ConnectionError:
            raise ValueError('Connection error')


class ProjectConfig(object):
    """Object that stores zanata.xml per-project configuration.

    Write out a zanata.xml file for the project given the supplied values.

    Attributes:
    zconfig (IniConfig): zanata.ini values
    xmlfile (str): path to zanata.xml to read or write
    rules (list): list of two-ples with pattern and rules
    """
    def __init__(self, zconfig, xmlfile, rules, verify, **kwargs):
        self.rest_service = ZanataRestService(zconfig, verify=verify)
        self.xmlfile = xmlfile
        self.rules = self._parse_rules(rules)
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

    def _create_config(self):
        """Create zanata.xml

        Use the supplied parameters to create zanata.xml by downloading
        a base version of the file and adding customizations.

        """
        xml = self._fetch_zanata_xml()
        self._add_configuration(xml)
        self._write_xml(xml)

    def _fetch_zanata_xml(self):
        """Get base zanata.xml

        Download a basic version of the configuration for the project
        using Zanata's REST API.

        """
        r = self.rest_service.query(
            '/rest/projects/p/%s/iterations/i/%s/config'
            % (self.project, self.version))
        project_config = r.content
        p = etree.XMLParser(remove_blank_text=True)
        try:
            xml = etree.parse(BytesIO(project_config), p)
        except etree.ParseError:
            raise ValueError('Error parsing xml output')
        return xml

    def _add_configuration(self, xml):
        """Insert additional configuration

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
        if self.excludes:
            excludes = etree.SubElement(root, 'excludes')
            excludes.text = self.excludes
        tag_prefix = self._get_tag_prefix(root)
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
            raise ValueError('Error writing zanata.xml.')
