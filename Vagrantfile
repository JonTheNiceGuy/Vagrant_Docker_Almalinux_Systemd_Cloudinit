if ENV['VAGRANT_DEFAULT_PROVIDER'] == nil
  ENV['VAGRANT_DEFAULT_PROVIDER'] = 'virtualbox'
end
if ENV['OS_VERSION'] == nil
  ENV['OS_VERSION'] = "10"
end

# Load Docker cloud-init support plugin
# This enables cloud-init configuration for Docker provider using NoCloud datasource
require_relative '.vagrant-plugins/vagrant-docker-cloudinit-plugin'

Vagrant.configure("2") do |config|
  if ENV['VAGRANT_DEFAULT_PROVIDER'] == 'virtualbox'
    config.vm.box = "almalinux/#{ENV['OS_VERSION']}"
    config.vm.box_check_update = false
  end

  config.ssh.insert_key = true

  config.vm.provider "docker" do |d|
    d.build_dir = ".vagrant-docker"
    d.has_ssh = true
    d.remains_running = false
    d.build_args = [
      "--network", "host",
      "--build-arg", "OS_VERSION=#{ENV['OS_VERSION']}"
    ]
    d.create_args = [
      "--tmpfs", "/tmp:exec",
      "--tmpfs", "/run:rw,mode=1777",
      "--tmpfs", "/run/lock:rw,mode=1777",
      "-v", "/sys/fs/cgroup:/sys/fs/cgroup:rw",
      "--cgroupns=host",
      "-t"
    ]
  end

  config.vm.define "worker" do |config|
    config.vm.hostname = "worker"

    # Virtualbox can use config.vm.cloud_init but docker can't
    config.vm.cloud_init :user_data do |cloud_init|
      cloud_init.content_type = "text/cloud-config"
      cloud_init.path = "worker/cloud-init.yaml"
    end
    # So we have a specific config block to manage this when we select docker provider
    config.docker_cloud_init.user_data do |cloud_init|
      cloud_init.content_type = "text/cloud-config"
      cloud_init.path = "worker/cloud-init.yaml"
    end

    config.vm.provision "shell", inline: "bash -x -c 'cat /opt/proof.txt'"
  end
end
