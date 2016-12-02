# Based upon https://github.com/Alexpux/MINGW-packages/blob/master/ci-library.sh


PACKAGES=()

# Print a colored log message
function _log() {
    local type="${1}"
    shift
    local msg="${@}"
    
    local normal='\e[0m'
    local red='\e[1;31m'   
    local green='\e[1;32m'
    local yellow='\e[1;33m'
    local cyan='\e[1;36m'
    
    case "${type}" in
        failure) echo -e "$red$msg$normal" ;;
        success) echo -e "$green$msg$normal" ;;
        build_step) echo -e "$green$msg$normal" ;;
        command) echo -e "$cyan$msg$normal" ;;
        message) echo -e "$msg" ;;
    esac
}

# Execute command and stop execution if the command fails
function _do() {
    CMD=$@
    _log command "$CMD"
    $CMD || { _log failure "FAILED: $CMD"; exit 1; }
    return $?
}

# Ensure that the given environment variable has been defined and is not empty
function _ensure-var() {
    local -n VARNAME=$1
    if [[ -z ${VARNAME+x} ]]; then
        _log failure "Environment variable $1 not defined."
        exit 1
    fi
}


# Package provides another (ignoring version constraints)
function _package_provides() {
    local package="${1}"
    local another_without_version="${2%%[<>=]*}"
    local pkgname provides
    _package_info "${package}" pkgname provides
    for pkg_name in "${pkgname[@]}";  do [[ "${pkg_name}" = "${another_without_version}" ]] && return 0; done
    for provided in "${provides[@]}"; do [[ "${provided}" = "${another_without_version}" ]] && return 0; done
    return 1
}

# Get package information
function _package_info() {
    local package="${1}"
    local properties=("${@:2}")
    for property in "${properties[@]}"; do
        local -n nameref_property="${property}"
        nameref_property=($(
            source "${package}/PKGBUILD"
            declare -n nameref_property="${property}"
            echo "${nameref_property[@]}"))
    done
}

# Add package to build after required dependencies
function _build_add() {
    local package="${1}"
    local depends makedepends
    for sorted_package in "${sorted_packages[@]}"; do
        [[ "${sorted_package}" = "${package}" ]] && return 0
    done
    _package_info "${package}" depends makedepends
    for dependency in "${depends[@]}" "${makedepends[@]}"; do
        for unsorted_package in "${PACKAGES[@]}"; do
            [[ "${package}" = "${unsorted_package}" ]] && continue
            _package_provides "${unsorted_package}" "${dependency}" && _build_add "${unsorted_package}"
        done
    done
    sorted_packages+=("${package}")
}

# list packages
#   adds the names of all subdirectories containing a PKGBUILD file to the
#   $PACKAGES array
function list_packages() {
    for p in $(ls **/PKGBUILD); do
        PACKAGES+=(${p/%\/PKGBUILD/})
    done
}

# extracts all 'validpgpkeys' from the PKGBUILDs
#   extracts all 'validpgpkeys' listed in the PKGBUILDs belonging to $PACKAGES
function get_validpgpkeys() {
    _VALIDPGPKEYS=()
    for p in "${PACKAGES[@]}"; do
        local validpgpkeys=()
        _package_info "$p" validpgpkeys
        _VALIDPGPKEYS+=$validpgpkeys
    done
    
    echo "${_VALIDPGPKEYS[@]}"
}

# Sort packages by dependency
#   reorders $PACKAGES such that dependencies are built first
function sort_packages_by_dependency() {
    local sorted_packages=()
    for p in "${PACKAGES[@]}"; do
        _build_add "${p}"
    done
    PACKAGES=("${sorted_packages[@]}")
}

# Build all packages defined in array variable PACKAGES
#   builds all $PACKAGES in the given order
function build_packages() {
    _log build_step "Start building packages: ${PACKAGES[@]}"
    _do mkdir -p "$REPODIR"
    
    for p in "${PACKAGES[@]}"; do
        cd $p
        _log command "Building pkg: $p"
        PKGEXT=".pkg.tar.xz" PKGDEST="$REPODIR" \
            _do makepkg --install --noconfirm --nosign --syncdeps --cleanbuild
        cd - > /dev/null
    done
    
    _log success "Done building packages!"
}


_ensure-var "REPODIR"
_ensure-var "REPONAME"