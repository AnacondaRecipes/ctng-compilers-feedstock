import lief
import tempfile
import shutil
import argparse
import uuid
import os

def rename_symbols(blob, remove_list=(), keep_list=()):
    changed = False
    for sym in blob.dynamic_symbols:
        if sym.has_version:
            if sym.symbol_version.has_auxiliary_version:
                symver = sym.symbol_version.symbol_version_auxiliary.name
                if remove_list and symver in remove_list:
                    print(f"hiding: {sym}")
                    print(f"GREPPABLE:{sym.name}")
                    new_name = "HIDDEN" + str(sym.name)
                    sym.name = new_name
                    changed = True
                if keep_list and symver not in keep_list:
                    print(f"hiding: {sym}")
                    print(f"GREPPABLE:{sym.name}")
                    new_name = "HIDDEN" + str(sym.name)
                    sym.name = new_name
                    changed = True
    if not changed:
        print("No changes were made, this was probably not intended")


def _generate_cli_parser(descr):
    parser = argparse.ArgumentParser(description=descr)
    parser.add_argument("in_file", help="output file")
    parser.add_argument("out_file", help="input file")
    g = parser.add_mutually_exclusive_group(required=True)
    g.add_argument("--remove_list", help="list of symbol versions to remove")
    g.add_argument("--keep_list", help="list of symbol versions to keep")
    return parser


def _work():
    parser = _generate_cli_parser("symbol_hider")
    args = vars(parser.parse_args())

    in_file = args['in_file']
    out_file = args['out_file']
    keep_list_file = args['keep_list']
    remove_list_file = args['remove_list']
    keep_list = remove_list = ()
    if keep_list_file:
        with open(keep_list_file, 'rt') as f:
            keep_list = set([x.strip() for x in f.readlines()])
    if remove_list_file:
        with open(remove_list_file, 'rt') as f:
            remove_list = set([x.strip() for x in f.readlines()])

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
