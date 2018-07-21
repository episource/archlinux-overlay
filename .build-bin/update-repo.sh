#!/usr/bin/env bash
SCRIPT_DIR=$( dirname $( readlink -e $0 ) )
source "$SCRIPT_DIR/../.build-lib/ci-library.sh"

_do update_repo
