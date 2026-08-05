#!/bin/sh
set -e

test -e /etc/os-release && os_release='/etc/os-release' || os_release='/usr/lib/os-release'
. "${os_release}"

nonshared=$(ls $PREFIX/lib/gcc/*-conda-linux-gnu/*/@libname@_nonshared*.a 2>/dev/null | head -n 1)
if [ -z "${nonshared}" ]; then
    echo "Cannot find nonshared archive ${nonshared}"
    exit 1
fi

echo "Nonshared archive is: ${nonshared}"

nonshared_dir=$(dirname "${nonshared}")

if [ "${ID:-linux}" = "rocky" ] || [ "${ID:-linux}" = "almalinux" ] || [ "${ID:-linux}" = "rhel" ]; then
    if [[ "${VERSION_ID}" == "8."* ]]; then
        nonshared_version=80
    elif [[ "${VERSION_ID}" == "9."* ]]; then
        nonshared_version=110
    elif [[ "${VERSION_ID}" == "10."* ]]; then
        nonshared_version=140
    else
        echo "Unknown RH based distro version: ${VERSION_ID}"
        exit 1
    fi
    ln -sf "@libname@_nonshared${nonshared_version}.a" "${nonshared_dir}/@libname@_nonshared.a"
else
    echo "This package should only be installed on a RedHat derivative: ${ID}"
    exit 1
fi
