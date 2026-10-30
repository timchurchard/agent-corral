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
  zstd \
  htop \
  rsync \
  build-essential
