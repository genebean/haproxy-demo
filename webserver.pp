package { 'openssl':
  ensure => present,
  before => Exec['create localhost cert'],
}

$pki_dirs = [
  '/etc/pki/',
  '/etc/pki/tls',
  '/etc/pki/tls/certs',
  '/etc/pki/tls/private',
]

file { $pki_dirs:
  ensure => directory,
  before => Exec['create localhost cert'],
}

exec { 'create localhost cert':
  # lint:ignore:80chars lint:ignore:140chars
  command   => "/usr/bin/openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -sha256 -subj '/CN=domain.com/O=My Company Name LTD./C=US' -keyout /etc/pki/tls/private/localhost.key -out /etc/pki/tls/certs/localhost.crt",
  # lint:endignore
  creates   => '/etc/pki/tls/certs/localhost.crt',
  logoutput => true,
  before    => Class['nginx'],
}

class { 'nginx':
  confd_purge  => true,
  server_purge => true,
}

nginx::resource::server { 'default':
  ensure      => present,
  listen_port => 80,
  ssl         => true,
  ssl_cert    => '/etc/pki/tls/certs/localhost.crt',
  ssl_key     => '/etc/pki/tls/private/localhost.key',
  ssl_port    => 443,
  www_root    => '/var/www/html',
}
