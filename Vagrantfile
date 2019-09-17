Vagrant.configure("2") do |config|
  # this controls how many backend nodes are created
  node_num=3

  # HAProxy instances
  (1..2).each do |i|
    vm_name="lb#{i}"

    config.vm.define vm_name do |s|
      s.vm.box = 'genebean/centos-7-puppet-latest'
      s.vm.hostname=vm_name
      s.vm.network "private_network", ip: "192.168.50.#{i+5}"
      s.vm.provision "shell", inline: 'echo "GATEWAYDEV=eth0" >> /etc/sysconfig/network && systemctl restart network'
      s.vm.provision "shell", inline: 'puppet module install puppetlabs-haproxy'
      s.vm.provision "shell", inline: 'puppet module install puppet-selinux'
      s.vm.provision "shell", inline: 'ln -s /vagrant/custom_facts /etc/puppetlabs/code/modules/custom_facts'
      s.vm.provision "shell", inline: "echo #{node_num} > /etc/webserver_count"
      s.vm.provision "shell", inline: 'puppet apply /vagrant/haproxy.pp'
      if i == 1 then
        s.vm.provision "shell", inline:<<-SHELL
          facter networking.fqdn
        SHELL
      else
        s.vm.provision "shell", inline:<<-SHELL
          facter networking.fqdn
        SHELL
      end
    end # config.vm
  end # HAProxy block

  (1..node_num).each do |i|
    vm_name="be#{i}"

    config.vm.define vm_name do |s|
      s.vm.box = 'debian/stretch64'
      s.vm.hostname=vm_name
      s.vm.network "private_network", ip: "192.168.50.#{i+10}"
      s.vm.provision "shell", inline:<<-SHELL
        export DEBIAN_FRONTEND=noninteractive
        wget https://apt.puppet.com/puppet-release-stretch.deb -O /tmp/puppet-release-stretch.deb
        dpkg -i /tmp/puppet-release-stretch.deb
        apt-get update
        apt-get -y install cowsay nginx puppet-agent
        source /etc/profile.d/puppet-agent.sh 
        puppet module install puppetlabs-apt
        puppet module install puppet-nginx
        puppet apply /vagrant/webserver.pp
        cat /vagrant/html-top > /var/www/html/index.html
        /usr/games/cowsay Hello from `hostname` >> /var/www/html/index.html
        cat /vagrant/html-bottom >> /var/www/html/index.html
      SHELL
    end
  end # backend block
end

