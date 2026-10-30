# -*- mode: ruby -*-
# vi: set ft=ruby :

require "yaml"

ROOT = File.dirname(__FILE__)
CONFIG_FILE = File.join(ROOT, "config", "vagrant.local.yml")
EXAMPLE_FILE = File.join(ROOT, "config", "vagrant.local.yml.example")

unless File.exist?(CONFIG_FILE)
  abort <<~MSG
    Missing #{CONFIG_FILE}

    Copy #{EXAMPLE_FILE} to config/vagrant.local.yml and edit it for this
    machine (resource sizing, static IP, hostname), then run `vagrant up`
    again. This file is gitignored on purpose -- each physical machine keeps
    its own copy.
  MSG
end

cfg = YAML.load_file(CONFIG_FILE)

Vagrant.configure("2") do |config|
  config.vm.box = cfg.fetch("box", "debian/trixie64")
  config.vm.box_version = cfg["box_version"] if cfg["box_version"]

  config.vm.hostname = cfg.fetch("hostname", "devbox")

  # No host synced folder by design -- work lives entirely on the VM's own
  # disk (see README), and the libvirt provider's default /vagrant sync
  # otherwise requires NFS on the host for no benefit here.
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.network "private_network", ip: cfg.fetch("ip", "192.168.121.10")

  # Agent forwarding is OFF by default (a guest can't use host keys unless
  # you ask for it). Opt in per session for git pushes:
  #   vagrant ssh -- -A
  # and see README.md's SSH agent forwarding note for scoping the
  # forwarded agent to specific hosts (PermitRemoteOpen).

  config.vm.provider :libvirt do |lv|
    lv.cpus = cfg.fetch("vcpus", 8)
    lv.memory = cfg.fetch("memory_mb", 16384)
    lv.machine_virtual_size = cfg.fetch("disk_gb", 128)
    # lv.storage_pool_name = "devvm"
  end

  config.vm.provision "shell", path: "provision/01-base.sh"
  config.vm.provision "shell", path: "provision/02-docker.sh"
  config.vm.provision "shell", path: "provision/03-cli-tools.sh"
  config.vm.provision "shell", path: "provision/04-desktop-vnc.sh"
  config.vm.provision "shell", path: "provision/05-go.sh"
  # Runs as the vagrant user: herdr installs into ~/.local/bin
  config.vm.provision "shell", path: "provision/06-herdr.sh", privileged: false
  config.vm.provision "shell", path: "provision/07-neovim.sh"
  config.vm.provision "shell", path: "provision/08-chrome.sh"
  config.vm.provision "shell", path: "provision/09-default-config.sh"
end
