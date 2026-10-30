#!/usr/bin/env bash
set -euo pipefail

# Go (pinned version) -- tarball install, apt's golang is too old
GO_VERSION=1.26.10

if ! command -v go >/dev/null 2>&1 || [[ "$(go version 2>/dev/null)" != *"go${GO_VERSION}"* ]]; then
  tmp_dir=$(mktemp -d)
  curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o "$tmp_dir/go.tar.gz"
  rm -rf /usr/local/go
  tar -C /usr/local -xzf "$tmp_dir/go.tar.gz"
  ln -sf /usr/local/go/bin/go /usr/local/bin/go
  ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
  rm -rf "$tmp_dir"
fi