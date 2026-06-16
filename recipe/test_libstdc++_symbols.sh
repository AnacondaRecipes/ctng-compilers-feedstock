#!/usr/bin/sh
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
