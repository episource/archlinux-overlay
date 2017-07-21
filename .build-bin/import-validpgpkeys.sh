#!/usr/bin/env bash
SCRIPT_DIR=$( dirname $( readlink -e $0 ) )
source "$SCRIPT_DIR/../.build-lib/ci-library.sh"

_do list_packages

# disable ipv6 for key fetching (inside docker!)
# dirmngr must not yet be running
mkdir -p "$HOME/.gnupg"
echo "disable-ipv6" > "$HOME/.gnupg/dirmngr.conf"

# `gpg --recv-key` requires write access to the current user's home directory!
_do gpg --recv-key $(get_validpgpkeys)
