#!/usr/bin/env bash
SCRIPT_DIR=$( dirname $( readlink -e $0 ) )
source "$SCRIPT_DIR/../.build-lib/ci-library.sh"

_do list_packages


# `gpg --recv-key` requires write access to the current user's home directory!
_do gpg --recv-key $(get_validpgpkeys)