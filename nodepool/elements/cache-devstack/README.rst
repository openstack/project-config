cache-devstack
==============

Pre-cache a range of things into CI images.  This element uses the
``source-repositories`` element to acquire files to be cached.  The
standard cache location is ``/opt/cache/files``.

A number of strategies are used to get the files to be cached.

We have a number of ``source-repository-*`` files for each package
package that should be cached into images.

``extra-data.d/55-cache-devstack-repos`` goes through each devstack
branch and runs the ``tools/image_list.sh`` script to dynamically
build a list of files to cache as requested by devstack.  This is
mostly virtual machine images, but also some other peripheral packages.

