A module to submit a log processing job.

This role is a container for an Ansible module which processes a log
directory and submits jobs to a log processing gearman queue.  The
role itself performs no actions, and is intended only to be used by
other roles as a dependency to supply the module.
