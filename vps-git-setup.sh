#!/usr/bin/env bash
# =============================================================================
#  vps-git-setup.sh -- Configure git identity and a GitHub deploy SSH key
#
#  Run this BEFORE vps-setup.sh on a fresh host
#
#  It will:
#    1. Prompt for and set git user.email / user.name (global)
#    2. Generate an ed25519 SSH key if one is missing (no passphrase)
#    3. Add github.com to known_hosts
#    4. Print the public key to register as a GitHub deploy key
#
#  Usage:
#    sudo chmod +x vps-git-setup.sh
#    sudo bash vps-git-setup.sh
# =============================================================================

set -euo pipefail

log() { echo "==> $*"; }

# Resolve the home directory we are configuring (root when run via sudo).
HOME_DIR="${HOME:-/root}"
SSH_DIR="$HOME_DIR/.ssh"
KEY_FILE="$SSH_DIR/id_ed25519"

if ! command -v git &>/dev/null; then
  echo "git is not installed. Install it first (apt-get install -y git)." >&2
  exit 1
fi
if ! command -v ssh-keygen &>/dev/null; then
  echo "ssh-keygen not found (install openssh-client)." >&2
  exit 1
fi

# ---- git identity -----------------------------------------------------------
current_email="$(git config --global user.email || true)"
current_name="$(git config --global user.name || true)"

read -r -p "Git email${current_email:+ [$current_email]}: " input_email
email="${input_email:-$current_email}"
while [[ -z "$email" ]]; do
  read -r -p "Git email (required): " email
done

read -r -p "Git name${current_name:+ [$current_name]}: " input_name
name="${input_name:-$current_name}"
while [[ -z "$name" ]]; do
  read -r -p "Git name (required): " name
done

git config --global user.email "$email"
git config --global user.name "$name"
log "git identity set to: $name <$email>"

# ---- ssh deploy key ---------------------------------------------------------
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ -f "$KEY_FILE" ]]; then
  log "SSH key already exists at $KEY_FILE (leaving it untouched)"
else
  log "Generating ed25519 SSH key at $KEY_FILE"
  ssh-keygen -t ed25519 -C "$email" -f "$KEY_FILE" -N ""
fi

# ---- known_hosts ------------------------------------------------------------
KNOWN_HOSTS="$SSH_DIR/known_hosts"
touch "$KNOWN_HOSTS"
chmod 600 "$KNOWN_HOSTS"
if ! ssh-keygen -F github.com -f "$KNOWN_HOSTS" &>/dev/null; then
  log "Adding github.com to known_hosts"
  ssh-keyscan -t rsa,ecdsa,ed25519 github.com >>"$KNOWN_HOSTS" 2>/dev/null
fi

# ---- next steps -------------------------------------------------------------
cat <<EOF

git is configured. Public deploy key (add to the repo as a deploy key with
write access -> https://github.com/dhammaorg/calm-deploy/settings/keys):

$(cat "${KEY_FILE}.pub")

After registering the key you can verify and clone:
  ssh -T git@github.com        # expect a "successfully authenticated" greeting
  git clone the private repository to /opt/dhamma

Then run vps-setup.sh to provision the host.

EOF
