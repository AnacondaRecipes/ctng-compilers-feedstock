#!/bin/bash

source ${RECIPE_DIR}/setup_compiler.sh
set -e -x

export CHOST="${triplet}"

# libtool wants to use ranlib that is here, macOS install doesn't grok -t etc
# .. do we need this scoped over the whole file though?
# export PATH=${SRC_DIR}/gcc_built/bin:${SRC_DIR}/.build/${CHOST}/buildtools/bin:${SRC_DIR}/.build/tools/bin:${PATH}

pushd ${SRC_DIR}/build

make -C $CHOST/libstdc++-v3/src prefix=${PREFIX} install
make -C $CHOST/libstdc++-v3/include prefix=${PREFIX} install
make -C $CHOST/libstdc++-v3/libsupc++ prefix=${PREFIX} install

mkdir -p ${PREFIX}/lib/gcc/${CHOST}/${gcc_version}
mkdir -p ${PREFIX}/${CHOST}/lib

if [[ "$target_platform" == "$cross_target_platform" ]]; then
    mv -v $PREFIX/lib/lib*.a ${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/
    if [[ "$target_platform" == linux-* ]]; then
        mv -v ${PREFIX}/lib/libstdc++.so* ${PREFIX}/${CHOST}/lib
    else
        rm -v ${PREFIX}/bin/libstdc++*.dll
    fi
else
    mv -v $PREFIX/${CHOST}/lib/lib*.a ${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/
fi

popd

if [[ "$gcc_flavor" == "manylinux" ]]; then
  # https://git.almalinux.org/rpms/gcc-toolset-15-gcc/src/commit/4d45dd5368467d758b31cda493a5fb92080746fd/gcc-toolset-15-gcc.spec#L390
  cp -v -a ${SRC_DIR}/build/${TARGET}/libstdc++-v3/src/.libs/libstdc++_nonshared80.a \
    ${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/
  cp -v -a ${SRC_DIR}/build/${TARGET}/libstdc++-v3/src/.libs/libstdc++_nonshared110.a \
    ${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/
  cp -v -a ${SRC_DIR}/build/${TARGET}/libstdc++-v3/src/.libs/libstdc++_nonshared140.a \
    ${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/

  # copy lib that is pretending to be the system one
  cp -v -a ${SRC_DIR}/build/${TARGET}/libstdc++-v3/src/.libs/libstdc++_system_like.so.6.0.34 \
	  ${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/

  if [[ "$target_platform" == 'linux-64' ]]; then
    oformat='OUTPUT_FORMAT(elf64-x86-64)'
  elif [[ "$target_platform" == 'linux-aarch64' ]]; then
    oformat='OUTPUT_FORMAT(elf64-littleaarch64)'
  else
    echo "Unknown platform"
    exit 1
  fi

  rm -v -f ${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/libstdc++.so

  # We point to the internal patched libraries so that we
  # don't end up with symbols from newwer libstdc++.
  # This replicates devtoolset as close as possible.
  libstdcxx_so="${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/libstdc++_system_like.so.6.0.34"
  libstdcxx_so_link="INPUT ( ${libstdcxx_so} -lstdc++_nonshared AS_NEEDED (${libstdcxx_so}) )"
  echo "/* GNU ld script
    Use the shared library, but some functions are only in
    the static library, so try that secondarily.  */
  ${oformat}
  ${libstdcxx_so_link}" > ${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/libstdc++.so

  mkdir -p $PREFIX/bin
  cp ${RECIPE_DIR}/post-install.sh "$PREFIX/bin/.${PKG_NAME}-post-link.sh"
  sed -i 's/@libname@/libstdc++/g' "$PREFIX/bin/.${PKG_NAME}-post-link.sh"
  cat "$PREFIX/bin/.${PKG_NAME}-post-link.sh"
fi
