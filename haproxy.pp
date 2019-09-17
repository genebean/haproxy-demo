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

$keepalive_vip = '192.168.50.5'
include keepalived

keepalived::vrrp::script { 'check_haproxy':
  script  => 'killall -0 haproxy',
  weight  => '2',
  require => Package['keepalived'],
}

if $facts['networking']['hostname'] == 'lb1' {
  keepalived::vrrp::instance { 'VI_50':
    interface         => 'eth0',
    state             => 'MASTER',
    virtual_router_id => 55,
    priority          => 101,
    auth_type         => 'PASS',
    auth_pass         => 'p@55w0rd',
    virtual_ipaddress => $keepalive_vip,
    track_script      => 'check_haproxy',
  }
} else {
  keepalived::vrrp::instance { 'VI_50':
    interface         => 'eth1',
    state             => 'BACKUP',
    virtual_router_id => 55,
    priority          => 100,
    auth_type         => 'PASS',
    auth_pass         => 'p@55w0rd',
    virtual_ipaddress => $keepalive_vip,
    track_script      => 'check_haproxy',
  }
}

class { 'haproxy':
  package_name        => 'rh-haproxy18',
  config_dir          => '/etc/opt/rh/rh-haproxy18/haproxy',
  config_file         => '/etc/opt/rh/rh-haproxy18/haproxy/haproxy.cfg',
  config_validate_cmd => '/bin/scl enable rh-haproxy18 "haproxy -f % -c"',
  service_name        => 'rh-haproxy18-haproxy',
  service_manage      => false,
  merge_options       => false,
  global_options      => {
    'log'                        => '127.0.0.1 local0',
    'chroot'                     => '/var/opt/rh/rh-haproxy18/lib/haproxy',
    'pidfile'                    => '/var/run/rh-haproxy18-haproxy.pid',
    'maxconn'                    => '4000',
    'user'                       => 'haproxy',
    'group'                      => 'haproxy',
    'daemon'                     => '',
    'stats'                      => 'socket /var/opt/rh/rh-haproxy18/lib/haproxy/stats',
    # lint:ignore:140chars
    # set default parameters to the intermediate configuration per https://mozilla.github.io/server-side-tls/ssl-config-generator/
    'tune.ssl.default-dh-param'  => '2048',
    'ssl-default-bind-ciphers'   => 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384',
    'ssl-default-bind-options'   => 'no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets',
    'ssl-default-server-ciphers' => 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384',
    'ssl-default-server-options' => 'no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets',
    # lint:endignore
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
    ipaddress        => $keepalive_vip,
    require          => Class['keepalived'],
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

service { 'rh-haproxy18-haproxy.service':
  ensure  => running,
  enable  => true,
  require => Class['haproxy'],
}

ini_setting {
  default:
    ensure            => present,
    path              => '/usr/lib/systemd/system/rh-haproxy18-haproxy.service',
    key_val_separator => '=',
    require           => Package['haproxy'],
    notify            => Service['rh-haproxy18-haproxy.service'],
  ;
  'haproxy after keepalived':
    section => 'Unit',
    setting => 'After',
    value   => 'network.target keepalived.service',
  ;
  'haproxy restart always':
    section => 'Service',
    setting => 'Restart',
    value   => 'always',
  ;
  'haproxy restart delay':
    section => 'Service',
    setting => 'RestartSec',
    value   => '10',
  ;
}

