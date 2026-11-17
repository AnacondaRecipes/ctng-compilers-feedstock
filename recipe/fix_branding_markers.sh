#!/bin/bash

# This finds files which contain the ACNDA_BRANDING_STR within the $PREFIX
# and passes that list of files into patch_strings.py to replace the
# ACNDA_BRANDING_STR with "$PKG_NAME $PKG_BUILD_STRING". This is to make it
# so that the tools, libraries and archives carry the Anaconda name
# and compiled artifacts produced by them have the same in the .comment
# section.
set -x

echo "fixing branding... replacing | ${ACNDA_BRANDING_STR} | with | ${PKG_BUILD_STRING} |"
MARKED_FILES=$(mktemp -p "${SRC_DIR}")
LC_ALL='C' grep -lsar "${ACNDA_BRANDING_STR}" "${PREFIX}" > "${MARKED_FILES}"
python "${RECIPE_DIR}/patch_strings.py" "${ACNDA_BRANDING_STR}" "${PKG_NAME} ${PKG_BUILD_STRING}" "${MARKED_FILES}" --verbose
