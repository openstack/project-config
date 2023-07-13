#!/usr/bin/env python3
#  Licensed under the Apache License, Version 2.0 (the "License"); you may
#  not use this file except in compliance with the License. You may obtain
#  a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#  License for the specific language governing permissions and limitations
#  under the License.

# Usage: normalize_acl.py acl.config [transformation [transformation [...]]]
#
# Transformations are described in user-facing detail below
#
# Transformations:
# all Report all transformations as a dry run.
# apply Apply all transformations to the file directly.
# 0 - dry run (default, print to stdout rather than modifying file in place)
# 1 - strip/condense whitespace and sort (implied by any other transformation)
# 2 - get rid of unneeded create on refs/tags
# 3 - remove any project.stat{e,us} = active since it's a default or a typo
# 4 - strip default *.owner = group Administrators permissions
# 5 - sort the exclusiveGroupPermissions group lists
# 6 - replace openstack-ci-admins and openstack-ci-core with infra-core
# 7 - add at least one core team, if no team is defined with special suffixes
#     like core, admins, milestone or Users
# 8 - fix All-Projects inheritance shadowed by exclusiveGroupPermissions
# 9 - Ensure submit requirements
#      * functions only noblock
#      * each label has a s-r block
# 10- Values should be indented with a hard tab, as that is the gerrit default
#

import re
import sys

# If adding a normalization step, add human-parsable description of it
# here.
NORMALIZATION_HELP = '''
One or more files have failed the Gerrit ACL normalization checks.  A
diff of the expected output is presented above.  You can reference this
with the following transformations to correct any problems.

The current transformations

1.  Whitespace should be stripped/condensed and keys should be
    alphabetically sorted.

2.  [access "refs/tags/*"] should not have create permissions

3.  No "project.stat{e,us} = active" since it's a default or a typo

4.  Remove default "*.owner = group" Administrators permissions

5.  The exclusiveGroupPermissions group lists should be sorted

6.  Old references to openstack-ci-admins and openstack-ci-core should
    now be infra-core

7.  There should be at least one core team, if no team is defined with
    special suffixes like core, admins, milestone or Users

8.  Whenever a project-specific ACL declares exclusiveGroupPermissions
    on some permission, it overrides standard permissions that would
    otherwise be inherited from All-Projects ACL.  These conditions
    must be duplicated into the project-specific rule to maintain
    standard behaviour.

9.  Labels must have submit-requirements
     - must have "function = NoBlock"
     - each label must have a corresponding submit-requirement block

10. Values should be indented with a hard tab, as that is the gerrit
    default; e.g.

    [section]
    	key1 = value
    	key2 = value
'''  # noqa: W191, E101

LAST_TRANSFORMATION = 10

aclfile = sys.argv[1]

# NOTE(ianw) : 2023-04-20 obviously we would not write any of this
# like this if we were starting fresh.  But this has grown from a
# simple thing into something difficult for people to deal with.  If
# we have any errors during the tox job, we use this to print out a
# help message.
if (aclfile == '-help'):
    print(NORMALIZATION_HELP)
    sys.exit(1)

try:
    transformations = sys.argv[2:]
    if transformations:
        RANGE_END = LAST_TRANSFORMATION + 1
        if transformations[0] == 'all':
            transformations = [str(x) for x in range(0, RANGE_END)]
        elif transformations[0] == 'apply':
            transformations = [str(x) for x in range(1, RANGE_END)]
except KeyError:
    transformations = []


def tokens(data):
    """Human-order comparison

    This handles embedded positive and negative integers, for sorting
    strings in a more human-friendly order."""
    data = data.replace('.', ' ').split()
    for n in range(len(data)):
        try:
            data[n] = int(data[n])
        except ValueError:
            pass
    return data


def normalize_boolean_ops(key, value):
    # Gerrit 3.6 takes lower-case "and/or" literally -- as in
    # you literally need to have and/or in the commit string.
    # Gerrit 3.7 fixes this, but let's standarise on capital
    # booleans
    if key in ('copyCondition', 'submittableIf', 'applicableIf'):
        value = value.replace(' and ', ' AND ')
        value = value.replace(' or ', ' OR ')
    return "%s = %s" % (key, value)


acl = {}
out = ''

valid_keys = {
    'abandon',
    'access',
    'applicableIf',
    'create',
    'createSignedTag',
    'copyCondition',
    'defaultValue',
    'delete',
    'description',
    'editHashtags',
    'exclusiveGroupPermissions',
    'forgeAuthor',
    'forgeCommitter',
    'function',
    'inheritFrom',
    'label-Allow-Post-Review',
    'label-Backport-Candidate',
    'label-Code-Review',
    'label-PTL-Approved',
    'label-Review-Priority',
    'label-Rollcall-Vote',
    'label-Workflow',
    'label-Verified',
    'mergeContent',
    'push',
    'pushMerge',
    'requireChangeId',
    'requireContributorAgreement',
    'state',
    'submit',
    'submittableIf',
    'toggleWipState',
    'value',
}

# push and label-* are handled specially and should not be in this list
group_keys = {
    'abandon',
    'create',
    'createSignedTag',
    'delete',
    'editHashtags',
    'forgeCommitter',
    'pushMerge',
    'submit',
    'toggleWipState',
}

if '0' in transformations or not transformations:
    dry_run = True
else:
    dry_run = False

aclfd = open(aclfile)
for line in aclfd:
    # condense whitespace to single spaces and get rid of leading/trailing
    line = re.sub(r'\s+', ' ', line).strip()
    # skip empty lines
    if not line:
        continue
    # this is a section heading
    if line.startswith('['):
        section = line.strip(' []')
        # use a list for this because some options can have the same "key"
        acl[section] = []
    # key=value lines
    elif '=' in line:
        acl[section].append(line)
        # Check for valid keys
        key, value = [x.strip() for x in line.split('=', 1)]
        if key not in valid_keys:
            raise Exception(
                '(%s) Unrecognized key "%s" in line: "%s"'
                % (aclfile, key, line))
        # group keywords, special handling for label-* votes and push +force
        values = [x.strip() for x in value.split(' ')]
        if ((key in group_keys and len(values) < 2)
                or (key.startswith("label-") and len(values) < 3)):
            raise Exception(
                '(%s) Not enough parameters in line: "%s"' % (aclfile, line))
        if ((key in group_keys and values[0] != "group")
                or (key.startswith("label-") and values[1] != "group")
                or (key == "push" and "group" not in values)):
            raise Exception(
                '(%s) Missing "group" keyword in line: "%s"' % (aclfile, line))

    # WTF
    else:
        raise Exception('Unrecognized line: "%s"' % line)
aclfd.close()

if '2' in transformations:
    for key in acl:
        if key.startswith('access "refs/tags/'):
            acl[key] = [
                x for x in acl[key]
                if not x.startswith('create = ')]

if '3' in transformations:
    try:
        acl['project'] = [x for x in acl['project'] if x not in
                          ('state = active', 'status = active')]
    except KeyError:
        pass

if '4' in transformations:
    for section in acl.keys():
        acl[section] = [x for x in acl[section]
                        if x != 'owner = group Administrators']

if '5' in transformations:
    for section in acl.keys():
        newsection = []
        for option in acl[section]:
            key, value = [x.strip() for x in option.split('=', 1)]
            if key == 'exclusiveGroupPermissions':
                newsection.append('%s = %s' % (
                    key, ' '.join(sorted(value.split()))))
            else:
                newsection.append(option)
        acl[section] = newsection

if '6' in transformations:
    for section in acl.keys():
        newsection = []
        for option in acl[section]:
            for group in ('openstack-ci-admins', 'openstack-ci-core'):
                option = option.replace('group %s' % group, 'group infra-core')
            newsection.append(option)
        acl[section] = newsection

if '7' in transformations:
    special_projects = (
        'ossa',
        'reviewday',
    )
    special_teams = (
        'admins',
        'Bootstrappers',
        'committee',
        'core',
        'maint',
        'Managers',
        'milestone',
        'packagers',
        'release',
        'Users',
    )
    for section in acl.keys():
        newsection = []
        for option in acl[section]:
            if ('refs/heads' in section and 'group' in option
                    and '-2..+2' in option
                    and not any(x in option for x in special_teams)
                    and not any(x in aclfile for x in special_projects)):
                option = '%s%s' % (option, '-core')
            newsection.append(option)
        acl[section] = newsection

if '8' in transformations:
    for section in acl.keys():
        newsection = []
        for option in acl[section]:
            newsection.append(option)
            key, value = [x.strip() for x in option.split('=', 1)]
            if key == 'exclusiveGroupPermissions':
                exclusives = value.split()
                # It's safe for these to be duplicates since we de-dup later
                if 'abandon' in exclusives:
                    newsection.append('abandon = group Change Owner')
                    newsection.append('abandon = group Project Bootstrappers')
                if 'label-Code-Review' in exclusives:
                    newsection.append('label-Code-Review = -2..+2 '
                                      'group Project Bootstrappers')
                    newsection.append('label-Code-Review = -1..+1 '
                                      'group Registered Users')
                if 'label-Workflow' in exclusives:
                    newsection.append('label-Workflow = -1..+1 '
                                      'group Project Bootstrappers')
                    newsection.append('label-Workflow = -1..+0 '
                                      'group Change Owner')
        acl[section] = newsection

# submit-requirements have taken over the role of "function" in labels
# since Gerrit 3.6.  We ensure that the only function in a label
# section now is the noop "NoBlock" function -- all labels now need to
# explicitly write their own submit-requirement.  e.g. for any
#  [label "Foo"]
# there should be a matching submit requirement section
#  [submit-requirement "Foo"]
# We can't really decide what the rules will be, so we just add the
# section with a dummy comment.
if '9' in transformations:
    missing_sr = {}
    for section in acl.keys():
        newsection = []
        if section.startswith("label "):
            label_name = section.split(' ')[1]
            sr_found = False
            for sr in acl.keys():
                if sr == 'submit-requirement %s' % (label_name):
                    sr_found = True
                    break
            if not sr_found:
                msg = ('# You must have a submit-requirement section for %s'
                       % label_name)
                missing_sr['submit-requirement %s' % label_name] = [msg]

            keys = []
            for option in acl[section]:
                key, value = [x.strip() for x in option.split('=', 1)]
                keys.append(key)
                # Insert an inline comment if the ACL uses an invalid function
                if key == 'function':
                    if value != 'NoBlock':
                        newsection.append(
                            '# XXX: The only supported function type is '
                            'NoBlock')
                newsection.append(normalize_boolean_ops(key, value))
            # Add function = NoBlock to label sections if not set as the
            # default is MaxWithBlock which will interfere with submit
            # requirements.
            if 'function' not in keys:
                newsection.append('function = NoBlock')
        else:
            for option in acl[section]:
                key, value = [x.strip() for x in option.split('=', 1)]
                newsection.append(normalize_boolean_ops(key, value))

        acl[section] = newsection
    acl.update(missing_sr)

for section in sorted(acl.keys()):
    if acl[section]:
        out += '\n[%s]\n' % section
        lastoption = ''
        for option in sorted(acl[section], key=tokens):
            if option != lastoption:
                if '10' in transformations:
                    # Gerrit prefers all option lines indented by a single
                    # hard tab; this minimises diffs if things like
                    # upgrades need to modify the acls
                    out += '\t'
                out += '%s\n' % option
            lastoption = option

if dry_run:
    print(out[1:-1])
else:
    aclfd = open(aclfile, 'w')
    aclfd.write(out[1:])
    aclfd.close()
