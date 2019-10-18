=============
nodepool-base
=============

Tasks to deal with image metadata and other Nodepool cloud specific tweaks.

Environment variables:

``NODEPOOL_SCRIPTDIR`` path to copy Nodepool scripts from. It is set
automatically by Nodepool.  For local hacking override it to where your scripts
are. Default:
``$TMP_MOUNT_PATH/opt/git/opendev.org/openstack/project-config/nodepool/scripts``.

Name resolution
---------------

The image should have the unbound DNS resolver package installed, the
``nodepool-base`` element then configures it to forward DNS queries
to:

  ``NODEPOOL_STATIC_NAMESERVER_V4``, default: ``1.0.0.1``
  ``NODEPOOL_STATIC_NAMESERVER_V4_FALLBACK``, default: ``8.8.8.8``.

If ``NODEPOOL_STATIC_NAMESERVER_POPULATE_IPV6`` is set to ``1`` then
the following two servers will be configured as forwarders too

 ``NODEPOOL_STATIC_NAMESERVER_V6``, default: ``2606:4700:4700::1111``
 ``NODEPOOL_STATIC_NAMESERVER_V6_FALLBACK``, default: ``2001:4860:4860::8888``

Note externally setting either of these values implies
``NODEPOOL_STATIC_NAMESERVER_POPULATE_IPV6=1``
