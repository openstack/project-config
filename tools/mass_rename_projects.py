#! /usr/bin/env python
#
# Copyright (c) 2015 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This takes a list of projects from stdin in the format of
# aeromancer
# anvil
# blazar
#
# and renames stackforge/aeromancer, stackforge/anvil, and stackforge/blazar
# to openstack/aeromancer, openstack/anvil, and openstack/blazar respectively
# in
#     gerrit/projects.yaml
#     gerritbot/channels.yaml
#     zuul/layout.yaml
#     jenkins/jobs/*
# , as well as invoking a series of `git mv` and `git add` commands for
# renaming acl files and otherwise staging a single commit

import functools
import locale
import os
import subprocess
import sys
import tempfile
import yaml
from collections import OrderedDict
import projectconfig_yamllib as pcy

def build_list(prefix, renamelist):
    return map(lambda x: "%s/%s" % (prefix, x), renamelist)

def load_yaml_data(filename):
    data = yaml.load(open(filename)) # TODO raise error if open fails
    return data

class ProjectData:
    def __init__(self, data, gitmoves):
        self.data = data
        self.gitmoves = gitmoves

def build_project_data(stacklist, data):
    gitmoves = {}

    for project in data:
        sproject = project['project']
        oproject = sproject.replace('stackforge','openstack',1)
        if sproject in stacklist:
            project['project'] = oproject
            try:
                old = project['acl-config']
                new = old.replace('stackforge','openstack',1)
                project['acl-config'] = new
                gitmoves[old.replace('/home/gerrit2','gerrit')] = new.replace('/home/gerrit2','gerrit')
            except KeyError:
                aclfile = "gerrit/acls/%s.config" % sproject
                if os.path.isfile(aclfile):
                    gitmoves[aclfile] = aclfile.replace('stackforge','openstack',1)

    # this is mildly disgusting
    sorteddata = sorted(data, key=lambda t: locale.strxfrm(t['project'].lower().replace("_", "}")))
    return ProjectData(sorteddata, gitmoves)

def rename_in_projects_yaml(stacklist, data):

    errors = False # TODO add error checking

    newdata = build_project_data(stacklist,data).data

    with open('gerrit/projects.yaml', 'w') as out: # TODO raise error if open fails
        out.write(yaml.dump(newdata, default_flow_style=False,
                            Dumper=pcy.IndentedDumper, width=80))

    return True

def load_channel_data(filename):
    data = yaml.load(open(filename)) # TODO raise error if open fails
    return data

def build_channel_data(stacklist, data):

    for k,v in data.items():
        newprojects = []
        for i in v['projects']:
            if i in stacklist:
                newprojects.append(i.replace('stackforge','openstack',1))
            else:
                newprojects.append(i)

            v['projects'] = sorted(newprojects)

    return data

def rename_in_channels_yaml(stacklist, ydata):

    errors = False # TODO add error handling

    data = build_channel_data(stacklist, ydata)

    with open('gerritbot/channels.yaml', 'w') as out:
        out.write('# This file is sorted alphabetically by channel name.\n')
        first = True
        for k, v in data.items():
            if not first:
                out.write('\n')
            first = False
            out.write(yaml.dump({k: v}, default_flow_style=False,
                                Dumper=pcy.IndentedDumper, width=80, indent=2))

    return True

def rename_with_sed(zuullayout, targetfile, stacklist, openlist):
    errors = False #TODO add error handling

    h, fn = tempfile.mkstemp()
    with os.fdopen(h, 'w') as out:
        for f,t in zip(stacklist,openlist):
            if zuullayout:
                out.write("s#name: %s[[:space:]]*$#name: %s#;\n" % (f,t))
            else:
                out.write("s#%s\\([ /]\\)#%s\\1#;\n" % (f,t))
                out.write("s#%s$#%s#;\n" % (f,t))
        out.flush()
        subprocess.call(['sed', '-f', fn, '-i', targetfile])
    os.unlink(fn)

    return True

filesToChange = {
        'gerrit/projects.yaml'   :  {   'data': False,
                                        'func': rename_in_projects_yaml
                                    },
        'gerritbot/channels.yaml':  {   'data': False,
                                        'func': rename_in_channels_yaml
                                    },
        'zuul/layout.yaml'       :  {   'data': False,
                                        'func': functools.partial(rename_with_sed, True, 'zuul/layout.yaml')
                                    }
}

def main():
    locale.setlocale(locale.LC_COLLATE, 'C')

    yaml.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
                         pcy.construct_yaml_map)

    yaml.add_representer(OrderedDict, pcy.project_representer,
                         Dumper=pcy.IndentedDumper)

    if os.isatty(0):
        sys.stderr.write('You appear to be typing in the list of projects by hand rather than\n')
        sys.stderr.write('using file redirection or a pipe.  If this is your intent, send an\n')
        sys.stderr.write('EOF by typing Ctrl-D on a blank line after the complete list has\n')
        sys.stderr.write('been entered.\n\n')
    renamelist = [x.rstrip('\n') for x in sys.stdin.readlines()]
    stacklist = build_list('stackforge', renamelist)
    openlist = build_list('openstack', renamelist)
    pdata = build_project_data(stacklist, load_yaml_data('gerrit/projects.yaml'))

    filesToChange['zuul/layout.yaml']['data'] = openlist

    # because Python isn't lazy
    filesToChange['gerrit/projects.yaml']['data'] = pdata.data
    filesToChange['gerritbot/channels.yaml']['data'] = load_yaml_data('gerritbot/channels.yaml')

    for f in filesToChange:
        sys.stderr.write("working on %s\n" % f)
        filesToChange[f]['func'](stacklist, filesToChange[f]['data'])
        subprocess.call(['git', 'add', f])
        sys.stderr.write("updated %s\n" % f)

    for t in os.listdir('jenkins/jobs'):
        f = os.path.join('jenkins/jobs', t)
        sys.stderr.write("working on %s\n" % f)
        rename_with_sed(False, f, stacklist, openlist)
        subprocess.call(['git', 'add', f])
        sys.stderr.write("updated %s\n" % f)

    for s,o in pdata.gitmoves.items():
        sys.stderr.write("renaming %s to %s\n" % (s, o))
        subprocess.call(['git', 'mv', s, o])

if __name__ == '__main__':
    main()
