# -*- mode: ruby -*-
# vim: set ft=ruby :
# -*- mode: ruby -*-
# vim: set ft=ruby :

MACHINES = {

:inet2Router => {
      :box_name => "centos/7",
      :net => [
                 {ip: '192.168.255.2', adapter: 2, netmask: "255.255.255.240", virtualbox__intnet: "router-net"},
              ]   
},

:inetRouter => {
      :box_name => "centos/7",
      :net => [
                 {ip: '192.168.255.1', adapter: 2, netmask: "255.255.255.240", virtualbox__intnet: "router-net"},
              ]
},

:centralRouter => {
      :box_name => "centos/7",
      :net => [
                 {ip: '192.168.255.3', adapter: 2, netmask: "255.255.255.240", virtualbox__intnet: "router-net"},
                 {ip: '192.168.3.1', adapter: 3, netmask: "255.255.255.240", virtualbox__intnet: "local-net"},
              ]
},

:centralServer => {
      :box_name => "centos/7",
      :net => [
                 {ip: '192.168.3.2', adapter: 2, netmask: "255.255.255.240", virtualbox__intnet: "local-net"},
              ]
},
  
}

Vagrant.configure("2") do |config|

  MACHINES.each do |boxname, boxconfig|

    config.vm.define boxname do |box|

        box.vm.box = boxconfig[:box_name]
        box.vm.host_name = boxname.to_s

        boxconfig[:net].each do |ipconf|
          box.vm.network "private_network", ipconf
        end
        
        if boxconfig.key?(:public)
          box.vm.network "public_network", boxconfig[:public]
        end
        
        # box.vm.provision "ansible" do |ansible|
        #   ansible.playbook = "ansible/playbook/provision.yml"
        # end
                
    end

  end
    
end