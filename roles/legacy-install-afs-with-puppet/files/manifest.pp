class { 'openafs::client':
  cell         => 'openstack.org',
  realm        => 'OPENSTACK.ORG',
  admin_server => 'kdc.openstack.org',
  cache_size   => 500000,
  kdcs         => [
    'kdc01.openstack.org',
    'kdc02.openstack.org',
  ],
}
