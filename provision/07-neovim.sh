#!/usr/bin/env bash
set -euo pipefail

# Neovim (pinned version) -- tarball install (official prebuilt from GitHub),
# apt's neovim lags releases. Lives in /opt/nvim, symlinked onto PATH.
NVIM_VERSION=0.12.6
# sha256 of nvim-linux-x86_64.tar.gz for this release (Neovim publishes no
# checksum file, so this was computed from the release artifact itself)
NVIM_SHA256=474430d53e6264f6d6dd18db42d6dc9df3a1b56ca9e88a325bbf860e1a811d87

if ! command -v nvim >/dev/null 2>&1 || [[ "$(nvim --version 2>/dev/null | head -n1)" != *"v${NVIM_VERSION}"* ]]; then
  tmp_dir=$(mktemp -d)
  curl -fsSL "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-x86_64.tar.gz" -o "$tmp_dir/nvim.tar.gz"
  echo "${NVIM_SHA256}  $tmp_dir/nvim.tar.gz" | sha256sum -c -
  rm -rf /opt/nvim /opt/nvim-linux-x86_64
  tar -C /opt -xzf "$tmp_dir/nvim.tar.gz"
  mv /opt/nvim-linux-x86_64 /opt/nvim
  ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
  ln -sf /opt/nvim/bin/nvim /usr/local/bin/vim
  rm -rf "$tmp_dir"
fi

# tree-sitter CLI -- nvim-treesitter main needs 0.26.1+, newer than Debian's
TREE_SITTER_VERSION=0.27.1
TREE_SITTER_SHA256=d01042f94ba3d6827ddc9788e235f75d8366431be42bdf90ade534d960c98b7d
if ! command -v tree-sitter >/dev/null 2>&1 || [[ "$(tree-sitter --version 2>/dev/null)" != *"${TREE_SITTER_VERSION}"* ]]; then
  tmp_dir=$(mktemp -d)
  curl -fsSL "https://github.com/tree-sitter/tree-sitter/releases/download/v${TREE_SITTER_VERSION}/tree-sitter-linux-x64.gz" -o "$tmp_dir/tree-sitter.gz"
  echo "${TREE_SITTER_SHA256}  $tmp_dir/tree-sitter.gz" | sha256sum -c -
  gzip -dc "$tmp_dir/tree-sitter.gz" > "$tmp_dir/tree-sitter"
  install -m 0755 "$tmp_dir/tree-sitter" /usr/local/bin/tree-sitter
  rm -rf "$tmp_dir"
fi
