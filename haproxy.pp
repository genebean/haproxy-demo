include selinux

selinux::boolean { 'haproxy_connect_any': }

package { 'centos-release-scl':
  ensure => present,
}

package { 'centos-release-scl-rh':
  ensure => present,
}

exec { 'make scl repo cache':
  command     => '/usr/bin/yum makecache',
  subscribe   => Package[
    'centos-release-scl',
    'centos-release-scl-rh',
  ],
  refreshonly => true,
}

class { 'haproxy':
  package_name        => 'rh-haproxy18',
  config_dir          => '/etc/opt/rh/rh-haproxy18/haproxy',
  config_file         => '/etc/opt/rh/rh-haproxy18/haproxy/haproxy.cfg',
  config_validate_cmd => '/bin/scl enable rh-haproxy18 "haproxy -f % -c"',
  service_name        => 'rh-haproxy18-haproxy',
  global_options      => {
    'log'                        => '127.0.0.1 local0',
    'chroot'                     => '/var/opt/rh/rh-haproxy18/lib/haproxy',
    'pidfile'                    => '/var/run/rh-haproxy18-haproxy.pid',
    'maxconn'                    => '4000',
    'user'                       => 'haproxy',
    'group'                      => 'haproxy',
    'daemon'                     => '',
    'stats'                      => 'socket /var/opt/rh/rh-haproxy18/lib/haproxy/stats',
    # set default parameters to the intermediate configuration per https://mozilla.github.io/server-side-tls/ssl-config-generator/
    'tune.ssl.default-dh-param'  => '2048',
    'ssl-default-bind-ciphers'   => 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384',
    'ssl-default-bind-options'   => 'no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets',
    'ssl-default-server-ciphers' => 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384',
    'ssl-default-server-options' => 'no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets',
  },
  defaults_options    => {
    'mode'    => 'tcp',
    'balance' => 'leastconn',
    'log'     => 'global',
    'maxconn' => '8000',
    'option'  => [
      'tcplog',
      'dontlognull',
      'http-server-close',
      'forwardfor except 127.0.0.0/8',
      'redispatch',
    ],
    'retries' => '3',
    'timeout' => [
      'http-request 10s',
      'queue 30m',
      'connect 10s',
      'client 15m',
      'server 15m',
      'http-keep-alive 10s',
      'check 10s',
    ],
  },
  require             => Package[
    'centos-release-scl',
    'centos-release-scl-rh',
  ],
}

haproxy::listen {
  default:
    collect_exported => false,
    ipaddress        => $facts['networking']['interfaces']['eth1']['ip'],
  ;
  'website-80':
    ports => '80',
  ;
  'website-443':
    ports => '443',
  ;
}

if $facts['webserver_count'] > 0 {
  Integer[1, $facts['webserver_count']].each |$x| {
    $ip = $x + 10
    haproxy::balancermember {
      default:
        options      => 'check',
        server_names => "be${x}",
        ipaddresses  => "192.168.50.${ip}",
      ;
      "be${x}-80":
        ports             => '80',
        listening_service => 'website-80',
      ;
      "be${x}-443":
        ports             => '443',
        listening_service => 'website-443',
      ;
    }
  }
}

haproxy::listen { 'stats-page':
  collect_exported => false,
  ipaddress        => '*',
  ports            => '9000',
  options          => {
    'mode'   => 'http',
    'option' => [
      'httplog',
    ],
    'stats'  =>[
      'uri /',
      'realm HAProxy\ Statistics',
      'admin if TRUE',
    ],
  },
}

