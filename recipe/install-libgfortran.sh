#!/bin/bash

source ${RECIPE_DIR}/setup_compiler.sh
set -e -x

rm -f ${PREFIX}/lib/libgfortran* || true

if [[ "${TARGET}" == *mingw* ]]; then
  mkdir -p ${PREFIX}/bin/
  cp ${SRC_DIR}/build/${TARGET}/libgfortran/.libs/libgfortran*.dll ${PREFIX}/bin/
else
  mkdir -p ${PREFIX}/lib
  cp -f --no-dereference ${SRC_DIR}/build/${TARGET}/libgfortran/.libs/libgfortran*.so* ${PREFIX}/lib/
fi

# Install Runtime Library Exception
install -Dm644 $SRC_DIR/COPYING.RUNTIME \
        ${PREFIX}/share/licenses/libgfortran/RUNTIME.LIBRARY.EXCEPTION

if [[ "$gcc_flavor" == "manylinux" ]]; then
  # TODO: Create a libgfortran-devel package.
  mkdir -p ${PREFIX}/lib/gcc/${triplet}/${gcc_version}

  # https://git.almalinux.org/rpms/gcc-toolset-15-gcc/src/commit/4d45dd5368467d758b31cda493a5fb92080746fd/gcc-toolset-15-gcc.spec#L390
  cp -v -a ${SRC_DIR}/build/${TARGET}/libgfortran/.libs/libgfortran_nonshared80.a \
    ${PREFIX}/lib/gcc/${triplet}/${gcc_version}/libgfortran_nonshared.a

  if [[ "$target_platform" == 'linux-64' ]]; then
    oformat='OUTPUT_FORMAT(elf64-x86-64)'
  elif [[ "$target_platform" == 'linux-aarch64' ]]; then
    oformat='OUTPUT_FORMAT(elf64-littleaarch64)'
  else
    echo "Unknown platform"
    exit 1
  fi

  rm -f ${PREFIX}/lib/libgfortran.so
  echo "/* GNU ld script
    Use the shared library, but some functions are only in
    the static library, so try that secondarily.  */
  ${oformat}
  INPUT ( ${PREFIX}/lib/libgfortran.so.5 -lgfortran_nonshared )" > ${PREFIX}/lib/gcc/${triplet}/${gcc_version}/libgfortran.so
fi
