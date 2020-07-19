#!/usr/bin/env bash
SCRIPT_DIR=$( dirname $( readlink -e $0 ) )
source "$SCRIPT_DIR/../.build-lib/ci-library.sh"

_do list_packages

DIRMNGR_CONF="$HOME/.gnupg/dirmngr.conf"

# disable ipv6 for key fetching (inside docker!)
# dirmngr must not yet be running
mkdir -p "$HOME/.gnupg"
echo "disable-ipv6" > "$DIRMNGR_CONF"

if [[ -n "$KEYSERVER" ]]; then
  echo "keyserver $KEYSERVER" >> "$DIRMNGR_CONF"
fi

if [[ -n "$KEYSERVER_CACERT" ]]; then
    if [[ ! "$KEYSERVER_CACERT" == "https://"* ]]; then
        _log failure "Cacert url is not https! Refusing to load: $KEYSERVER_CACERT"
        exit 1
    fi
    
    CACERT_PATH="$HOME/.gnupg/keyserver_cacert.pem"
    curl "$KEYSERVER_CACERT" -o "$CACERT_PATH"
    echo "hkp-cacert $CACERT_PATH" >> "$DIRMNGR_CONF"
fi

# `gpg --recv-key` requires write access to the current user's home directory!
_do gpg --recv-key $(get_validpgpkeys)
