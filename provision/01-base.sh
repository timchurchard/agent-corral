#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get upgrade -y
apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  unzip \
  jq \
  git \
  tmux \
  zsh \
  zstd \
  htop \
  rsync \
  bubblewrap \
  socat \
  ripgrep \
  seccomp \
  build-essential
