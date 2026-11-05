#!/usr/bin/env bash
set -euo pipefail

# AWS CLI v2 (pinned version + sha256 of the linux-x86_64 zip)
AWSCLI_VERSION=2.39.2
AWSCLI_SHA256=bb3e675d5c9a915121f3f90b380ec041ba52517067d017e4a4ceba40e0213247
if ! command -v aws >/dev/null 2>&1 || [[ "$(aws --version 2>/dev/null)" != "aws-cli/${AWSCLI_VERSION}"* ]]; then
  tmp_dir=$(mktemp -d)
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip" -o "$tmp_dir/awscliv2.zip"
  echo "${AWSCLI_SHA256}  $tmp_dir/awscliv2.zip" | sha256sum -c -
  unzip -q "$tmp_dir/awscliv2.zip" -d "$tmp_dir"
  "$tmp_dir/aws/install" --update
  rm -rf "$tmp_dir"
fi

# Node.js (LTS)
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
  apt-get install -y nodejs
fi

# Claude Code CLI -- pinned native per-user install, replacing the npm package
CLAUDE_VERSION=2.1.318
CLAUDE_SHA256=708c77b204db30086ff6f1ed34577bda03e1be74ced80557cbf7b54249ebf0bd
CLAUDE_ZST_SHA256=760aaca865c68a315e49d129614a5f5dc9cab99f7de75899257faed68f553f3b
claude_bin="/home/vagrant/.local/share/claude/versions/${CLAUDE_VERSION}"
if npm list -g @anthropic-ai/claude-code >/dev/null 2>&1; then
  npm uninstall -g @anthropic-ai/claude-code
fi
install -d -o vagrant -g vagrant -m 0755 \
  /home/vagrant/.local/bin "/home/vagrant/.local/share/claude/versions"
if [ ! -x "$claude_bin" ]; then
  tmp_dir=$(mktemp -d)
  curl -fsSL "https://downloads.claude.ai/claude-code-releases/${CLAUDE_VERSION}/linux-x64/claude.zst" -o "$tmp_dir/claude.zst"
  echo "${CLAUDE_ZST_SHA256}  $tmp_dir/claude.zst" | sha256sum -c -
  zstd -d -q -c "$tmp_dir/claude.zst" > "$tmp_dir/claude"
  echo "${CLAUDE_SHA256}  $tmp_dir/claude" | sha256sum -c -
  install -o vagrant -g vagrant -m 0755 "$tmp_dir/claude" "$claude_bin"
  rm -rf "$tmp_dir"
fi
ln -sfn "$claude_bin" /home/vagrant/.local/bin/claude

# nono sandbox (pinned version + sha256 of the linux-x86_64 archive)
NONO_VERSION=0.81.0
NONO_SHA256=7ecc33ff9c349bdfa84b4496e7a7555f67bcc33f1e125c7df9efb653c6c4e569
if ! command -v nono >/dev/null 2>&1 || [[ "$(nono --version 2>/dev/null)" != *"${NONO_VERSION}"* ]]; then
  tmp_dir=$(mktemp -d)
  curl -fsSL "https://github.com/nolabs-ai/nono/releases/download/v${NONO_VERSION}/nono-v${NONO_VERSION}-x86_64-unknown-linux-gnu.tar.gz" -o "$tmp_dir/nono.tar.gz"
  echo "${NONO_SHA256}  $tmp_dir/nono.tar.gz" | sha256sum -c -
  tar -xzf "$tmp_dir/nono.tar.gz" -C "$tmp_dir"
  install -m 0755 "$tmp_dir/nono" /usr/local/bin/nono
  rm -rf "$tmp_dir"
fi

# nvm (per-user, ~vagrant) -- LTS Node for interactive shells, npx, skills.
# Must run as the vagrant user since nvm installs into $HOME/.nvm; su (as
# root) needs no sudo. Provisioning itself keeps using the system Node/npm
# above, because this block isn't on root's PATH.
NVM_VERSION=0.40.8
if [ ! -d /home/vagrant/.nvm ]; then
  su - vagrant -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash"
fi
su - vagrant -c '
  export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"
  if ! nvm ls 2>/dev/null | grep -qE "v[0-9]+\."; then
    nvm install --lts
  fi
'

# Ollama -- system install, ships its own systemd service
if ! command -v ollama >/dev/null 2>&1; then
  curl -fsSL https://ollama.com/install.sh | sh
fi

# gh CLI -- backs the git credential helper in 09-default-config.sh
if ! command -v gh >/dev/null 2>&1; then
  apt-get install -y gh
fi
