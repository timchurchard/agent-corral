#!/usr/bin/env bash
set -euo pipefail

# Host-side helper -- NOT part of provisioning. Snapshots the VM and copies
# it (disk + any snapshots, since they live inside the qcow2) to another
# physical machine. Run from a checkout of this repo; needs the `libvirt`
# group on both hosts and the standard /home/libvirt-images pool.
#
# One VM per static IP/MAC across all machines: don't run a copied VM at
# the same time as its source.

VIRSH="virsh -c qemu:///system"

usage() {
  cat <<'USAGE'
Usage (run from a checkout of this repo):
  scripts/10-snapshot.sh list [<machine>]
  scripts/10-snapshot.sh create <snap-name> [<machine>]
  scripts/10-snapshot.sh revert <snap-name> [<machine>]
  scripts/10-snapshot.sh copy <user>@<target-host> [<machine>]

<machine> is the Vagrant machine name (see .vagrant/machines/); it can be
omitted when the checkout has exactly one.
USAGE
  exit 1
}

die() { echo "error: $*" >&2; exit 1; }

# Resolves MACH and DOMAIN from the optional machine name argument ($1).
resolve() {
  local want=$1 machs
  # Only machines that actually exist (have a libvirt id) count
  machs=$(for d in .vagrant/machines/*/; do
            [ -f "$d/libvirt/id" ] && printf '%s\n' "$(basename "$d")"
          done) || true
  [ -n "$machs" ] ||
    die "no created machines -- run 'vagrant up' from the repo checkout first"
  MACH=${want:-$machs}
  [ "$(wc -l <<<"$machs")" -eq 1 ] || [ -n "$want" ] ||
    die "several machines here ($(echo "$machs" | tr '\n' ' ')) -- pass one"
  [ -f ".vagrant/machines/$MACH/libvirt/id" ] ||
    die "machine '$MACH' not created yet (vagrant up [name])"
  DOMAIN=$(cat ".vagrant/machines/$MACH/libvirt/id")
}

ensure_halted() {
  local state
  state=$($VIRSH domstate "$1" 2>/dev/null || echo unknown)
  [ "$state" = "shut off" ] ||
    die "$1 is in state '$state' -- snapshot/revert need it halted: vagrant halt"
}

create() {
  ensure_halted "$DOMAIN"
  $VIRSH snapshot-create-as "$DOMAIN" "$1" --description "via scripts/10-snapshot.sh $(date -Is)"
}

revert() {
  ensure_halted "$DOMAIN"
  $VIRSH snapshot-revert "$DOMAIN" "$1"
}

copy() {
  local target=$1 disk state
  state=$($VIRSH domstate "$DOMAIN" 2>/dev/null || echo unknown)
  if [ "$state" != "shut off" ]; then
    echo "VM in state '$state' -- halting..."
    vagrant halt "$MACH"
  fi
  disk=$($VIRSH domblklist "$DOMAIN" --details | awk '$2 == "disk" { print $4 }')
  [ "$(wc -w <<<"$disk")" -eq 1 ] ||
    die "expected exactly one disk, saw: $(echo "$disk")"
  [ "$(dirname "$disk")" = "/home/libvirt-images" ] ||
    die "disk lives at $disk (not the standard pool) -- copy manually"
  echo "Copying $disk to $target ..."
  rsync -avz --partial --sparse "$disk" "$target:/home/libvirt-images/"
  # The qcow2 carries its internal snapshots with it. Define the domain on
  # the target (same name/UUID/MAC on purpose: only one clone runs at a
  # time, and the static-IP config matches it).
  $VIRSH dumpxml "$DOMAIN" | ssh "$target" "virsh -c qemu:///system define /dev/stdin"
  cat <<EOF

On $target, in that checkout of this repo, adopt the VM with:
  mkdir -p .vagrant/machines/$MACH/libvirt
  echo '$DOMAIN' > .vagrant/machines/$MACH/libvirt/id
  vagrant up    # picks up the copied domain instead of creating one
EOF
}

[ $# -ge 1 ] || usage
action=$1
shift
case "$action" in
  list)   resolve "${1:-}";        $VIRSH snapshot-list "$DOMAIN" ;;
  create) [ $# -ge 1 ] || usage;   resolve "${2:-}"; create "$1" ;;
  revert) [ $# -ge 1 ] || usage;   resolve "${2:-}"; revert "$1" ;;
  copy)   [ $# -ge 1 ] || usage;   resolve "${2:-}"; copy "$1" ;;
  *) usage ;;
esac