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

if [[ "$target_platform" == 'linux-64' ]]; then
  oformat='OUTPUT_FORMAT(elf64-x86-64)'
elif [[ "$target_platform" == 'linux-aarch64' ]]; then
  oformat='OUTPUT_FORMAT(elf64-littleaarch64)'
else
  echo "Unknown platform"
  exit 1
fi

echo "/* GNU ld script
   Use the shared library, but some functions are only in
   the static library, so try that secondarily.  */
${oformat}
GROUP ( ${PREFIX}/lib/libgcc_s.so.1 libgcc.a )" > ${PREFIX}/lib/gcc/${triplet}/${gcc_version}/libgcc_s.so
