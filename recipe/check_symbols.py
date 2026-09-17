import argparse

def _generate_cli_parser(descr):
    parser = argparse.ArgumentParser(description=descr)
    parser.add_argument("expected_symbols", help="file containing list of expected symbols")
    parser.add_argument("got_symbols", help="file containing list of found symbols")
    return parser


def _work():
    parser = _generate_cli_parser("check_symbols")
    args = vars(parser.parse_args())

    expected_f = args['expected_symbols']
    got_f = args['got_symbols']


    # check that the symbols present are a non-strict subset of
    # those expected.
    def get_syms(fname):
        with open(fname, 'rt') as f:
            return set([x.strip() for x in f.readlines()])

    expected = get_syms(expected_f)
    got = get_syms(got_f)

    if not expected:
        raise ValueError("No symbol versions found in expected file")
    if not got:
        raise ValueError("No symbol versions found in found file")

    diff = got - expected

    if diff:
        msg = (f"FAIL:\n The symbols listeed in '{got_f}' are not a strict subset "
                f"of those in reference '{expected_f}' .\n"
                f"Expected:\n{'\n'.join(sorted(expected))}"
                f"\n\nGot:\n{'\n'.join(sorted(got))}"
                f"f\n\nDiff:\n{'\n'.join(sorted(diff))}")
        raise AssertionError(msg)

    print("Symbol check OK")

if __name__ == "__main__":
    _work()
