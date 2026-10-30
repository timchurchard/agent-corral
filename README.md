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

Most of these run straight from the host with `vagrant ssh -c` — no need
to enter an interactive session:

```sh
vagrant ssh -c "git config --global user.name '...'"
vagrant ssh -c "git config --global user.email '...'"
vagrant ssh -c "vncpasswd"
```

The VNC password is the one manual gate on the desktop: the `vncserver@:1`
unit is installed but deliberately not enabled until it's set. Start the
desktop once it's done:

```sh
vagrant ssh -c "sudo systemctl enable --now vncserver@:1"
```

A few steps do need a real interactive session — open one with
`vagrant ssh`:

- `claude` — log in on first run (needs its interactive prompt/TUI).
- Authorize a host SSH key on the VM — needed for `ssh vagrant@<vm-ip>`
  (the VNC tunnel further down), `ssh devbox` if you set up that SSH
  alias, and `hc machine add`. `ssh-copy-id` against the VM has to be
  pointed at the per-machine Vagrant key under `.vagrant/machines/...`,
  which is easy to fumble — piping through vagrant sidesteps it:

  ```sh
  cat ~/.ssh/<your-key>.pub | vagrant ssh -c \
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
  ```
- Personal credentials aren't provisioned. For git pushes from inside the
  VM use agent forwarding, opt in per session with the destination scoped —
  no private key ever lands on the guest, and the forwarded agent refuses
  to sign for anything but GitHub:

  ```sh
  vagrant ssh -- -A -o PermitRemoteOpen=github.com:22
  ```

  (Vagrant runs ssh with its own config file, so scoping goes on the
  command line, not `~/.ssh/config` — for plain `ssh devbox` sessions a
  `Match` block in `~/.ssh/config` works the same way.)
  For anything else you may want to copy material in manually, e.g.
  `rsync ~/.aws/` or a `~/.ssh/id_whatever_key` into the VM (then
  `chmod 600` inside it), or run `gh auth login` / `aws sso login` there.

## Remote access from outside the house

Manage/inspect the VM (start/stop/snapshot, console view) via Cockpit:

```sh
ssh -L 9090:localhost:9090 <user>@<physical-host>
# then open https://localhost:9090 locally
```

Use the actual desktop (browser, GUI IDE) inside the VM via VNC. The server
binds to localhost inside the guest only, so connect through an SSH tunnel
to the VM itself — from the physical host, or with `-J` from anywhere
further away (VNC traffic stays inside the tunnel). The `vagrant@`
connection needs one of your keys authorized on the VM
(`vagrant ssh -c` one-liner in the manual steps above):

```sh
ssh -L 5901:localhost:5901 vagrant@192.168.121.10
# from a remote machine, jump via the physical host:
ssh -J <user>@<physical-host> -L 5901:localhost:5901 vagrant@192.168.121.10
# then point a VNC client at localhost:5901
```

## Host-side helper scripts

`scripts/10-snapshot.sh` is a host-side convenience (not part of
provisioning). Run it from a checkout of this repo:

```sh
scripts/10-snapshot.sh create <snap-name>   # VM halted (it refuses if up)
scripts/10-snapshot.sh list                 # or .revert / .copy
scripts/10-snapshot.sh revert <snap-name>
scripts/10-snapshot.sh copy <user>@<target-host>   # halts, copies the disk
```

The copy carries internal snapshots along (they live inside the qcow2),
defines the domain on the target as-is (same name/UUID/MAC — only one
clone may run at a time), and prints the two commands that make Vagrant
adopt it there.

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
