#!/usr/bin/env bash
SCRIPT_DIR=$( dirname $( readlink -e $0 ) )
source "$SCRIPT_DIR/.build_lib.sh"

_REPO="${REPODIR}/${REPONAME}"

_log build_step "Start creating repository: ${_REPO}"
_do repo-add "${_REPO}.db.tar.xz" "${BINDIR}"/*.pkg.tar.xz
_log success "Done creating repository!"