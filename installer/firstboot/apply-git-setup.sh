#!/usr/bin/env bash
# Generates an ed25519 SSH key for the new user and applies the git identity
# collected by the TUI, if any. Runs as the target user, not root.

set -euo pipefail

FLAG_FILE="/etc/sobarch/git-identity"
STATE_DIR="$HOME/.local/state/sobarch"
MARKER="$STATE_DIR/git-setup-done"
SSH_KEY="$HOME/.ssh/id_ed25519"

mkdir -p "$STATE_DIR"

if [[ ! -f "$SSH_KEY" ]]; then
    echo "apply-git-setup: generating an ed25519 SSH key..."
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -N "" -C "$(whoami)@$(hostname)" -f "$SSH_KEY" -q
fi

git_name=""
git_email=""
if [[ -f "$FLAG_FILE" ]]; then
    git_name="$(sed -n '1p' "$FLAG_FILE")"
    git_email="$(sed -n '2p' "$FLAG_FILE")"
fi

if [[ -n "$git_name" && -n "$git_email" ]]; then
    echo "apply-git-setup: setting git user.name/user.email..."
    git config --global user.name "$git_name"
    git config --global user.email "$git_email"
fi

touch "$MARKER"
echo "apply-git-setup: done. Public key ($SSH_KEY.pub), add it to your git host:"
cat "$SSH_KEY.pub"
