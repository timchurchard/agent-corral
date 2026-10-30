#!/usr/bin/env bash
set -euo pipefail

# herdr (per-user install) -- runs as the vagrant user (privileged: false in
# the Vagrantfile), installs to ~/.local/bin
if ! command -v herdr-app >/dev/null 2>&1; then
  curl -fsSL https://releases.herdr.dev/app/install.sh | sh
fi