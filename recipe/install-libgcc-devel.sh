#!/bin/bash

source ${RECIPE_DIR}/setup_compiler.sh
set -e -x

export CHOST="${triplet}"

# libtool wants to use ranlib that is here, macOS install doesn't grok -t etc
# .. do we need this scoped over the whole file though?
#export PATH=${SRC_DIR}/gcc_built/bin:${SRC_DIR}/.build/${CHOST}/buildtools/bin:${SRC_DIR}/.build/tools/bin:${PATH}

pushd ${SRC_DIR}/build

make -C ${CHOST}/libgcc prefix=${PREFIX} install

# ${PREFIX}/lib/libgcc_s.so* goes into libgcc output, but
# avoid that the equivalents in ${PREFIX}/${CHOST}/lib end up
# in gcc_impl_{{ cross_target_platform }}, c.f. install-gcc.sh
mkdir -p ${PREFIX}/${CHOST}/lib
if [[ "${triplet}" == *linux* ]]; then
  mv ${PREFIX}/lib/libgcc_s.so* ${PREFIX}/${CHOST}/lib
else
  # import library, not static library
  mv ${PREFIX}/lib/libgcc_s.a ${PREFIX}/${CHOST}/lib
  rm ${PREFIX}/lib/libgcc_s*.dll || true
fi
# This is in gcc_impl as it is gcc specific and clang has the same header
rm -rf ${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/include/unwind.h

popd


if [[ "$gcc_flavor" == "manylinux" ]]; then
  # https://git.almalinux.org/rpms/gcc-toolset-15-gcc/src/commit/4d45dd5368467d758b31cda493a5fb92080746fd/gcc-toolset-15-gcc.spec#L390

  mkdir -p ${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/

  # copy lib that is pretending to be the system one into the toolchain
  cp -v -a ${SRC_DIR}/build/${TARGET}/libgcc/libgcc_s_system_like.so.1 \
    ${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/

  if [[ "$target_platform" == 'linux-64' ]]; then
    oformat='OUTPUT_FORMAT(elf64-x86-64)'
  elif [[ "$target_platform" == 'linux-aarch64' ]]; then
    oformat='OUTPUT_FORMAT(elf64-littleaarch64)'
  else
    echo "Unknown platform"
    exit 1
  fi

  rm -v -f ${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/libgcc_s.so

  # This replicates devtoolset as close as possible.
  libgcc_s_so="${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/libgcc_s_system_like.so.1"
  libgcc_s_so_link="GROUP ( ${libgcc_s_so} -lgcc )"
  echo "/* GNU ld script
  Use the shared library, but some functions are only in
  the static library, so try that secondarily.  */
  ${oformat}
  ${libgcc_s_so_link}" > ${PREFIX}/lib/gcc/${CHOST}/${gcc_version}/libgcc_s.so

fi

