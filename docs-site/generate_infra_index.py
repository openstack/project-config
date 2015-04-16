#!/usr/bin/env python
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Read the infra-documents.yaml file and generate the index.html file.
"""

from __future__ import print_function

import argparse
import os

import jinja2
import yaml


def render_template(template_filename, output_filename, template_context):
    with open(template_filename, 'r') as f:
        template = jinja2.Template(f.read())
    print('Writing %r' % output_filename)
    with open(output_filename, 'w') as f:
        f.write(template.render(**template_context))


parser = argparse.ArgumentParser()
parser.add_argument('-v', '--verbose',
                    dest='verbose',
                    default=False,
                    action='store_true',
                    )
parser.add_argument(
    'infile',
    help='Path to infra-documents.yaml',
)
args = parser.parse_args()

print('Reading documents data from %r' % args.infile)
infile = yaml.load(open(args.infile, 'r'))
template_path = os.path.dirname(args.infile)

template_context = {
    'documents': infile['documents'],
    'all': infile['documents']
}

outdir = os.path.join(template_path, 'output')
if not os.path.exists(outdir):
    os.makedirs(outdir)


for template_name, filename in [('infra-index.html.tmpl', 'index.html')]:
    render_template(os.path.join(template_path, template_name),
                    os.path.join(outdir, filename),
                    template_context)
