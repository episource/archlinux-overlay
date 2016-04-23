#!/usr/bin/env bash
SCRIPT_DIR=$( dirname $( readlink -e $0 ) )
source "$SCRIPT_DIR/.build_lib.sh"

# sort repository packages based on dependency hierarchy
# - it is assumed that the repository contains only compatible package
#   versions, hence version information is ignored. If this assumption
#   does not hold, makepkg will fail later on
list_packages
sort_packages_by_dependency
build_packages