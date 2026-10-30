# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Infrastructure config, not application code. It defines one libvirt/KVM VM managed by Vagrant provisioned entirely by shell scripts. The repo is cloned onto several physical machines; the VM is meant to look identical on each (work-in-progress moves between machines via git push/pull, not shared VM state or synced folders).

## Common commands

```sh
vagrant up --provider=libvirt        # create/start the VM (requires config/vagrant.local.yml)
vagrant provision                    # re-run provisioning on an already-created VM
vagrant provision --provision-with shell   # or scope by name, e.g. provisioners 01-base.sh
vagrant reload --provision           # reboot + re-provision
vagrant ssh                          # enter the guest
vagrant destroy -f                   # remove the VM (disk is recreated from scratch)
vagrant status / vagrant halt        # inspect / stop
```

There is no build/test/lint tooling — verification is the README's checklist (`docker run hello-world`, `aws --version`, `claude --version` etc. inside the guest, plus Cockpit/VNC reachability over SSH tunnels).

## Key structure

- `Vagrantfile` — reads `config/vagrant.local.yml`, fails with a clear message if it's missing. All keys have fallbacks, so the yml only overrides box version, hostname, static IP, vcpus/memory/disk. No synced folder by design (work lives on the VM's own disk). SSH agent forwarding is off by default; opt in per session with `vagrant ssh -- -A` so guest git can use host keys without a private key landing on the guest — see the README's SSH agent forwarding note.
- `config/vagrant.local.yml` — **gitignored on purpose**. Each physical machine keeps its own copy (resource sizing + static IP differ per machine). Copy from `config/vagrant.local.yml.example`. Never generate or commit this file; `box_version` must be pinned to a concrete version, not left as `CHANGE_ME`.
- `provision/01-base.sh … 04-desktop-vnc.sh` — run in filename order on every provision. They use `set -euo pipefail` and guard installs with `command -v` checks, so they stay idempotent across re-provisions — keep new scripts that way.

## Provisioning constraints

- Provisioning installs only generic tooling (Docker, AWS CLI, Node/LTS, Claude Code CLI, XFCE + TigerVNC). Personal/secret setup (git identity, `claude` login, `vncpasswd`, AWS credentials/MFA) is intentionally **out of scope** of the scripts — that's the README's "Post-`vagrant up` manual steps" section. Don't add secret material or interactive steps to provision scripts.
- The VNC unit (`vncserver@:1`) is installed but deliberately not enabled in 04: it can't start before `vncpasswd` runs inside the guest.
- Desktop/VNC access is via SSH tunnel only (Cockpit on host 127.0.0.1:9090, VNC on VM 192.168.121.10:5901) — nothing is meant to be directly exposed.
- Host-side prerequisites (KVM module, vagrant-libvirt plugin, libvirt `default` storage pool repoint under `/home`, Cockpit localhost-only bind) are per-physical-machine and live in the README — don't move them into provision scripts.