#!/usr/bin/env bash
set -euo pipefail

# ~/.bashrc extras for the vagrant user: the Go bin dir (05 installs Go)
# plus a tmux helper and container aliases. Appended once, guarded by a
# marker comment so re-provisioning never duplicates or clobbers edits.
if ! grep -q '^# agent-corral defaults' /home/vagrant/.bashrc 2>/dev/null; then
  cat >> /home/vagrant/.bashrc <<'EOF'

# agent-corral defaults
export PATH="$PATH:$HOME/go/bin"

# tmux alias from https://gist.github.com/lucaspiller/3377737
tm() {
  [[ -z "$1" ]] && { echo "usage: tm <session>" >&2; return 1; }
  tmux has -t $1 && tmux attach -d -t $1 || tmux new -s $1
}

alias docker-clean-stopped='for t in $(docker container ls -aq --filter "status=exited"); do docker container rm $t; done'
alias docker-kill-all='for t in $(docker container ls -aq); do docker rm -f $t; done'
EOF
fi