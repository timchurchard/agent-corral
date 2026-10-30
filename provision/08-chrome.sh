#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Google Chrome -- no versioned .deb or published digests exist, so we
# install the current stable build from dl.google.com over TLS on first
# provision (curl's -p/--fail guards channel errors). The package's
# postinst adds Google's apt repo and signing key, so later `apt upgrade`
# keeps Chrome current with verified signatures.
if ! command -v google-chrome >/dev/null 2>&1; then
  tmp_dir=$(mktemp -d)
  curl -fsSL "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" -o "$tmp_dir/chrome.deb"
  apt-get install -y "$tmp_dir/chrome.deb"
  rm -rf "$tmp_dir"
fi