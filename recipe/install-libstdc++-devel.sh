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
    mv $PREFIX/lib/lib*.a ${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/
    if [[ "$target_platform" == linux-* ]]; then
        mv ${PREFIX}/lib/libstdc++.so* ${PREFIX}/${CHOST}/lib
    else
        rm ${PREFIX}/bin/libstdc++*.dll
    fi
else
    mv $PREFIX/${CHOST}/lib/lib*.a ${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/
fi

popd

# https://git.almalinux.org/rpms/gcc-toolset-15-gcc/src/commit/4d45dd5368467d758b31cda493a5fb92080746fd/gcc-toolset-15-gcc.spec#L390
cp -v -a ${SRC_DIR}/build/${TARGET}/libstdc++-v3/src/.libs/libstdc++_nonshared80.a \
  ${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/libstdc++_nonshared.a

if [[ "$target_platform" == 'linux-64' ]]; then
  oformat='OUTPUT_FORMAT(elf64-x86-64)'
elif [[ "$target_platform" == 'linux-aarch64' ]]; then
  oformat='OUTPUT_FORMAT(elf64-littleaarch64)'
else
  echo "Unknown platform"
  exit 1
fi

libstdcxx_so="${PREFIX}/lib/libstdc++.so.6"
libstdcxx_so_link="INPUT ( ${libstdcxx_so} -lstdc++_nonshared AS_NEEDED (${libstdcxx_so}) )"

rm -v -f ${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/libstdc++.so
echo "/* GNU ld script
   Use the shared library, but some functions are only in
   the static library, so try that secondarily.  */
${oformat}
${libstdcxx_so_link}" > ${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/libstdc++.so
