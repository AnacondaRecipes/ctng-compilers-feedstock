#!/bin/bash

set -ex

source ${RECIPE_DIR}/setup_compiler.sh

ln -s mpfr-* mpfr
ln -s mpc-* mpc
ln -s gmp-* gmp
ln -s isl-* isl

# ensure patch is applied
# grep 'conda-forge:: allow' gcc/gcc.c*

GCC_CONFIGURE_OPTIONS=()

if [[ "$channel_targets" == *conda-forge* ]]; then
  GCC_CONFIGURE_OPTIONS+=(--with-pkgversion="conda-forge gcc ${gcc_version}-${PKG_BUILDNUM}")
  GCC_CONFIGURE_OPTIONS+=(--with-bugurl="https://github.com/conda-forge/ctng-compilers-feedstock/issues/new/choose")
fi

for tool in addr2line ar as c++filt cc c++ fc gcc g++ gfortran ld nm objcopy objdump ranlib readelf size strings strip; do
  tool_upper=$(echo $tool | tr a-z-+ A-Z_X)
  if [[ "$tool" == "cc" ]]; then
     tool=gcc
  elif [[ "$tool" == "fc" ]]; then
     tool=gfortran
  elif [[ "$tool" == "c++" ]]; then
     tool=g++
  elif [[ "$target_platform" != "$build_platform" && "$tool" =~ ^(ar|nm|ranlib)$ ]]; then
     tool="gcc-${tool}"
  fi
  eval "export ${tool_upper}_FOR_BUILD=\$BUILD_PREFIX/bin/\$BUILD-\$tool"
  eval "export ${tool_upper}=\$BUILD_PREFIX/bin/\$HOST-\$tool"
  eval "export ${tool_upper}_FOR_TARGET=\$BUILD_PREFIX/bin/\$TARGET-\$tool"
done

if [[ "$cross_target_platform" == "win-64" ]]; then
  # do not expect ${prefix}/mingw symlink - this should be superceded by
  # 0005-Windows-Don-t-ignore-native-system-header-dir.patch .. but isn't!
  sed -i 's#${prefix}/mingw/#${prefix}/${target}/sysroot/usr/#g' configure
  if [[ "$gcc_maj_ver" == "13" || "$gcc_maj_ver" == "14" ]]; then
    sed -i "s#/mingw/#/usr/#g" gcc/config/i386/mingw32.h
  else
    sed -i "s#/mingw/#/usr/#g" gcc/config/mingw/mingw32.h
  fi
else
  # prevent mingw patches from being archived in linux conda packages
  rm -rf ${RECIPE_DIR}/patches/mingw
fi

NATIVE_SYSTEM_HEADER_DIR=/usr/include
SYSROOT_DIR=${PREFIX}/${TARGET}/sysroot

# workaround a bug in gcc build files when using external binutils
# and build != host == target
export gcc_cv_objdump=$OBJDUMP_FOR_TARGET

ls $BUILD_PREFIX/bin/

# ./contrib/download_prerequisites

# We want CONDA_PREFIX/usr/lib not CONDA_PREFIX/usr/lib64 and this
# is the only way. It is incompatible with multilib (obviously).
TINFO_FILES=$(find . -path "*/config/*/t-*")
for TINFO_FILE in ${TINFO_FILES}; do
  echo TINFO_FILE ${TINFO_FILE}
  sed -i.bak 's#^\(MULTILIB_OSDIRNAMES.*\)\(lib64\)#\1lib#g' ${TINFO_FILE}
  rm -f ${TINFO_FILE}.bak
  sed -i.bak 's#^\(MULTILIB_OSDIRNAMES.*\)\(libx32\)#\1lib#g' ${TINFO_FILE}
  rm -f ${TINFO_FILE}.bak
done

# workaround for https://gcc.gnu.org/bugzilla//show_bug.cgi?id=80196
if [[ "$gcc_version" == "11."* && "$build_platform" != "$target_platform" ]]; then
  sed -i.bak 's@-I$glibcxx_srcdir/libsupc++@-I$glibcxx_srcdir/libsupc++ -nostdinc++@g' libstdc++-v3/configure
fi

# https://git.rockylinux.org/staging/rpms/gcc-toolset-15-gcc/-/blob/r8/SPECS/gcc-toolset-15-gcc.spec#L750
touch -r isl-0.24/m4/ax_prog_cxx_for_build.m4 isl-0.24/m4/ax_prog_cc_for_build.m4

./contrib/gcc_update --touch

mkdir -p build
cd build

# We need to explicitly set the gxx include dir because previously
# with ct-ng, native build was not considered native because
# BUILD=HOST=x86_64-build_unknown-linux-gnu and TARGET=x86_64-conda-linux-gnu
# Depending on native or not, the include dir changes. Setting it explictly
# goes back to the original way.
# See https://github.com/gcc-mirror/gcc/blob/16e2427f50c208dfe07d07f18009969502c25dc8/gcc/configure.ac#L218

if [[ "$TARGET" == *linux* ]]; then
  GCC_CONFIGURE_OPTIONS+=(--enable-libsanitizer)
  GCC_CONFIGURE_OPTIONS+=(--enable-default-pie)
  GCC_CONFIGURE_OPTIONS+=(--enable-threads=posix)
  # The bootstrap compiler's static libstdc++.a can reference dladdr from the
  # tzdata relocation patch, so stage1 tools such as gcov need libdl explicitly.
  export LIBS="-Wl,--undefined=dladdr -ldl ${LIBS:-}"
fi

../configure \
  --prefix="$PREFIX" \
  --with-slibdir="$PREFIX/lib" \
  --libdir="$PREFIX/lib" \
  --mandir="$PREFIX/man" \
  --build=$BUILD \
  --host=$HOST \
  --target=$TARGET \
  --enable-languages=c,c++,fortran,objc,obj-c++ \
  --enable-__cxa_atexit \
  --disable-libmudflap \
  --enable-libgomp \
  --disable-libssp \
  --enable-libquadmath \
  --enable-libquadmath-support \
  --enable-lto \
  --enable-target-optspace \
  --enable-plugin \
  --enable-gold \
  --disable-nls \
  --disable-multilib \
  --enable-long-long \
  --with-sysroot=${SYSROOT_DIR} \
  --with-build-sysroot=${BUILD_PREFIX}/${TARGET}/sysroot \
  --with-native-system-header-dir=${NATIVE_SYSTEM_HEADER_DIR} \
  --with-gxx-include-dir="${PREFIX}/lib/gcc/${TARGET}/${gcc_version}/include/c++" \
  --enable-initfini-array \
  --with-gcc-major-version-only \
  --enable-host-pie \
  --enable-host-bind-now \
  --enable-gnu-indirect-function \
  --with-linker-hash-style=gnu \
  --enable-libstdcxx-backtrace \
  --enable-gnu-unique-object \
  --enable-linker-build-id \
  --disable-libunwind-exceptions \
  --enable-checking=release \
  "${GCC_CONFIGURE_OPTIONS[@]}"

# Setting the CPU_COUNT=1 lets you see which job failed!
# CPU_COUNT=1
make -j${CPU_COUNT} LDFLAGS_FOR_TARGET=-Wl,-z,relro,-z,now

echo
echo
echo "Testing jcjcjcjcjc"
echo "++++++++++++++++++"
echo

mkdir -p libstdc++_compat_test
cd libstdc++_compat_test


readelf -Ws /usr/lib64/libstdc++.so.6 \
| sed -n '/\.symtab/,$d;/ UND /d;/@GLIBC_PRIVATE/d;/\(GLOBAL\|WEAK\|UNIQUE\)/p' \
| awk '{ if ($4 == "OBJECT") { printf "%s %s %s %s %s\n", $8, $4, $5, $6, $3 } else { printf "%s %s %s %s\n", $8, $4, $5, $6 }}' \
| sed 's/ UNIQUE / GLOBAL /;s/ WEAK / GLOBAL /;s/@@GLIBCXX_\(LDBL_\)\?[0-9.]*//;s/@@CXXABI_TM_[0-9.]*//;s/@@CXXABI_FLOAT128//;s/@@CXXABI_\(LDBL_\)\?[0-9.]*//' \
| LC_ALL=C sort -u > system.abilist

# This is in the "build folder"
readelf -Ws ${SRC_DIR}/build/${TARGET}/libstdc++-v3/src/.libs/libstdc++.so.6 \
| sed -n '/\.symtab/,$d;/ UND /d;/@GLIBC_PRIVATE/d;/\(GLOBAL\|WEAK\|UNIQUE\)/p' \
| awk '{ if ($4 == "OBJECT") { printf "%s %s %s %s %s\n", $8, $4, $5, $6, $3 } else { printf "%s %s %s %s\n", $8, $4, $5, $6 }}' \
| sed 's/ UNIQUE / GLOBAL /;s/ WEAK / GLOBAL /;s/@@GLIBCXX_\(LDBL_\)\?[0-9.]*//;s/@@CXXABI_TM_[0-9.]*//;s/@@CXXABI_FLOAT128//;s/@@CXXABI_\(LDBL_\)\?[0-9.]*//' \
| LC_ALL=C sort -u > vanilla.abilist

diff -up system.abilist vanilla.abilist \
| awk '/^\+\+\+/{next}/^\+/{print gensub(/^+(.*)$/,"\\1","1",$0)}' > system2vanilla.abilist.diff

${SRC_DIR}/build/gcc/xgcc \
    -B ${SRC_DIR}/build/gcc \
    -shared \
    -o libstdc++_nonshared.so \
    -Wl,--whole-archive ${SRC_DIR}/build/${TARGET}/libstdc++-v3/src/.libs/libstdc++_nonshared80.a \
    -Wl,--no-whole-archive /usr/lib64/libstdc++.so.6

readelf -Ws libstdc++_nonshared.so
| sed -n '/\.symtab/,$d;/ UND /d;/@GLIBC_PRIVATE/d;/\(GLOBAL\|WEAK\|UNIQUE\)/p'
| awk '{ if ($4 == "OBJECT") { printf "%s %s %s %s %s\n", $8, $4, $5, $6, $3 } else { printf "%s %s %s %s\n", $8, $4, $5, $6 }}'
| sed 's/ UNIQUE / GLOBAL /;s/ WEAK / GLOBAL /;s/@@GLIBCXX_\(LDBL_\)\?[0-9.]*//;s/@@CXXABI_TM_[0-9.]*//;s/@@CXXABI_FLOAT128//;s/@@CXXABI_\(LDBL_\)\?[0-9.]*//'
| LC_ALL=C sort -u > nonshared.abilist

echo ====================NONSHARED=========================
ldd -d -r ./libstdc++_nonshared.so || :
ldd -u ./libstdc++_nonshared.so || :
diff -up system2vanilla.abilist.diff nonshared.abilist || :
readelf -Ws ${SRC_DIR}/build/${TARGET}/libstdc++-v3/src/.libs/libstdc++_nonshared80.a | grep HIDDEN.*UND | grep -v __dso_handle || :
echo ====================NONSHARED END=====================
rm -f libstdc++_nonshared.so
