#!/usr/bin/env bash
set -euo pipefail

# User skills (repo: skills/<name>/SKILL.md) -> clone to ~/src/skills and
# symlink each skill into ~/.claude/skills. Runs as the vagrant user.
# GIT_CONFIG_* are cleared because 09-default-config.sh's insteadOf rewrite
# sends github https URLs to ssh, and provisioning has no ssh keys to give;
# the repo is public, so plain https works.

SKILLS_URL=https://github.com/timchurchard/skills
SKILLS_SRC=$HOME/src/skills

if [ -d "$SKILLS_SRC/.git" ]; then
  git -C "$SKILLS_SRC" pull --ff-only >/dev/null 2>&1 || true
else
  mkdir -p "$(dirname "$SKILLS_SRC")"
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    git clone --depth 1 "$SKILLS_URL" "$SKILLS_SRC"
fi

SKILL_DIR="$SKILLS_SRC/skills"
[ -d "$SKILL_DIR" ] || SKILL_DIR=$SKILLS_SRC
mkdir -p "$HOME/.claude/skills"
for dir in "$SKILL_DIR"/*/; do
  [ -f "$dir/SKILL.md" ] || continue
  ln -sfn "$dir" "$HOME/.claude/skills/$(basename "$dir")"
done