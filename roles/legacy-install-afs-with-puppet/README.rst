Legacy role to install AFS client on nodes with Infra puppet

AFS is a little tricky to install because it takes an additional repo for
CentOS. This is a tide-me-over role to use Infra's puppet manifests to install
AFS client on remote nodes until we have an Ansible solution cooked up.

There are no parameters. It's just hardcoded to get an AFS client up.
