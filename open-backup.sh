#!/usr/bin/env zsh
SCRIPT_DIR=$(dirname $0:A)
gpg -d --passphrase-file $SCRIPT_DIR/auth.env --batch $1 | tar xzvf -
