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
        warn) echo -e "$yellow$msg$normal" ;;
        success) echo -e "$green$msg$normal" ;;
        build_step) echo -e "$green$msg$normal" ;;
        command) echo -e "$cyan$msg$normal" ;;
        message) echo -e "$msg" ;;
    esac
}

# Execute command and stop execution if the command fails
# Pass expected_code=exit_code[,exit_code][,exit_code][...] to define a list of
# expected exit codes, that indicate that the operation was successful.
# The default is 0.
function _do() {
    CMD="$@"
    WANTED_RESULT=( 0 )
    
    if [[ "$1" == "expected_code="* ]]; then
        CMD="${@:2}"
        WANTED_RESULT="${1#expected_code=}"
        WANTED_RESULT=( ${WANTED_RESULT//,/ } )
    fi
    
    _log command "$CMD"
    $CMD
    RESULT=$?
    
    for w in ${WANTED_RESULT[@]}; do
        if [[ "$RESULT" -eq $w ]]; then
            return $RESULT
        fi
    done
    
    _log failure "FAILED (Exit Code $RESULT): $CMD";
    exit 1;
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

# Updates or initializes the repository database
function update_repo() {
    _log build_step "Updating repository: $_REPO"
    
    mkdir -p "$REPODIR"
    _REPO="$REPODIR/$REPONAME"
    
    shopt -s nullglob
    _do repo-add --new --remove "$_REPO.db.tar.xz" "$REPODIR"/*.pkg.tar.xz
    shopt -u nullglob
    
    [[ ! -f "$_REPO.db" ]] \
        && _do ln -s "$_REPO.db.tar.xz" "$_REPO.db"
    [[ ! -f "$_REPO.files" ]] \
        && _do ln -s "$_REPO.files.tar.xz" "$_REPO.files"
        
    # Update pacman pkg database
    sudo pacman -Sy
    
    _log success "Done updating repository!"
}

# Build all packages defined in array variable PACKAGES
#   builds all $PACKAGES in the given order
function build_packages() {
    _log build_step "Start building packages: ${PACKAGES[@]}"
    
    for p in "${PACKAGES[@]}"; do
        #if [[ -f "$REPODIR/$p.pkg.tar.xz" ]]; then
        #    _log 
        #    continue
        #fi
    
        cd $p
        _log command "Building pkg: $p"
        PKGEXT=".pkg.tar.xz" PKGDEST="$REPODIR" \
            _do expected_code=0,13 makepkg --noconfirm --nosign --syncdeps --rmdeps --cleanbuild
            
        if [[ $? -eq 13 ]]; then
            _log warn "Skipping pkg (already built): $p"
        fi
        
        update_repo
        cd - > /dev/null
    done
    
    _log success "Done building packages!"
}


_ensure-var "REPODIR"
_ensure-var "REPONAME"