===============
 Release Tools
===============

release_from_yaml.sh
====================

This script takes YAML files describing deliverables to release (like those
living in ``openstack/releases``) and calls the release.sh script (see below)
to apply the corresponding tags. It will create a tag for the last release
mentioned in the file(s). You can point it to specific YAML files, or to a
local git repository (in which case it will look at the files modified in the
most recent commit).

Examples:

::

  ./release_from_yaml.sh ../openstack-releases deliverables/mitaka/nova.yaml

Call release.sh for all repositories mentioned in the last release added
to ../openstack-releases/deliverables/mitaka/nova.yaml

::

  ./release_from_yaml.sh ../openstack-releases

Look into the git repository at ../openstack-releases for deliverable YAML
files modified at the last commit, and call release.sh for all repositories
mentioned on the last release in each such file.


release.sh
==========

This script creates a tag on a given repository SHA and pushes it to Gerrit.
Additionally it will add a message on Launchpad bugs that are mentioned as
"closed" in git commit messages since the last tag on the same series.

Example:

::

  ./release.sh openstack/oslo.rootwrap mitaka 3.0.3 gerrit/master

Apply a 3.0.3 tag (associated to the mitaka series) to the gerrit master
HEAD of the openstack/oslo.rootwrap reporitory, and add a comment for each
closed bug mentioned in commit messages since the previous mitaka tag (3.0.2).

branch_from_yaml.sh
===================

This script looks at the deliverable files to decide how to create
stable branches.

::

  $ branch_from_yaml.sh ~/repos/openstack/releases mitaka
  $ branch_from_yaml.sh ~/repos/openstack/releases mitaka
  $ branch_from_yaml.sh ~/repos/openstack/releases mitaka deliverables/_independent/openstack-ansible.yaml
