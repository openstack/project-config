#!/usr/bin/env python3

#
# Copyright 2020 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#

# glob all .whl files in a directory, and make a index.html page
# in PEP503 (https://www.python.org/dev/peps/pep-0503/) format

import argparse
import datetime
import email
import glob
import hashlib
import html
import logging
import sys
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('outfile', nargs='?', default='-', help="output filename")
parser.add_argument('-d', '--debug', dest="debug", action='store_true')
args = parser.parse_args()

level = logging.DEBUG if args.debug else logging.INFO
logging.basicConfig(level=level)


class NotAWheelException(Exception):
    pass


class NoMetadataException(Exception):
    pass


class NoRequirementsException(Exception):
    pass


class BadFormatException(Exception):
    pass


def get_requirements(filename):
    # This is an implementation of the description on finding
    # requirements from a wheel provided by chrahunt at:
    #  https://github.com/pypa/pip/issues/7586#issuecomment-573534655
    with zipfile.ZipFile(filename) as zip:
        metadata = None

        names = zip.namelist()
        for name in names:
            if name.endswith('.dist-info/METADATA'):
                metadata = zip.open(name)
                # finish loop and sanity check we got the right one?
                break

        if not metadata:
            return NoMetadataException

        parsed = email.message_from_binary_file(metadata)
        requirements = parsed.get_all('Requires-Python')

        if not requirements:
            raise NoRequirementsException

        if len(requirements) > 1:
            print("Multiple requirements headers found?")
            raise BadFormatException

        return html.escape(requirements[0])


def get_sha256(filename):
    sha256 = hashlib.sha256()
    with open(filename, "rb") as f:
        for b in iter(lambda: f.read(4096), b''):
            sha256.update(b)
    return(sha256.hexdigest())


output = '''<html>
  <head>
    <title>Links</title>
  </head>
  <body>
'''

files = glob.glob('*.whl')
for f in files:

    requirements = ''
    try:
        logging.debug("Checking for requirements of : %s" % f)
        requirements = get_requirements(f)
        logging.debug("requirements are: %s" % requirements)
    # NOTE(ianw): i'm not really sure if any of these should be
    # terminal, as it would mean pip can't read the file anyway.  Just
    # log for now.
    except NoMetadataException:
        logging.debug("no metadata")
        pass
    except NoRequirementsException:
        logging.debug("no python requirements")
        pass
    except BadFormatException:
        logging.debug("Could not open")
        pass

    sha256 = get_sha256(f)
    logging.debug("sha256 for %s: %s" % (f, sha256))

    output += f'    <a href="{f}#sha256={sha256}"'
    if requirements:
        output += f' data-requires-python="{requirements}" '
    output += f'>{f}</a>\n'

output += '''  </body>
</html>
'''
now = datetime.datetime.now()
output += '<!-- last update: %s -->\n' % now.isoformat()

logging.debug("Final output write")

if args.outfile == '-':
    outfile = sys.stdout
else:
    outfile = open(args.outfile, "w")
    logging.debug("Output going to: %s" % args.outfile)

outfile.write(output)

logging.debug("Done!")
