import lief
import tempfile
import shutil
import argparse
import uuid
import os
import json


def rename_symbols(blob, remove_list=(), keep_list=()):
    # this is the prefix that will be used to "hide" the symbols that need to
    # be hidden, it starts with `__` to use language common reserved name space.
    hiding_prefix = "__HIDDEN"
    changed = False
    for sym in blob.dynamic_symbols:
        if not sym.exported:
            # the symbol needs to be exported from this lib to want to hide it
            # else this will try and hide symbols that are `UND`.
            continue
        if sym.has_version:
            if sym.symbol_version.has_auxiliary_version:
                symver = sym.symbol_version.symbol_version_auxiliary.name
                if remove_list and symver in remove_list:
                    print(f"hiding: {sym}")
                    print(f"GREPPABLE:{sym.name}")
                    new_name = hiding_prefix + str(sym.name)
                    sym.name = new_name
                    changed = True
                if keep_list and symver not in keep_list:
                    print(f"hiding: {sym}")
                    print(f"GREPPABLE:{sym.name}")
                    new_name = hiding_prefix + str(sym.name)
                    sym.name = new_name
                    changed = True
    if not changed:
        print("No changes were made, this was probably not intended")


def _generate_cli_parser(descr):
    parser = argparse.ArgumentParser(description=descr)
    parser.add_argument("in_file", help="output file")
    parser.add_argument("out_file", help="input file")
    parser.add_argument("target", help="target e.g. 'x86_64'")
    g = parser.add_mutually_exclusive_group(required=True)
    g.add_argument("--remove_list", help="list of symbol versions to remove")
    g.add_argument("--keep_list", help="list of symbol versions to keep")
    return parser


def _work():
    parser = _generate_cli_parser("symbol_hider")
    args = vars(parser.parse_args())

    in_file = args['in_file']
    out_file = args['out_file']
    target = args['target']
    keep_list_file = args['keep_list']
    remove_list_file = args['remove_list']
    keep_list = remove_list = ()


    def extract_sym_list(fname):
        with open(keep_list_file, 'rt') as f:
            jdat = json.loads(f.read())
            if (target_syms := jdat.get(target)) is not None:
                return set([x.strip() for x in target_syms])
            else:
                msg = f"Given target '{target}' is not in known targets: {set(jdat.keys())}"
                raise ValueError(msg)

    if keep_list_file:
        keep_list = extract_sym_list(keep_list_file)
    if remove_list_file:
        remove_list = extract_sym_list(remove_list_file)

    # operate entirely on copies, this is a crude attempt to stop accidents
    # relating to hardlinks.
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_in_file = os.path.join(tmpdir, uuid.uuid4().hex)
        tmp_out_file = os.path.join(tmpdir, uuid.uuid4().hex)
        shutil.copy(in_file, tmp_in_file)

        blob = lief.parse(tmp_in_file)
        rename_symbols(blob, remove_list, keep_list)
        blob.write(out_file)


if __name__ == "__main__":
    _work()
