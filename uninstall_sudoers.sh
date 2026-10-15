#!/bin/bash
set -e

FILE="/etc/sudoers.d/sleepless"

if [ -f "$FILE" ]; then
    echo "Removing $FILE"
    sudo rm -f "$FILE"
    echo "Removed $FILE"
else
    echo "File $FILE does not exist; nothing to remove."
fi
