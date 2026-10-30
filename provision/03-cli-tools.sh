#!/usr/bin/env bash
set -euo pipefail

# AWS CLI v2
if ! command -v aws >/dev/null 2>&1; then
  tmp_dir=$(mktemp -d)
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$tmp_dir/awscliv2.zip"
  unzip -q "$tmp_dir/awscliv2.zip" -d "$tmp_dir"
  "$tmp_dir/aws/install"
  rm -rf "$tmp_dir"
fi

# Node.js (LTS) -- needed to install the Claude Code CLI via npm
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
  apt-get install -y nodejs
fi

# Claude Code CLI
if ! command -v claude >/dev/null 2>&1; then
  npm install -g @anthropic-ai/claude-code
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
