#!/usr/bin/env bash
SCRIPT_DIR=$( dirname $( readlink -e $0 ) )
source "$SCRIPT_DIR/../.build-lib/ci-library.sh"

_do list_packages


# sort repository packages based on (inter-)dependency hierarchy
# - it is assumed that the repository contains only compatible package
#   versions, hence version information is ignored. If this assumption
#   does not hold, makepkg will fail later on
_do sort_packages_by_dependency
_do build_packages