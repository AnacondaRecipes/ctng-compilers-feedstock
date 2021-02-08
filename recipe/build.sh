#!/bin/bash

set -ex

if [[ ${BOOTSTRAPPING} == yes ]]; then
  # When you build with your own compilers, even if they're in /opt/cfs, crosstool-ng fails to link because it strips too many flags
  # meaning we do not get to -Wl,-rpath the search for libstdc++ and it loads the system one instead.
  # GCC's testsuite fails without this:
  # [ALL  ]    /opt/cfs/conda-bld/ctng-compilers_1611857510222/work/.build/aarch64-conda-linux-gnu/build/build-cc-gcc-core-pass-1/./gcc/xgcc -B/opt/cfs/conda-bld/ctng-compilers_1611857510222/work/.build/aarch64-conda-linux-gnu/build/build-cc-gcc-core-pass-1/./gcc/ -xc -nostdinc /dev/null -S -o /dev/null -fself-test=/opt/cfs/conda-bld/ctng-compilers_1611857510222/work/.build/aarch64-conda-linux-gnu/src/gcc/gcc/testsuite/selftests
  # [ALL  ]    /opt/cfs/conda-bld/ctng-compilers_1611857510222/work/.build/aarch64-conda-linux-gnu/build/build-cc-gcc-core-pass-1/./gcc/cc1: error while loading shared libraries: libzstd.so.1: cannot open shared object file: No such file or directory
  # export LD_LIBRARY_PATH=${SYS_PREFIX}/lib:${LD_LIBRARY_PATH}
  NEED_DTS=no
  if which gcc > /dev/null 2>&1; then
    SYS_GCC_VERSION=$(gcc --version | grep ^gcc | sed 's/^.* //g')
    SYS_GCC_VERSION_MAJ=${SYS_GCC_VERSION%%:*}
    if (( SYS_GCC_VERSION_MAJ < 8 )); then
      echo "INFO :: System compilers (${SYS_GCC_VERSION}) are too old to build modern compilers"
      echo "INFO :: .. will try to find devtoolset in /opt/rh instead."
      NEED_DTS=yes
    else
      echo "INFO :: Proceeding with system compilers (${SYS_GCC_VERSION})"
    fi
  else
    echo "INFO :: No system compilers found"
    echo "INFO :: .. will try to find devtoolset in /opt/rh instead."
    NEED_DTS=yes
  fi
  if [[ ${NEED_DTS} == yes ]]; then
    FOUND_DTS=no
    for DTS in 9 8 7; do
      if [[ -d /opt/rh/devtoolset-${DTS}/root/usr ]]; then
        FOUND_DTS=yes
        PATH=/opt/rh/devtoolset-${DTS}/root/usr/bin:${PATH}
        break
      fi
    done
    if [[ ${FOUND_DTS} == no ]]; then
      echo "ERROR :: Failed to find devtoolset. ctng-compilers-feedstock can only be bootstrapped"
      echo "ERROR :: with this at present. Maybe:"
      echo "ERROR :: yum install -y centos-release-scl"
      echo "ERROR :: yum install -y devtoolset-9-toolchain"
      exit 1
    fi
  fi
fi

if [[ "${ctng_cpu_arch}" == "aarch64" ]]; then
    rm -f $BUILD_PREFIX/share/crosstool-ng/packages/glibc/2.17/*-glibc-*.patch
fi

mkdir -p .build/src
mkdir -p .build/tarballs

if [[ $(uname) == Darwin ]]; then
  DOWNLOADER="curl -SL"
  DOWNLOADER_INSECURE=${DOWNLOADER}" --insecure"
  DOWNLOADER_OUT="-C - -o"
else
  DOWNLOADER="wget -c -q"
  DOWNLOADER_INSECURE=${DOWNLOADER}" --no-check-certificate"
  DOWNLOADER_OUT="-O"
fi

if [[ ${target_platform} =~ osx-.* ]]; then
  if [[ ! -f ${BUILD_PREFIX}/bin/llvm-objcopy ]]; then
    echo "no llvm-objcopy"
    exit 1
  fi
  ln -s ${BUILD_PREFIX}/bin/llvm-objcopy ${BUILD_PREFIX}/bin/x86_64-apple-darwin19.6.0-objcopy
  chmod +x ${BUILD_PREFIX}/bin/x86_64-apple-darwin19.6.0-objcopy
  ln -s ${BUILD_PREFIX}/bin/llvm-objcopy ${BUILD_PREFIX}/bin/objcopy
  chmod +x ${BUILD_PREFIX}/bin/objcopy
  unset CC CXX
fi

mkdir -p ${SYS_PREFIX}/conda-bld/src_cache/
# Some kernels are not on kernel.org, such as the CentOS 5.11 one used (and heavily patched) by RedHat.
# if [[ ! -e "${SYS_PREFIX}/conda-bld/src_cache/linux-${ctng_kernel}.tar.bz2" ]] && \
#    [[ ! -e "${SYS_PREFIX}/conda-bld/src_cache/linux-${ctng_kernel}.tar.xz" ]]; then
#   if [[ ${ctng_kernel} == 2.6.* ]]; then
#     ${DOWNLOADER} ftp://ftp.be.debian.org/pub/linux/kernel/v2.6/linux-${ctng_kernel}.tar.bz2 ${DOWNLOADER_OUT} ${SYS_PREFIX}/conda-bld/src_cache/linux-${ctng_kernel}.tar.bz2
#   elif [[ ${ctng_kernel} == 3.* ]]; then
#     # Necessary because crosstool-ng looks in the wrong location for this one.
#     ${DOWNLOADER} https://www.kernel.org/pub/linux/kernel/v3.x/linux-${ctng_kernel}.tar.bz2 ${DOWNLOADER_OUT} ${SYS_PREFIX}/conda-bld/src_cache/linux-${ctng_kernel}.tar.bz2
#   elif [[ ${ctng_kernel} == 4.* ]]; then
#     ${DOWNLOADER} https://www.kernel.org/pub/linux/kernel/v4.x/linux-${ctng_kernel}.tar.xz ${DOWNLOADER_OUT} ${SYS_PREFIX}/conda-bld/src_cache/linux-${ctng_kernel}.tar.xz
#   fi
# fi

if [[ ! -e "${SYS_PREFIX}/conda-bld/src_cache/gettext-${ctng_gettext}.tar.gz" ]]; then
  ${DOWNLOADER_INSECURE} https://ftp.gnu.org/gnu/gettext/gettext-${ctng_gettext}.tar.gz ${DOWNLOADER_OUT} ${SYS_PREFIX}/conda-bld/src_cache/gettext-${ctng_gettext}.tar.gz
fi

# Necessary because uclibc let their certificate expire, this is a bit hacky.
if [[ ${ctng_libc} == uClibc ]]; then
  if [[ ! -e "${SYS_PREFIX}/conda-bld/src_cache/uClibc-${ctng_uClibc}.tar.xz" ]]; then
    ${DOWNLOADER_INSECURE} https://www.uclibc.org/downloads/uClibc-${ctng_uClibc}.tar.xz ${DOWNLOADER_OUT} ${SYS_PREFIX}/conda-bld/src_cache/uClibc-${ctng_uClibc}.tar.xz
  fi
else
  if [[ ! -e "${SYS_PREFIX}/conda-bld/src_cache/glibc-${conda_glibc_ver}.tar.xz" ]]; then
    ${DOWNLOADER_INSECURE} https://ftp.gnu.org/gnu/libc/glibc-${conda_glibc_ver}.tar.xz ${DOWNLOADER_OUT} ${SYS_PREFIX}/conda-bld/src_cache/glibc-${conda_glibc_ver}.tar.xz
  fi
fi

if [[ ! -e "${SYS_PREFIX}/conda-bld/src_cache/binutils-${ctng_binutils}.tar.xz" ]]; then
  ${DOWNLOADER_INSECURE} https://ftp.gnu.org/gnu/binutils/binutils-${ctng_binutils}.tar.xz ${DOWNLOADER_OUT} ${SYS_PREFIX}/conda-bld/src_cache/binutils-${ctng_binutils}.tar.xz
fi

# Necessary because CentOS5.11 is having some certificate issues.
if [[ -n "${ctng_duma}" ]]; then
  if [[ ! -e "${SYS_PREFIX}/conda-bld/src_cache/duma_${ctng_duma//./_}.tar.gz" ]]; then
    ${DOWNLOADER_INSECURE} http://mirror.opencompute.org/onie/crosstool-NG/duma_${ctng_duma//./_}.tar.gz ${DOWNLOADER_OUT} ${SYS_PREFIX}/conda-bld/src_cache/duma_${ctng_duma//./_}.tar.gz
  fi
fi

if [[ ! -e "${SYS_PREFIX}/conda-bld/src_cache/expat-2.2.0.tar.bz2" ]]; then
  ${DOWNLOADER_INSECURE} http://mirror.opencompute.org/onie/crosstool-NG/expat-2.2.0.tar.bz2 ${DOWNLOADER_OUT} ${SYS_PREFIX}/conda-bld/src_cache/expat-2.2.0.tar.bz2
fi

[[ -d ${SRC_DIR}/gcc_built ]] || mkdir -p ${SRC_DIR}/gcc_built

# If the gfortran binary doesn't exist yet, then run ct-ng
if [[ ! -n $(find ${SRC_DIR}/gcc_built -iname ${ctng_cpu_arch}-${ctng_vendor}-*-gfortran) ]]; then
    source ${RECIPE_DIR}/write_ctng_config

    yes "" | ct-ng ${ctng_sample}
    write_ctng_config_before .config
    # Apply some adjustments for conda.
    sed -i.bak "s|# CT_DISABLE_MULTILIB_LIB_OSDIRNAMES is not set|CT_DISABLE_MULTILIB_LIB_OSDIRNAMES=y|g" .config
    sed -i.bak "s|CT_CC_GCC_USE_LTO=n|CT_CC_GCC_USE_LTO=y|g" .config
    cat .config | grep CT_DISABLE_MULTILIB_LIB_OSDIRNAMES=y || exit 1
    cat .config | grep CT_CC_GCC_USE_LTO=y || exit 1
    # Not sure why this is getting set to y since it depends on ! STATIC_TOOLCHAIN
    if [[ ${ctng_nature} == static ]]; then
      sed -i.bak "s|CT_CC_GCC_ENABLE_PLUGINS=y|CT_CC_GCC_ENABLE_PLUGINS=n|g" .config
    fi
    if [[ $(uname) == Darwin ]]; then
        sed -i.bak "s|CT_WANTS_STATIC_LINK=y|CT_WANTS_STATIC_LINK=n|g" .config
        sed -i.bak "s|CT_CC_GCC_STATIC_LIBSTDCXX=y|CT_CC_GCC_STATIC_LIBSTDCXX=n|g" .config
        sed -i.bak "s|CT_STATIC_TOOLCHAIN=y|CT_STATIC_TOOLCHAIN=n|g" .config
        sed -i.bak "s|CT_BUILD=\"x86_64-pc-linux-gnu\"|CT_BUILD=\"x86_64-apple-darwin11\"|g" .config
    fi
    # Now ensure any changes we made above pull in other requirements by running oldconfig.
    yes "" | ct-ng oldconfig
    # Now filter out 'things that cause problems'. For example, depending on the base sample, you can end up with
    # two different glibc versions in-play.
    sed -i.bak '/CT_LIBC/d' .config
    sed -i.bak '/CT_LIBC_GLIBC/d' .config
    # And undo any damage to version numbers => the seds above could be moved into this too probably.
    write_ctng_config_after .config
    if cat .config | grep "CT_GDB_NATIVE=y"; then
      if ! cat .config | grep "CT_EXPAT_TARGET=y"; then
        echo "ERROR: CT_GDB_NATIVE=y but CT_EXPAT_TARGET!=y"
        cat .config
        echo "ERROR: CT_GDB_NATIVE=y but CT_EXPAT_TARGET!=y"
        exit 1
      fi
    fi
    echo "CT-NG CONFIG IS:"
    cat .config
    unset CPPFLAGS CFLAGS CXXFLAGS LDFLAGS
    set +e
    LOGINFIX=${ctng_target_platform}-c_${ctng_gcc}-k_${ctng-kernel}-g_${conda_glibc_ver}
    ct-ng build
    if [[ $? != 0 ]]; then
      tail -n 1000 build.log
      cp build.log ${RECIPE_DIR}/bad_build_${LOGINFIX}.log
      cp .config ${RECIPE_DIR}/bad_.config_${LOGINFIX}
      exit 1
    fi
    set -e
    cp build.log ${RECIPE_DIR}/good_build_${LOGINFIX}.log
    cp .config ${RECIPE_DIR}/good_.config_${LOGINFIX}
fi

# increase stack size to prevent test failures
# http://gcc.gnu.org/bugzilla/show_bug.cgi?id=31827
if [[ $(uname) == Linux ]]; then
  ulimit -s 32768 || true
fi

CHOST=$(${SRC_DIR}/.build/*-*-*-*/build/build-cc-gcc-final/gcc/xgcc -dumpmachine)

# pushd .build/${CHOST}/build/build-cc-gcc-final
# make -k check || true
# popd

# .build/src/gcc-${PKG_VERSION}/contrib/test_summary

chmod -R u+w ${SRC_DIR}/gcc_built

# Next problem: macOS targetting uClibc ends up with broken symlinks in sysroot/usr/lib:
if [[ $(uname) == Darwin ]]; then
  pushd ${SRC_DIR}/gcc_built/${CHOST}/sysroot/usr/lib
    links=$(find . -type l | cut -c 3-)
    for link in ${links}; do
      target=$(readlink ${link} | sed 's#^/##' | sed 's#//#/#')
      rm ${link}
      ln -s ${target} ${link}
    done
  popd
fi

exit 0
