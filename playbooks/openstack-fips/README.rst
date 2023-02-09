This pre.yaml playbook is called as part of the openstack-fips job.
Its primary purpose is enable an Ubuntu Advantage subscription using
a subscription key that is stored in project-config.

Enabling FIPS requires a reboot, and so we need the FIPS playbook to
run very early in the node setup, so that resources set up by
subsequent pre-scripts are not affected by the reboot.

Therefore, the openstack-fips job must be definied as a base job for
most OpenStack jobs.  As most jobs will not require fips, a playbook
variable enable_fips - which defaults to False - is provided.

To enable FIPS mode, a job will simply need to set enable_fips to
True as a job variable.

**Job Variables**

.. zuul:jobvar:: enable_fips
   :default: False

   Whether to run the playbook and enable fips.  Defaults to False.

