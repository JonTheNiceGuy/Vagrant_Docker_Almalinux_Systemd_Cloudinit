Vagrant + Docker + AlmaLinux + Systemd + Cloud-Init
=====================================================

PURPOSE
-------
This project demonstrates how to run AlmaLinux virtual machines using Vagrant
with BOTH VirtualBox and Docker providers, while supporting systemd and
cloud-init configuration in both environments.

The key challenge solved here is enabling cloud-init in Docker containers,
which is not natively supported by Vagrant's Docker provider.


KEY FEATURES
------------
1. Dual Provider Support: Works with both VirtualBox and Docker
2. Systemd in Docker: Runs systemd inside Docker containers
3. Cloud-Init Support: Custom Vagrant plugin enables cloud-init in Docker
4. AlmaLinux: Configurable version (default: AlmaLinux 10)


COMPONENTS
----------
Vagrantfile
  - Main configuration supporting both providers
  - Defines a "worker" VM/container with cloud-init configuration

.vagrant-plugins/vagrant-docker-cloudinit-plugin.rb
  - Custom Vagrant plugin that implements docker_cloud_init helper
  - Sets up cloud-init NoCloud datasource for Docker containers
  - Mounts cloud-init files to /var/lib/cloud/seed/nocloud/

.vagrant-docker/Dockerfile
  - Builds AlmaLinux container with systemd and cloud-init
  - Based on work from containerized-systemd project
  - Includes SSH server and Vagrant user setup

.vagrant-docker/docker-entrypoint.sh
  - Initializes systemd inside the container
  - Required for running systemd as PID 1 in Docker

worker/cloud-init.yaml
  - Example cloud-init configuration
  - Creates /opt/proof.txt to demonstrate cloud-init works


USAGE
-----
Using VirtualBox (default):
  vagrant up

Using Docker:
  VAGRANT_DEFAULT_PROVIDER=docker vagrant up

Change AlmaLinux version:
  OS_VERSION=9 vagrant up


HOW IT WORKS
------------
For VirtualBox:
  Uses native config.vm.cloud_init support

For Docker:
  1. Custom plugin intercepts the container creation
  2. Reads cloud-init configuration from worker/cloud-init.yaml
  3. Creates files in .vagrant/cloudinit/worker/
  4. Mounts this directory to /var/lib/cloud/seed/nocloud/ in container
  5. cloud-init inside container reads from NoCloud datasource
  6. Configuration is applied during container startup


VERIFICATION
-----------
After running 'vagrant up', the provisioning step will execute:
  bash -x -c 'cat /opt/proof.txt'

This should output "This system works", proving that cloud-init successfully
ran and created the file as specified in worker/cloud-init.yaml.


CREDITS
-------
Based on:
- https://jon.sprig.gs/blog/post/2145
- https://vtorosyan.github.io/ansible-docker-vagrant/
- https://github.com/AkihiroSuda/containerized-systemd/

The plugin to enable cloud-init in Docker was created with the assistance of [Claude.ai](https://claude.ai).
