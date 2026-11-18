#!/usr/bin/env python3
# =============================================================================
# scripts/verify/spike/normalize.py - Spike's commit log -> the canonical trace.
#
# WP-9 P4a. Spike prints one line per retired instruction with --log-commits,
# but the text is its own:
#
#   core   0: 3 0x00000000 (0x00000093) x1  0x00000000
#   core   0: 3 0x00000574 (0x5c302023) mem 0x000005c0 0x00000001
#   core   0: 3 0x00000578 (0x0000006f)
#   core   0: 3 0x00000094 (0x00010703) x14 0xffffffdd mem 0x00000850
#
# The DUT writes the same observation as (WP-9 P2, the monitor):
#
#   <0x pc:08x> <xN|-> <0xval|-> <0xinst:08x>
#
# and this script is the only adapter: it keeps the commit lines, drops the
# `mem ...` suffix (the store address/data is not part of the compared state)
# and emits that one line. It does not cut, compare or know what `tohost` is --
# the cut belongs to compare.py alone, so the rule is implemented exactly once.
#
# Measured on the reference machine (2026-11-17, P3 build 11848099):
#   * a store prints `mem 0xADDR 0xVAL` with no register token;
#   * a load prints the register token AND a `mem 0xADDR` suffix;
#   * a byte value is not zero padded (`0xdd`), so fields are parsed as
#     integers and re-emitted with a fixed width;
#   * `rd = x0` prints no register token ("add zero,ra,sp" comes out without
#     `xN`), and the DUT suppresses the same write -- if Spike ever does print
#     `x0`, it is normalised to `-`/`-` here so the two producers agree.
#
# Usage: normalize.py spike-log <in> <out>
# Exit:  0 wrote at least one canonical line; 1 no commit line at all, or a
#        read/write error. A vacuous trace is never a pass.
# =============================================================================

import argparse
import re
import sys

# Anchored: a commit line carries `core <hart>: <priv> 0xPC (0xINST)`. A
# `mem`-only continuation line (or any other decoration Spike may add) does not
# match, so it can never be counted as a commit.
COMMIT_RE = re.compile(
    r"^\s*core\s+\d+:\s+\d+\s+0x(?P<pc>[0-9a-fA-F]+)\s+"
    r"\(0x(?P<inst>[0-9a-fA-F]+)\)(?P<tail>.*)$"
)
# The first register token in the tail. Stores have none; loads have one and
# then a `mem` suffix; both are handled by taking the first match only.
REG_RE = re.compile(r"\bx(?P<rd>\d+)\s+0x(?P<val>[0-9a-fA-F]+)")


def canonical(pc, rd, val, inst):
    """The one line format both producers agree on."""
    rd_field = "-" if rd is None else "x%d" % rd
    val_field = "-" if val is None else "0x%08x" % val
    return "0x%08x %s %s 0x%08x" % (pc, rd_field, val_field, inst)


def normalize_line(line):
    """Return the canonical line, or None when `line` is not a commit."""
    match = COMMIT_RE.match(line.rstrip("\n"))
    if not match:
        return None
    pc = int(match.group("pc"), 16)
    inst = int(match.group("inst"), 16)
    reg = REG_RE.search(match.group("tail"))
    if reg is None:
        return canonical(pc, None, None, inst)
    rd = int(reg.group("rd"))
    val = int(reg.group("val"), 16)
    if rd == 0:
        # Both producers suppress the write to x0; keep one spelling.
        return canonical(pc, None, None, inst)
    return canonical(pc, rd, val, inst)


def spike_log(infile, outfile):
    try:
        with open(infile, "r", encoding="utf-8", errors="replace") as handle:
            lines = handle.readlines()
    except OSError as exc:
        print("normalize: cannot read %s: %s" % (infile, exc), file=sys.stderr)
        return 1

    out = []
    core_lines = 0
    for line in lines:
        if line.lstrip().startswith("core"):
            core_lines += 1
        parsed = normalize_line(line)
        if parsed is not None:
            out.append(parsed)

    if not out:
        # A vacuous trace must never look like a pass: zero commits is a defect
        # of the producer (or of this adapter), not an empty comparison.
        print(
            "normalize: no commit line in %s (%d 'core' line(s) seen); "
            "was spike built with --enable-commitlog and run with --log-commits?"
            % (infile, core_lines),
            file=sys.stderr,
        )
        return 1

    try:
        with open(outfile, "w", encoding="utf-8") as handle:
            handle.write("\n".join(out))
            handle.write("\n")
    except OSError as exc:
        print("normalize: cannot write %s: %s" % (outfile, exc), file=sys.stderr)
        return 1

    print("normalize: %d commit line(s) -> %s" % (len(out), outfile))
    return 0


def main(argv):
    parser = argparse.ArgumentParser(
        description="Adapt a Spike --log-commits log to the DUT's canonical trace."
    )
    sub = parser.add_subparsers(dest="command", required=True)
    log = sub.add_parser("spike-log", help="<in> <out>: Spike log -> canonical trace")
    log.add_argument("infile")
    log.add_argument("outfile")
    args = parser.parse_args(argv)

    if args.command == "spike-log":
        return spike_log(args.infile, args.outfile)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
