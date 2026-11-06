#!/usr/bin/env bash
# Prepares a fresh Fedora machine and runs the full installer.
#
# Run it like this, not with "curl | bash", because the steps are interactive:
#   bash <(curl -fsSL https://raw.githubusercontent.com/SantaVC/fedora-bootstrap/main/setup.sh)

set -euo pipefail

readonly SETTINGS_REPO="SantaVC/Fedora_Settings"
readonly SETTINGS_DIR="$HOME/Development/Repositories/Fedora_Settings"

die() {
  echo "error: $*" >&2
  exit 1
}

# 1. Check the machine.
# shellcheck disable=SC1091
[[ "$(. /etc/os-release && echo "$ID")" == "fedora" ]] || die "this script only supports Fedora"
[[ "$(id -u)" != "0" ]] || die "do not run as root, the script calls sudo itself"
sudo -v || die "sudo must work for this user"

# 2. Install what the next steps need.
sudo dnf install -y git gh

# 3. Log in to GitHub. The device code flow can be completed on a phone.
gh auth status >/dev/null 2>&1 || gh auth login -h github.com -p https -w
gh auth setup-git

# 4. Get the settings repo, without ever overwriting local work.
if [[ -d "$SETTINGS_DIR/.git" ]]; then
  if [[ -n "$(git -C "$SETTINGS_DIR" status --porcelain)" ]]; then
    echo "warning: $SETTINGS_DIR has uncommitted changes, not pulling" >&2
  else
    git -C "$SETTINGS_DIR" pull --ff-only || die "cannot fast-forward $SETTINGS_DIR, resolve it by hand"
  fi
else
  mkdir -p "$(dirname "$SETTINGS_DIR")"
  git clone "https://github.com/$SETTINGS_REPO.git" "$SETTINGS_DIR"
fi

# 5. Get the installer from the latest release, so this machine does not need Go.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
gh release download --repo "$SETTINGS_REPO" --pattern installer --dir "$tmp" \
  || die "cannot download the installer, does $SETTINGS_REPO have a release?"
chmod +x "$tmp/installer"

# 6. Show what would change, and only change it after a yes. Plan exits non-zero
# when a step is blocked, which is worth reading but not a reason to stop here.
"$tmp/installer" plan || true
echo
read -rp "Apply these changes? [y/N] " answer
[[ "$answer" == [yY]* ]] || { echo "Nothing changed."; exit 0; }

"$tmp/installer" apply
