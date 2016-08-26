zuul-worker
===========

Setup a node to be a zuul worker

User Creation
=============

This element bakes in a ``zuul`` user on the host for the zuul-worker
process to log in with.

By default login permissions (``authorized_keys``) will be populated
for the ``zuul`` user from ``~/.ssh/id_rsa.pub`` -- i.e. the public
key of the currently building user.  Specify an alternative filename
in ``ZUUL_USER_SSH_PUBLIC_KEY`` to override this.

The ``zuul`` user is provided with passwordless ``sudo`` access.
