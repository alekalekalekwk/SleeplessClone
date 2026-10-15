#!/bin/bash
set -e

USER_NAME="$(whoami)"
TMP_FILE="$(mktemp /tmp/sleepless_sudoers.XXXXXX)"

cleanup() {
    rm -f "$TMP_FILE"
}
trap cleanup EXIT

cat << EOF > "$TMP_FILE"
$USER_NAME ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0
$USER_NAME ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1
EOF

echo "Validating sudoers configuration..."
visudo -cf "$TMP_FILE"

echo "Installing /etc/sudoers.d/sleepless..."
sudo install -m 0440 -o root -g wheel "$TMP_FILE" /etc/sudoers.d/sleepless

echo "Successfully installed /etc/sudoers.d/sleepless"
