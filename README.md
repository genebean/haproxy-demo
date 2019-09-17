# HAProxy Demo

This is a demo environment that shows off using HAProxy and keepalived together.

- [Usage info](#usage-info)
  - [Addresses](#addresses)
- [Custom Functions](#custom-functions)
  - [octets](#octets)

## Usage info

After running `vagrant up` you will have 5 virtual machines:

- 2 x CentOS 7 HAProxy instances
- 3 x Debian 9 Nginx instances

The Nginx instances are running Debian to reduce the memory footprint as they only need 512MB of RAM.

There is a webpage on each Debian instance that identifies what server it resides on. These pages are accessible via a floating IP (a VIP) provided by keepalived and shared among the HAProxy instances. The address is 192.168.50.5. You can access the http version via a browser or `curl http://192.168.50.5` and you can access the https version via `curl -k https://192.168.50.5` (it seems browsers don't like the self-signed cert).

```plain
                    +---------------+
                  +-+ 192.168.50.05 +-+
                  | +---------------+ |
                  |                   |
                  |                   v
          +-------v-------+   +-------+-------+
          | 192.168.50.06 +-+-+ 192.168.50.07 |
          +---------------+ | +---------------+
                            |
        +---------------------------------------+
        |                   |                   |
        v                   v                   v
+-------+-------+   +-------+-------+   +-------+-------+
| 192.168.50.11 |   | 192.168.50.12 |   | 192.168.50.13 |
+---------------+   +---------------+   +---------------+
```

### Addresses

Below is a list of addresses for this setup:

- HAProxy VIP:
  - http: [http://192.168.50.5](http://192.168.50.5)
  - https: [https://192.168.50.5](https://192.168.50.5)
- lb1 stats: [http://192.168.50.6:9000](http://192.168.50.6:9000)
- lb2 stats: [http://192.168.50.7:9000](http://192.168.50.7:9000)
- be1:
  - http: [http://192.168.50.11](http://192.168.50.11)
  - https: [https://192.168.50.11](https://192.168.50.11)
- be2:
  - http: [http://192.168.50.12](http://192.168.50.12)
  - https: [https://192.168.50.12](https://192.168.50.12)
- be3:
  - http: [http://192.168.50.13](http://192.168.50.13)
  - https: [https://192.168.50.11](https://192.168.50.13)

## Custom Functions

### octets

```puppet
$ip_array = $facts['networking']['interfaces']['eth1']['ip'].octets
$previous_ip = [
  $ip_array[0],
  $ip_array[1],
  $ip_array[2],
  $ip_array[3] - 1,
].join('.')

notice($previous_ip)
```
