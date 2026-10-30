#!/usr/bin/env bash
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

usermod -aG docker vagrant

systemctl enable --now docker

# ctop (pinned version + sha256)
CTOP_VERSION=0.7.7
CTOP_SHA256=b78374734ebe3d14b6edee3d5512c911c250d7fa7f3f964cb00acd3bc5a02a09
if ! command -v ctop >/dev/null 2>&1; then
  tmp_dir=$(mktemp -d)
  curl -fsSL "https://github.com/bcicen/ctop/releases/download/v${CTOP_VERSION}/ctop-${CTOP_VERSION}-linux-amd64" -o "$tmp_dir/ctop"
  echo "${CTOP_SHA256}  $tmp_dir/ctop" | sha256sum -c -
  install -m 0755 "$tmp_dir/ctop" /usr/local/bin/ctop
  rm -rf "$tmp_dir"
fi
