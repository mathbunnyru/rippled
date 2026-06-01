#!/bin/bash
# Install sanitizer runtime libraries required to run binaries compiled with:
#   -fsanitize=address   → libasan.so.8
#   -fsanitize=thread    → libtsan.so.2
#   -fsanitize=undefined → libubsan.so.1
#
# These versions ship with GCC 12. Supported base images:
#   debian:bookworm  — GCC 12 is the default compiler
#   ubuntu:20.04     — GCC 9 is the default; GCC 12 libs installed via PPA
#   rhel:9           — GCC 11 is the default; GCC 12 libs installed via gcc-toolset-12
#   nixos/nix        — tests are skipped; this script is not called

set -euo pipefail

if [ ! -f /etc/os-release ]; then
    echo "ERROR: /etc/os-release not found; cannot detect OS" >&2
    exit 1
fi

# shellcheck source=/dev/null
. /etc/os-release

echo "Detected OS: ${ID} ${VERSION_ID:-}"

case "${ID}" in
    debian)
        apt-get update -y
        apt-get install -y --no-install-recommends \
            libasan8 \
            libtsan2 \
            libubsan1
        rm -rf /var/lib/apt/lists/*
        ;;

    ubuntu)
        apt-get update -y
        apt-get install -y --no-install-recommends \
            gnupg \
            software-properties-common
        add-apt-repository -y ppa:ubuntu-toolchain-r/test
        apt-get update -y
        apt-get install -y --no-install-recommends \
            libasan8 \
            libtsan2 \
            libubsan1
        rm -rf /var/lib/apt/lists/*
        ;;

    rhel | centos | rocky | almalinux)
        # gcc-toolset-12 installs GCC 12 runtime libraries under
        # /opt/rh/gcc-toolset-12/root/usr/lib64/. Make them visible to the
        # dynamic linker by adding that path to ld.so.conf.d.
        dnf install -y gcc-toolset-12
        echo "/opt/rh/gcc-toolset-12/root/usr/lib64" \
            >/etc/ld.so.conf.d/gcc-toolset-12.conf
        ldconfig
        ;;

    *)
        echo "ERROR: unsupported OS '${ID}'. Supported: debian, ubuntu, rhel" >&2
        exit 1
        ;;
esac

# Verify that every expected library is now resolvable by the dynamic linker.
missing=0
for lib in libasan.so.8 libtsan.so.2 libubsan.so.1; do
    if ldconfig -p | grep -q "${lib}"; then
        echo "OK: ${lib} found"
    else
        echo "ERROR: ${lib} not found after installation" >&2
        missing=$((missing + 1))
    fi
done

if [ "${missing}" -ne 0 ]; then
    echo "ERROR: ${missing} library/libraries missing" >&2
    exit 1
fi

echo "All sanitizer runtime libraries installed successfully."
