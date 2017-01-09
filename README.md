# archlinux-overlay
This repository contains a collection of custom [PKGBUILD](https://wiki.archlinux.org/index.php/PKGBUILD) scripts for [Arch Linux](https://wiki.archlinux.org/index.php/Arch_Linux).

The repository includes all necessary configuration files to build the corresponding binary package repository with [GitLab-CI](https://about.gitlab.com/gitlab-ci/). Nevertheless, the packages can also be build manually or using other CI-tools.


## About PKGBUILD and makepkg
A [PKGBUILD](https://wiki.archlinux.org/index.php/PKGBUILD) is a shell script providing all information required by the [makepkg](https://wiki.archlinux.org/index.php/Makepkg) utility to build a binary package for [Arch Linux](https://wiki.archlinux.org/index.php/Arch_Linux) and its package manager [pacman](https://wiki.archlinux.org/index.php/Pacman).

More information on [how to create packages](https://wiki.archlinux.org/index.php/Creating_packages) can be found in the [Arch Linux Wiki](https://wiki.archlinux.org/).


## Building the packages

**Important:** The build scripts (`.build-bin/*` , `.build-lib/*`) are designed to be run in a dedicated container or virtual machine. Don't run these scripts on your main machine! You have been warned!

### ... using GitLab & GitLab-CI
This repository already includes a pre-configured [.gitlab-ci.yml](https://docs.gitlab.com/ce/ci/yaml/README.html) configuration file for [Gitlab-CI](https://about.gitlab.com/gitlab-ci/). It uses a [docker runner](https://docs.gitlab.com/ce/ci/docker/using_docker_images.html) to build the packages in a docker container using [`nfnty/arch-devel:latest`](https://hub.docker.com/r/nfnty/arch-devel/) as image.

**All you need to do:** Read about [the gitlab runner](https://docs.gitlab.com/runner/) and [using docker images](https://docs.gitlab.com/ce/ci/docker/using_docker_images.html) to configure GitLab and GitLab-CI, such that a docker runner and the docker image [`nfnty/arch-devel:latest`](https://hub.docker.com/r/nfnty/arch-devel/) are available to your `archlinux-overlay` gitlab project.

Currently all packages are rebuild when going this way. The resulting repository is available for [download as a tar or zip archive](https://gitlab.com/help/user/project/builds/artifacts.md#downloading-build-artifacts), but can also be made available to pacman directly: Just append the snippet below to [/etc/pacman.conf](https://www.archlinux.org/pacman/pacman.conf.5.html) and adjust the `build-id` and url. Sadly, until [gitlab-org/gitlab-ce#22536](https://gitlab.com/gitlab-org/gitlab-ce/issues/22536) is implemented, there's no simple way to refer to the most recent `master`-branch build directly. 

```
[archlinux-overlay]
Server = http(s)://gitlab.your-host.local/your-group/$repo/builds/<build_id>/artifacts/file/
SigLevel = Optional TrustAll

# Gitlab's only way to provide a direct link to the latest build requires adding
# a query string to the url, which is not suitable for pacman.
# See issue gitlab-org/gitlab-ce#22536.
# Workaround: provide entries for future builds! Urls are tried sequentially.
# Server = http(s)://gitlab.your-host.local/your-group/$repo/builds/<build_id - 1>/artifacts/file/
# Server = http(s)://gitlab.your-host.local/your-group/$repo/builds/<build_id - 2>/artifacts/file/
# ...
```

Build artifacts (the repository) are deleted automatically after one week. Goto to the [build's page](https://gitlab.com/help/user/project/builds/artifacts.md#browsing-build-artifacts) and choose "keep" to preserve the repository for an unlimited time.

### ... using a custom build environment
The build environment needs to be based on [Arch Linux](https://wiki.archlinux.org/index.php/Arch_Linux). If a dockerized build environment is an option, take a look at the docker image [`nfnty/arch-devel`](https://hub.docker.com/r/nfnty/arch-devel/), which is a good point to start.

**Important:** During package build, packages may be installed or replaced and public keys might be added to the build user's keyring.

Here are the configuration steps required in addition to setting up the operating system: 
1. Install the meta-package `base-devel`: `pacman -S --needed base-devel`
2. Optional - adjust `/etc/makepkg.conf` to your needs - see [makepkg.conf(5)](https://www.archlinux.org/pacman/makepkg.conf.5.html) and [Creating optimized packages](https://wiki.archlinux.org/index.php/Makepkg#Creating_optimized_packages) for details.
3. Choose or create a user account for building the packages (below referred to as `the-user`):
  * it needs to be a restricted (non-root) user account
  * it will be granted permission to invoke (sudo) pacman as root without password
  * it needs a writable home directory
  * keys might be added to it's public keyring during build
4. Grant `the-user` the right to invoke `pacman` as root: `echo 'the-user ALL=(ALL) NOPASSWD: /usr/bin/pacman' >> /etc/sudoers`

From now on, the whole repository is build with these steps:
1. Checkout the `archlinux-overlay` git repository or make it available by other means (docker volume, ...)
2. Login as / change to user `the-user`
3. Optional, but recommended - update the system: `sudo pacman -Syu --noconfirm`
4. Change to the repository's source directory
5. Choose a binary repository location & name: `export REPONAME="archlinux-overlay" && export REPODIR="_repo"`
6. Import missing [validpgpkeys](https://wiki.archlinux.org/index.php/PKGBUILD#validpgpkeys): `.build-bin/import-validpgpkeys.sh`
7. Build the whole repository: `.build-bin/build.sh`
8. Create the repository: `.build-bin/deploy.sh`

Any binary package found within `REPODIR` won't be rebuild until the PKGBUILD version has changed. Packages are replaced by newer versions, if available, and the old package's files are removed.

Steps 5-8 could also be scripted using the CI-build library `.build-lib/ci-library.sh`:
```bash
#!/usr/bin/env bash
source "$REPO_SOURCE_PATH/.build-lib/ci-library.sh"


# list & sort repository packages based on (inter-)dependency hierarchy
# - it is assumed that the repository contains only compatible package versions,
#   hence version information is ignored. If this assumption does not hold,
#   makepkg will fail later on
_do list_packages
_do sort_packages_by_dependency

# add validpgpkeys to the current user's public keyring
_do gpg --recv-key $(get_validpgpkeys)

# build packages in the order calculated above
_do build_packages

# create / update the repository
mkdir -p "$REPODIR"
_do repo-add --new "${REPODIR}/${REPONAME}.db.tar.xz" "${REPODIR}"/*.pkg.tar.xz
[[ ! -f "${REPODIR}/${REPONAME}.db" ]] \
    && ln -s "${REPODIR}/${REPONAME}.db.tar.xz" "${REPODIR}/${REPONAME}.db"
[[ ! -f "${REPODIR}/${REPONAME}.files" ]] \
    && ln -s "${REPODIR}/${REPONAME}.files.tar.xz" "${REPODIR}/${REPONAME}.files"
```

### ... manually
You can always build single packages using [makepkg](https://wiki.archlinux.org/index.php/Makepkg). This requires you to take care of dependencies manually. You might also need to import the public keys listed as [validpgpkeys](https://wiki.archlinux.org/index.php/PKGBUILD#validpgpkeys) into your user's keyring.

Building single packages this way is generally considered safe, so it is usually OK to do this on your main machine. However, you shouldn't use a root account. Makepkg even enforces this.

Here's what to do:
1. Go to a PKGBUILDs directory `cd my-package`
2. Invoke makepkg `makepkg`

Now the package can be installed using `pacman -U /path/to/my-package.tar.xz`.

If makepkg reports missing dependencies you are required to install them manually. Keep in mind, that these dependencies might be part of the `archlinux-overlay` repository and hence could require building them manually, too.

If makepkg fails with `ERROR: One or more PGP signatures could not be verified!`, there are two possible reasons: 1) The source file signatures have been modified or 2) the user account invoking `makepkg` is missing a key. In the later case, look for a `validpgpkeys` array in the PKGBUILD and add these keys to your keyring using `_do gpg --recv-key`.