========================
Reviewing project-config
========================

The following are notes for reviewers on how to review changes for
project-config. These notes are not exhaustive, they cover a few
caveats that especially core reviewers should be aware of.

Additional reviews
==================

For changes to projects, there should be support by the project team
that is affected. A couple of projects have listed infra liaisons at
https://wiki.openstack.org/wiki/CrossProjectLiaisons#Infra . Changes
should only merge when at least one of the infra liaisons has given a
+1. For not-listed projects, there are no rules but it might be good
to ask for review by PTL or cores of the repo depending on the change.

Voting jobs
===========

There should be no non-voting jobs in the gate queue. Voting jobs
should be in both check and gate queues.

New repo creations
==================

Check the following:

* If publishing to PyPI is set up: Check that
  https://pypi.python.org/pypi/PROJECT exists and is set up for
  openstackci.

* Is this a new repository for a team that is part of the Big Tent?
  Then ask for a governance review and PTL+1.

* If there's no import ("upstream" keyword) of an existing repository,
  best check that the team really wants to start with a new empty repo
  and has no content to import. Either is fine, it's just that an
  import at repo creation time is easy, afterwards it only causes
  problems.

Big Tent resources
==================

Check that publishing to docs.openstack.org or specs.openstack.org is
only enabled for projects that are in the Big Tent (mentioned in
governance repository). Similary, translation workflow is also only
enabled for Big Tent projects.

Proposal jobs
=============

Proposal jobs run on the long running proposal slave that has access
to the credentials that the jobs need to access Zanata and gerrit.
Jobs running there are the exception and need to be carefully reviewed
before approving them.

Here are some points to look at:

* First response should be: How else can we achieve this?

* Jobs can publish artifacts also to specific places, like
  static.openstack.org or tarballs.openstack.org, and use these from
  other jobs.

* Proposal jobs should not run arbitrary scripts from other
  repositories or install untrusted packages.

Removing check-requirements job
===============================

* The http://git.openstack.org/cgit/openstack/requirements repository holds
  list of projects that have check-requirements job in <root>/projects.txt.

* Whenever a review is submitted for removing check-requirements job,
  the reviewer should verify that the project has been removed from
  projects.txt already or that this project-config change depends
  on the review to remove it.

Jobs for persistent node
========================

In general, nodes are off-lined after a job run. Some special nodes
are not off-lined and long-lived. Ensure for these nodes that any job
running on them is handled in zuul/openstack_functions.py.

Current nodes that are long-lived are: proposal, release, signing, wheel-mirror-*
