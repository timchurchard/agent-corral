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

# Either a `machines:` section (name -> settings) for several VMs from this
# one Vagrantfile, e.g. separate work/clean machines, or no such section for
# the original single-VM layout. Each entry needs its own ip and hostname:
# they all share libvirt's private NAT network, and the hostname doubles as
# the libvirt domain name, so duplicates collide.
machines =
  if cfg["machines"]
    cfg["machines"].map { |name, m| [name.to_s, m || {}] }
  else
    [["default", cfg]]
  end

if machines.size > 1
  ips = machines.map { |_, m| m["ip"] }.compact
  hostnames = machines.map { |_, m| m["hostname"] }.compact
  if ips.uniq.size != machines.size
    abort "config/vagrant.local.yml: every machine needs a distinct `ip`"
  end
  if hostnames.uniq.size != machines.size
    abort "config/vagrant.local.yml: every machine needs a distinct `hostname`"
  end
end

Vagrant.configure("2") do |config|
  config.vm.box = cfg["box"] if cfg["box"]

  # No host synced folder by design -- work lives entirely on the VM's own
  # disk (see README), and the libvirt provider's default /vagrant sync
  # otherwise requires NFS on the host for no benefit here.
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Agent forwarding is OFF by default (a guest can't use host keys unless
  # you ask for it). Opt in per session for git pushes:
  #   vagrant ssh -- -A
  # and see README.md's SSH agent forwarding note for scoping the
  # forwarded agent to specific hosts (PermitRemoteOpen).

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

  machines.each do |name, m|
    box = m["box"] || cfg.fetch("box", "debian/trixie64")
    hostname = m["hostname"] ||
               (name == "default" ? "devbox" : "devbox-#{name}")
    ip = m["ip"]
    if ip.nil? && machines.size > 1
      abort "machine '#{name}' in config/vagrant.local.yml needs an `ip`" \
            " (they all share one private network)"
    end
    ip ||= "192.168.121.10"

    config.vm.define name, primary: (name == "default") do |node|
      node.vm.box = box
      node.vm.box_version = m["box_version"] || cfg["box_version"]
      node.vm.hostname = hostname

      node.vm.network "private_network", ip: ip

      node.vm.provider :libvirt do |lv|
        lv.cpus = m.fetch("vcpus", cfg.fetch("vcpus", 8))
        lv.memory = m.fetch("memory_mb", cfg.fetch("memory_mb", 16384))
        lv.machine_virtual_size = m.fetch("disk_gb", cfg.fetch("disk_gb", 128))
        # lv.storage_pool_name = "devvm"
      end
    end
  end
end