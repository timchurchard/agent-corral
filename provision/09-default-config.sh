#!/usr/bin/env bash
set -euo pipefail

# Default ~/.gitconfig for the vagrant user -- aliases, GitHub URL rewrite
# and the gh credential helper from the maintainer's setup. First-write
# only: an existing .gitconfig (or later manual edits) is never clobbered.
# Name/email stay a manual step (README) since commits should not carry a
# machine-provisioned identity.
CONF=/home/vagrant/.gitconfig
if [ ! -e "$CONF" ]; then
  cat > "$CONF" <<'EOF'
[alias]
    br = branch -vva
    bd = log --oneline --cherry --date=short --pretty=format:'%Cred%h %Cgreen%an %Cblue%ad %Creset%s'
    bdv = log --cherry
    ca = commit --amend --date="now"
    ci = commit
    co = checkout
    cp = cherry-pick
    df = diff
    dl = fetch --prune
    lg = log --stat --show-signature
    lgv = log --graph --abbrev-commit --decorate --date=relative --all
    lgs = log --oneline --decorate --date=relative --pretty=format:'%Cred%h%Creset%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'
    me = merge --ff-only
    mt = mergetool
    st = status
    up = rebase
    sq = rebase -i
    gca = gc --aggressive --prune
    su = submodule update --init --recursive
    spush = push --recurse-submodules=on-demand
    stu = status -uno
    ss = stash
[url "git@github.com:"]
    insteadOf = https://github.com/
[credential "https://github.com"]
	helper =
	helper = !/usr/bin/gh auth git-credential
[credential "https://gist.github.com"]
	helper =
	helper = !/usr/bin/gh auth git-credential
EOF
  chown vagrant:vagrant "$CONF"
  chmod 600 "$CONF"
fi