#!/bin/bash

source ${RECIPE_DIR}/setup_compiler.sh

if [[ "$target_platform" == "win-"* ]]; then
  symlink_or_copy="cp"
else
  symlink_or_copy="ln -sf"
fi

if [[ "${PKG_NAME}" == "${name_prefix}gcc" ]]; then
  for tool in cc cpp gcc gcc-ar gcc-nm gcc-ranlib gcov gcov-dump gcov-tool; do
    $symlink_or_copy ${PREFIX}/bin/${triplet}-${tool}${EXEEXT} ${PREFIX}/bin/${tool}${EXEEXT}
  done
elif [[ "${PKG_NAME}" == "${name_prefix}gxx" ]]; then
  $symlink_or_copy ${PREFIX}/bin/${triplet}-g++${EXEEXT} ${PREFIX}/bin/g++${EXEEXT}
  $symlink_or_copy ${PREFIX}/bin/${triplet}-c++${EXEEXT} ${PREFIX}/bin/c++${EXEEXT}
elif [[ "${PKG_NAME}" == "${name_prefix}gfortran" ]]; then
  $symlink_or_copy ${PREFIX}/bin/${triplet}-gfortran${EXEEXT} ${PREFIX}/bin/gfortran${EXEEXT}
fi
