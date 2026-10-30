# agent-corral

A reproducible work dev environment, as a single libvirt/KVM VM managed by
Vagrant. Keeps work tooling (git clones, Docker, AWS CLI, tmux, Claude Code)
off the host OS. Designed to be cloned onto any of several physical machines
and produce an identical environment on each — only one VM runs at a time,
and work-in-progress moves between machines via `git push`/`pull` (or manual
`rsync`/`scp`), not shared VM state.

## One-time host setup (per physical machine)

```sh
sudo apt-get update
sudo apt-get install -y qemu-kvm qemu-system libvirt-daemon-system libvirt-clients \
  virtinst bridge-utils ruby-libvirt libvirt-dev cockpit cockpit-machines vagrant

# Load the KVM module for this CPU and make it survive reboots -- without
# it libvirt can't get KVM-backed domain capabilities at all, and
# `vagrant up` fails with "could not get preferred machine ... type=kvm".
# Check vendor_id in /proc/cpuinfo: GenuineIntel -> kvm_intel, AuthenticAMD -> kvm_amd.
sudo modprobe kvm-intel   # or kvm-amd, depending on this machine's CPU
echo kvm-intel | sudo tee /etc/modules-load.d/kvm.conf   # or kvm-amd

# Vagrant itself: follow https://developer.hashicorp.com/vagrant/downloads
vagrant plugin install vagrant-libvirt

sudo usermod -aG libvirt "$USER"
# log out/in (or reboot) for the group membership to take effect
```

By default vagrant-libvirt creates VM disks in libvirt's `default` storage
pool at `/var/lib/libvirt/images`, on the root partition. Repoint that pool
at a directory under `/home` before the first `vagrant up` (this VM's disk
is `disk_gb` large, currently 128GB):

```sh
sudo virsh pool-destroy default 2>/dev/null || true
sudo virsh pool-undefine default 2>/dev/null || true
sudo mkdir -p /home/libvirt-images
sudo virsh pool-define-as default dir --target /home/libvirt-images
sudo virsh pool-autostart default
sudo virsh pool-start default
```

`/home` and every directory down to `/home/libvirt-images` need the execute
bit for "other" so the qemu process (which runs as `libvirt-qemu`, not root)
can traverse into it — check with `namei -l /home/libvirt-images` and
`chmod o+x` any directory that's missing it if `vagrant up` fails to create
the disk. This is per-host, since each physical machine defines its own
`default` pool; if you'd rather leave the system default pool alone, give
just this VM its own pool instead by defining a second pool the same way
under a different name (e.g. `devvm`) and adding
`lv.storage_pool_name = "devvm"` inside the Vagrantfile's
`config.vm.provider :libvirt` block.

Bind Cockpit to localhost only — it defaults to listening on all interfaces,
and remote access here is meant to go through an SSH tunnel, not a directly
exposed port:

```sh
sudo mkdir -p /etc/systemd/system/cockpit.socket.d
sudo tee /etc/systemd/system/cockpit.socket.d/listen-localhost.conf >/dev/null <<'EOF'
[Socket]
ListenStream=
ListenStream=127.0.0.1:9090
EOF
sudo systemctl daemon-reload
sudo systemctl restart cockpit.socket
sudo systemctl enable --now cockpit.socket
```

## Per-machine setup

```sh
git clone <this repo> agent-corral
cd agent-corral
cp config/vagrant.local.yml.example config/vagrant.local.yml
# edit config/vagrant.local.yml: box_version, ip, vcpus, memory_mb, disk_gb
vagrant up --provider=libvirt
```

`config/vagrant.local.yml` is gitignored on purpose — each machine keeps its
own copy so resource sizing and the VM's static IP can differ without
touching the shared Vagrantfile.

## Post-`vagrant up` manual steps (not scripted — personal/secret)

```sh
vagrant ssh
```

- `git config --global user.name ...` / `user.email ...`
- `claude` — log in on first run
- `vncpasswd` — set a VNC password before starting the desktop:
  `sudo systemctl enable --now vncserver@:1`
- Personal credentials aren't provisioned. `vagrant ssh` on itself already
  uses SSH agent forwarding, so git over SSH works with no key on the guest.
  For anything else you may want to copy material in manually, e.g.
  `rsync ~/.aws/` or a `~/.ssh/id_whatever_key` into the VM (then
  `chmod 600` inside it), or run `gh auth login` / `aws sso login` there.

## Remote access from outside the house

Manage/inspect the VM (start/stop/snapshot, console view) via Cockpit:

```sh
ssh -L 9090:localhost:9090 <user>@<physical-host>
# then open https://localhost:9090 locally
```

Use the actual desktop (browser, GUI IDE) inside the VM via VNC, tunneled
through the same host (replace with the VM's static IP from
`vagrant.local.yml`):

```sh
ssh -L 5901:192.168.121.10:5901 <user>@<physical-host>
# then point a VNC client at localhost:5901
```

From the physical host itself no tunnel is needed — point the VNC client
straight at the VM (VNC syntax uses `::` for the port, e.g.
`192.168.121.10::5901`). The VM sits on libvirt's private NAT network, so
this stays unreachable from outside the host.

## Herdr cheat sheet

Installed by provision `06-herdr.sh` (runs as `vagrant`): `herdr-app` and
the `~/.local/bin/herdr-core` CLI (aliased `hc`). Herdr is a desktop app
that hosts coding agents in `herdr-core`, a small background server, so
agents keep working after the app quits.

- Open the app from the XFCE desktop (via the VNC tunnel) — run `herdr-app`.
- Run `hc` in any shell for background work.
- Docs: <https://herdr.dev/guide>, core: <https://herdr.dev/core>.

Common CLI:

```sh
# start an agent in the background and tell it how to report back
hc run --bg codex "review my diff. Done: hc send t1"

# steer a running task mid-flight
hc send t3 "take another look"

# add a remote machine to the sidebar via SSH
hc machine add vps
```

Configuration lives in `~/.config/herdr-app/` (`AGENTS.md` for what the
agent may change, `settings.json`, `keys.json`, `layouts/`, `mods/`,
`themes/`).

Notes: after a VM reboot the panes come back with plain shells — agents
don't restart by themselves. Agents running inside tmux can't report
status to Herdr; start them in a Herdr pane directly.

Default keys (no tmux-style prefix; chords go straight to Herdr):

| Keys | Action |
| --- | --- |
| `ctrl-shift-t` | new tab |
| `ctrl-shift-o` | split pane right |
| `alt-1` … `alt-9` | jump to space 1–9 |
| `ctrl-shift-pageup` / `ctrl-shift-pagedown` | previous / next panel |
| `ctrl-shift-l` | cycle layouts |
| `ctrl-shift-b` | toggle sidebar |
| `ctrl-shift-c` | copy |

Rebind anything (including a tmux-style prefix if you want one) in
`keys.json`.

## Verification checklist

- `vagrant up` completes cleanly on the libvirt provider.
- Inside the guest: `docker run hello-world`, `aws --version`, `go version`
  (1.26.10), `tmux`, `claude --version` all work.
- Cockpit reachable through its SSH tunnel; VM visible and controllable.
- VNC reachable through its SSH tunnel; XFCE desktop opens and a browser
  runs inside it.
- Clone onto a second physical machine, redo per-machine setup, confirm the
  same checks pass there too.
