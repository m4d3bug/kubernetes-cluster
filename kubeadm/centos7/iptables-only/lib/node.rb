config.vm.define "#{k8s['cluster']['node']}-#{i}" do |subconfig|
    subconfig.vm.box = k8s['image']
    subconfig.vm.box_check_update = false

    subconfig.vm.hostname = "#{k8s['cluster']['node']}-#{i}"
    subconfig.vm.network :private_network,
	ip: "#{k8s['ip_part']}.#{i + 10}",
        libvirt__dhcp_enabled: "#{k8s['dhcp_enabled']}",
        libvirt__network_name: "#{k8s['zone']}",
        libvirt__host_ip: "#{k8s['router']}"

    subconfig.vm.provider "libvirt" do |lv|
        lv.default_prefix = "#{k8s['domain_prefix']}"
        lv.memory = k8s['resources']['node']['memory']
        lv.cpus = k8s['resources']['node']['cpus']
        lv.storage_pool_name = k8s['resources']['node']['storage_pool'] 
    end

    subconfig.vm.provision "#{k8s['cluster']['master']}-initial-setup", type: "shell" do |ins|
        ins.path = "script/bootstrap.sh"
        ins.args = ["#{k8s['user']}"]
    end

    # Hostfile :: Master node
    subconfig.vm.provision "master-hostfile", type: "shell" do |s|
        s.inline = <<-SHELL
            echo -e "$1\t$2" | tee -a /etc/hosts
        SHELL
        s.args = ["#{k8s['ip_part']}.10", "#{k8s['cluster']['master']}"]
    end
    # Hostfile :: Worker node
    (1..k8s['resources']['node']['count']).each do |j|
        if i != j
            subconfig.vm.provision "other-worker-hostfile", type: "shell" do |supdate|
                supdate.inline = <<-SHELL
                    echo -e "$1\t$2" | tee -a /etc/hosts
                SHELL
                supdate.args = ["#{k8s['ip_part']}.#{10 + j}", "#{k8s['cluster']['node']}-#{j}", "#{k8s['user']}", "#{i}"]
            end
        else
            subconfig.vm.provision "self-worker-hostfile", type: "shell" do |supdate|
                supdate.inline = <<-SHELL
                    echo -e "127.0.0.1\t$2" | tee -a /etc/hosts; echo -e "$1\t$2" | tee -a /etc/hosts
                SHELL
                supdate.args = ["#{k8s['ip_part']}.#{10 + j}", "#{k8s['cluster']['node']}-#{j}", "#{k8s['user']}", "#{i}"]
            end
        end
    end

    subconfig.vm.provision "Reboot to load all config", type:"shell", inline: "shutdown -r now"
end
