import argparse
import re

# The following `binary_replace` function is adapted from:
# https://github.com/conda/conda/blob/742ee78785602d903e0568452296ca3daee44490/conda/core/portability.py#L253-L315
# Under the terms of the license: https://github.com/conda/conda/blob/742ee78785602d903e0568452296ca3daee44490/LICENSE
# included below.
# --------------------------------
# BSD 3-Clause License
#
# Copyright (c) 2012, Anaconda, Inc.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# ---
#
# Conda incorporates the following libraries into its distributed code:
#
# * auxlib, licensed as ISC
# * frozendict, license as LGPL-3.0
# --------------------------------

# https://github.com/conda/conda/blob/742ee78785602d903e0568452296ca3daee44490/conda/core/portability.py#L42-L51
#
# These are the most common file encodings that we run across when having to replace our
# PREFIX_PLACEHOLDER string. They apply to binary and text formats.
# More information/discussion: https://github.com/conda/conda/pull/9946
POPULAR_ENCODINGS = (
    "utf-8",
    "utf-16-le",
    "utf-16-be",
    "utf-32-le",
    "utf-32-be",
)


# https://github.com/conda/conda/blob/742ee78785602d903e0568452296ca3daee44490/conda/core/portability.py#L54-L55
class _PaddingError(Exception):
    pass


# https://github.com/conda/conda/blob/742ee78785602d903e0568452296ca3daee44490/conda/core/portability.py#L253-L315
def binary_replace(
    data: bytes,
    search: bytes,
    replacement: bytes,
    encoding: str = "utf-8",
) -> bytes:
    """
    Replaces occurrences of a search string with a replacement string in a given byte string.

    Args:
        data: The byte string in which to perform the replacements.
        search: The string to search for in the byte string.
        replacement: The string to replace occurrences of the search string with.
        encoding: The encoding to use when encoding and decoding strings. Defaults to "utf-8".

    Returns:
        The byte string with the replacements made.

    Raises:
        _PaddingError: If the padding calculation results in a negative value.

    NOTE: Does not necessarily work correctly on Windows.
    """
    zeros = "\0".encode(encoding)

    def replace(match: re.Match[bytes]) -> bytes:
        """
        Replaces occurrences of the search string with the replacement string in a matched group.

        Args:
            match: The matched group containing the search string.

        Returns:
            The replaced string with padding.

        Raises:
            _PaddingError: If the padding calculation results in a negative value.
        """
        occurrences = match.group().count(search)
        padding = (len(search) - len(replacement)) * occurrences
        if padding < 0:
            raise _PaddingError
        return match.group().replace(search, replacement) + b"\0" * padding

    try:
        original_data_len = len(data)
        pat = re.compile(
            re.escape(search) + b"(?:(?!(?:" + zeros + b")).)*" + zeros, flags=re.DOTALL
        )
    except Exception as e:
        breakpoint()
        pass

    data = pat.sub(replace, data)
    if len(data) != original_data_len:
        raise RuntimeError("Replaced data has different length than original.")

    return data


def _generate_cli_parser(descr):
    parser = argparse.ArgumentParser(description=descr)
    parser.add_argument(
        "placeholder",
        help="the placeholder to replace (this is the string that will be replaced)")
    parser.add_argument(
        "replacement",
        help="the replacement string (placeholder will be replaced with this)")
    parser.add_argument(
        "file_list",
        help="file containing list of files in which to do the replacement")
    parser.add_argument(
        "-v",
        "--verbose",
        help="verbosity",
        action='store_true')
    return parser


def _work():
    parser = _generate_cli_parser("patch_strings")
    args = vars(parser.parse_args())

    file_list_file = args['file_list']
    placeholder = args['placeholder']
    replacement = args['replacement']
    verbose = args.get('verbose')

    if len(placeholder) < len(replacement):
        raise ValueError(
            'The length of the replacement string exceeds the length of the placeholder.')

    with open(file_list_file, 'rt') as f:
        file_list = [x.strip() for x in f.readlines()]

    for fpath in file_list:
        if verbose:
            print(f'Patching: {fpath}')

        with open(fpath, 'rb') as f:
            data = f.read()

        for encoding in POPULAR_ENCODINGS:
            data = binary_replace(
                data,
                placeholder.encode(encoding),
                replacement.encode(encoding),
                encoding=encoding)

        with open(fpath, 'wb') as f:
            f.write(data)


if __name__ == "__main__":
    _work()
