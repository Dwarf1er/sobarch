#!/usr/bin/env bash
# Generates an ed25519 SSH key for the new account (if it doesn't
# already have one) and, if the TUI's Git screen (installer/tui/
# screens/git.py) collected an identity, sets it as user.name/
# user.email in the account's global git config.
#
# SSH-only, deliberately: no credential-helper/HTTPS path is set up
# here (see docs/DECISIONS.md). ssh-keygen is already available since
# openssh is a base dependency for the optional SSH server component
# (installer/firstboot/apply-security-baseline.sh), so this needs no
# new package.
#
# Must run as the target user, not root: it writes into that user's
# $HOME. sobarch-firstboot-git.service runs it via systemd's User=,
# which populates $HOME/$USER itself, same as apply-skel.sh.

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

# Absent (e.g. a hand-run archinstall config outside the TUI) means
# "no identity", same default-to-off pattern as SSH_FLAG in
# apply-security-baseline.sh: the SSH key above is still generated
# either way, since it needs no identity to be useful.
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
