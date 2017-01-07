#!/usr/bin/env bash
SCRIPT_DIR=$( dirname $( readlink -e $0 ) )
source "$SCRIPT_DIR/../.build-lib/ci-library.sh"

mkdir -p "$REPODIR"
_REPO="$REPODIR/$REPONAME"


_log build_step "Start creating repository: $_REPO"
_do repo-add --new --remove "$_REPO.db.tar.xz" "$REPODIR"/*.pkg.tar.xz
[[ ! -f "$_REPO.db" ]] \
    && _do ln -s "$_REPO.db.tar.xz" "$_REPO.db"
[[ ! -f "$_REPO.files" ]] \
    && _do ln -s "$_REPO.files.tar.xz" "$_REPO.files"
_log success "Done creating repository!"