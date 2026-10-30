#!/usr/bin/env bash
set -euo pipefail

# Neovim (pinned version) -- tarball install (official prebuilt from GitHub),
# apt's neovim lags releases. Lives in /opt/nvim, symlinked onto PATH.
NVIM_VERSION=0.12.6

if ! command -v nvim >/dev/null 2>&1 || [[ "$(nvim --version 2>/dev/null | head -n1)" != *"v${NVIM_VERSION}"* ]]; then
  tmp_dir=$(mktemp -d)
  curl -fsSL "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-x86_64.tar.gz" -o "$tmp_dir/nvim.tar.gz"
  rm -rf /opt/nvim /opt/nvim-linux-x86_64
  tar -C /opt -xzf "$tmp_dir/nvim.tar.gz"
  mv /opt/nvim-linux-x86_64 /opt/nvim
  ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
  rm -rf "$tmp_dir"
fi