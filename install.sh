#!/bin/sh
# setup temporary directory for cloned repositories and build artifacts
temporary_directory=''

_cleanup() {
    if [ -d "$temporary_directory" ]; then
        rm --recursive --force "$temporary_directory"
    fi
}

# trap sighup sigint sigabrt
trap '_cleanup' 1 2 6

_die() { 
    echo "error: $*" >&2; _cleanup; exit 1 
}

# package name to install is the first passed argument
package="$1"

if [ -z "$package" ]; then _die 'no package name'; fi
if ! command -v 'git' >/dev/null 2>&1; then _die 'command git not found'; fi
if ! command -v 'sudo' >/dev/null 2>&1; then _die 'command sudo not found'; fi

# create temporary directory
temporary_directory="$(mktemp --directory)"
original_directory="${temporary_directory}/original"
custom_directory="${temporary_directory}/custom"

# clone repositories
original_url='https://github.com/void-linux/void-packages'
custom_url='https://codeberg.org/coralpink/void'

git clone --depth 1 "$original_url" "$original_directory" || _die 'git clone failed'
git clone --depth 1 "$custom_url" "$custom_directory" || _die 'git clone failed'

# merge custom templates and shlibs with original repository
cp --recursive "${custom_directory}/srcpkgs"/* --target-directory="${original_directory}/srcpkgs"
cat "${custom_directory}/common/shlibs" >> "${original_directory}/common/shlibs"

# check if passed package name is available
if [ ! -d "${original_directory}/srcpkgs/${package}" ]; then
    _die "package \"${package}\" does not exist"
fi

xbps_src="${original_directory}/xbps-src"

"$xbps_src" binary-bootstrap || _die 'xbps-src binary-bootstrap failed'
"$xbps_src" pkg "$package" || _die 'xbps-src pkg failed'
sudo xbps-install --force --yes --repository "${original_directory}/hostdir/binpkgs" "$package" || _die 'xbps-install failed'

_cleanup
