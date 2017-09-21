#!/bin/bash

# E011 is intentionally ignored because it does not make sense; it is
# perfectly reasonable to put 'then' on a separate line when natural
# line breaks occur in long conditionals.

ROOT=$(readlink -fn $(dirname $0)/.. )
find $ROOT -not -path '*playbooks/legacy/*' -and -not -wholename \*.tox/\* \
    -and -not -wholename \*.test/\* \
    -and -name \*.sh -print0 | xargs -0 bashate -v --ignore E006,E011
