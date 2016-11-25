===============
openstack-repos
===============

Download all repos and packages that might be needed.

Environment variables:
----------------------

DIB_CUSTOM_PROJECTS_LIST_URL
  :Required: No
  :Default: None
  :Description: Url to a yaml file contains custom list of repos.
    The custom yaml file has the same structure as the default file:
    'https://git.openstack.org/cgit/openstack-infra/project-config/plain/gerrit/projects.yaml'
    Download only the repos that appear in the custom file rather than
    downloading all openstack repos that appear in the default file.
  :Example:
    DIB_CUSTOM_PROJECTS_LIST_URL='file:///etc//project-config//gerrit//custom_projects.yaml'
