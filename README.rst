OpenStack Infra Config Files
============================

This repo contains a set of config files that are consumed by the
openstack-infra/system-config puppet modules in order to deploy and
configure the OpenStack Infrastructure. You should edit these
files to make configuration changes to the OpenStack Infrastructure.

accessbot
=========

This dir contains the IRC access bot channel config. This config file
is used to specify which channels are managed by the infra team and
the permissions assigned to nicks in those channels.

`IRC Documentation <http://docs.openstack.org/infra/system-config/irc.html>`_

gerrit
======

This dir contains the main project registry in projects.yaml along
with all of the gerrit project ACLs in the acls subdir. You will need
to edit these files to add new projects to Gerrit.

See the `StackForge Documentation <http://docs.openstack.org/infra/system-config/stackforge.html>`_
for info on adding projects.

`Gerrit Documentation <http://docs.openstack.org/infra/system-config/gerrit.html>`_

gerritbot
=========

This dir contains the gerritbot channel config file. Edit this file to
add the gerritbot to your IRC channels for gerrit event messages.

`IRC Documentation <http://docs.openstack.org/infra/system-config/irc.html>`_

jenkins
=======

This dir contains the Jenkins job definitions as supplied to Jenkins Job
Builder as well as the scripts used in many of the jobs. Edit these files
if you need to add/delete/modify Jenkins Jobs.

`Jenkins Documentation <http://docs.openstack.org/infra/system-config/jenkins.html>`_
`Jenkins Job Builder Documentation <http://docs.openstack.org/infra/system-config/jjb.html>`_

nodepool
========

This dir contains the nodepool scripts and nodepool disk image builder
elements that are used to build the images we boot slave nodes off of.
Edit these files if you need to modify the base images that Jenkins jobs
run on.

`Nodepool Documentation <http://docs.openstack.org/infra/system-config/nodepool.html>`_

specs
=====

This dir contains the index.html file for the http://specs.openstack.org
site. Edit this file if you are adding and removing projects from that
site.

`Static Web Hosting Documentation <http://docs.openstack.org/infra/system-config/static.html>`_

zuul
====

This dir contains the zuul layout.yaml file and its python functions file(s).
These files determine what jobs are run on Gerrit events for each project.
Edit these files if you need to change the jobs that your project runs or
attributes of those jobs (voting, slave node type, etc).

`Zuul Documentation <http://docs.openstack.org/infra/system-config/zuul.html>`_

dev
===

This dir contains config files for the development deployments of
the above services.
