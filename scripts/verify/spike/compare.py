#!/usr/bin/env python3
# =============================================================================
# scripts/verify/spike/compare.py - compare two canonical commit traces.
#
# WP-9 P4a. Both sides already speak the one line format (the TB's
# +RETIRE_LOG monitor dump and normalize.py's adaptation of Spike's
# --log-commits log):
#
#   <0x pc:08x> <xN|-> <0xval|-> <0xinst:08x>
#
# The comparison is by COMMIT INDEX, never by pc: a loop retires the same pc
# many times, so matching on pc would let a missing iteration pass. Equal line
# count and equal (pc, rd, val, inst) at every index, or the index is reported.
#
# --- the cut rule (the one place it is implemented) --------------------------
# Spike does not stop logging at the `tohost` store: the pass epilogue ends in
# `j .`, so its log carries thousands of identical commits afterwards. The two
# traces are therefore cut at the FIRST committed line whose pc is in a set of
# candidate pcs, INCLUSIVE on both sides -- the line that performs the store is
# the last compared line, and everything after it is discarded.
#
# The candidate set is a set on purpose: each sanity dump carries TWO
# `sw ...,<tohost>` instructions, the `fail` epilogue and the `pass` epilogue,
# and only the pass one executes. Measured 2026-11-17:
#   rv32ui-p-add   fail 0x568  pass 0x574  tohost 0x5c0
#   rv32ui-p-beq   fail 0x348  pass 0x354  tohost 0x380
#   rv32ui-p-st_ld fail 0x774  pass 0x784  tohost 0x800
# Grepping the first match would cut at the address that never executes and
# fail the run for a reason that is not the DUT. The comparator does not assume
# which of the two ran; it takes whichever arrives first.
#
# If either side never reaches a cut pc, that is a FAILURE naming the side
# (`no_cut:dut` / `no_cut:spike`) -- never an empty pass.
#
# Usage:
#   compare.py --dut <file> --spike <file> --cut-pcs <hex,hex,...> --out <json>
#              [--rtl-digest <s>] [--tb-digest <s>] [--spike-commit <s>]
#   compare.py --selftest
# Exit: 0 pass (or a passing selftest), 1 fail (or a broken selftest), 2 usage.
# =============================================================================

import argparse
import json
import os
import re
import sys
import tempfile

CANON_RE = re.compile(
    r"^(?P<pc>0x[0-9a-fA-F]+) (?P<rd>x\d+|-) (?P<val>0x[0-9a-fA-F]+|-) "
    r"(?P<inst>0x[0-9a-fA-F]+)$"
)


class TraceError(Exception):
    pass


def parse_trace(path, label):
    """Read one canonical trace. Returns a list of (pc, rd, val, inst, text)."""
    try:
        with open(path, "r", encoding="utf-8") as handle:
            raw_lines = handle.readlines()
    except OSError as exc:
        raise TraceError("%s: cannot read %s: %s" % (label, path, exc))

    entries = []
    for lineno, raw in enumerate(raw_lines, 1):
        text = raw.strip()
        if not text:
            continue
        match = CANON_RE.match(text)
        if not match:
            raise TraceError(
                "%s: %s:%d is not a canonical trace line: %r"
                % (label, path, lineno, text)
            )
        rd_text = match.group("rd")
        val_text = match.group("val")
        rd = None if rd_text == "-" else int(rd_text[1:])
        val = None if val_text == "-" else int(val_text, 16)
        if (rd is None) != (val is None):
            raise TraceError(
                "%s: %s:%d has half a register write: %r"
                % (label, path, lineno, text)
            )
        if rd == 0:
            # The canonical form suppresses x0 (both producers do); a trace that
            # prints it is normalised here, not treated as a divergence.
            rd, val = None, None
        entries.append(
            (int(match.group("pc"), 16), rd, val, int(match.group("inst"), 16), text)
        )
    return entries


def cut_index(entries, cut_pcs):
    """First index whose pc is in the set, or None. The cut is inclusive."""
    for index, entry in enumerate(entries):
        if entry[0] in cut_pcs:
            return index
    return None


def compare_traces(dut_entries, spike_entries, cut_pcs):
    """The verdict as a dict, with no file I/O and no printing."""
    result = {
        "status": "fail",
        "reason": "",
        "cut_pcs": ["0x%08x" % pc for pc in sorted(cut_pcs)],
        "cut_index": None,
        "cut_index_spike": None,
        "cut_pc": None,
        "dut_lines": len(dut_entries),
        "spike_lines": len(spike_entries),
        "dut_count": 0,
        "spike_count": 0,
        "first_divergence": None,
        "rtl_digest": "",
        "tb_digest": "",
        "spike_commit": "",
    }

    for label, entries in (("dut", dut_entries), ("spike", spike_entries)):
        if not entries:
            # A trace with no commit at all proves nothing; the producer failed.
            result["reason"] = "empty:%s" % label
            return result

    dut_cut = cut_index(dut_entries, cut_pcs)
    if dut_cut is None:
        result["reason"] = "no_cut:dut"
        return result
    spike_cut = cut_index(spike_entries, cut_pcs)
    if spike_cut is None:
        result["cut_index"] = dut_cut
        result["cut_pc"] = "0x%08x" % dut_entries[dut_cut][0]
        result["reason"] = "no_cut:spike"
        return result

    dut_cut_trace = dut_entries[: dut_cut + 1]
    spike_cut_trace = spike_entries[: spike_cut + 1]
    result["cut_index"] = dut_cut
    result["cut_index_spike"] = spike_cut
    result["cut_pc"] = "0x%08x" % dut_entries[dut_cut][0]
    result["dut_count"] = len(dut_cut_trace)
    result["spike_count"] = len(spike_cut_trace)

    if len(dut_cut_trace) != len(spike_cut_trace):
        index = min(len(dut_cut_trace), len(spike_cut_trace))
        result["reason"] = "count"
        result["first_divergence"] = {
            "index": index,
            "field": "count",
            "dut": dut_cut_trace[index][4] if index < len(dut_cut_trace) else "<end of trace>",
            "spike": spike_cut_trace[index][4] if index < len(spike_cut_trace) else "<end of trace>",
        }
        return result

    # Strict, field by field, by commit index. pc first: a missing/extra
    # instruction shifts every later index, so the first bad index is the story.
    for index, (dut, spike) in enumerate(zip(dut_cut_trace, spike_cut_trace)):
        for field, dut_value, spike_value in (
            ("pc", dut[0], spike[0]),
            ("rd", dut[1], spike[1]),
            ("val", dut[2], spike[2]),
            ("inst", dut[3], spike[3]),
        ):
            if dut_value != spike_value:
                result["reason"] = "divergence"
                result["first_divergence"] = {
                    "index": index,
                    "field": field,
                    "dut": dut[4],
                    "spike": spike[4],
                }
                return result

    result["status"] = "pass"
    return result


def print_verdict(result):
    if result["status"] == "pass":
        print(
            "COMPARE: pass compared=%d/%d cut_index=%d cut_pc=%s (dut lines=%d, spike lines=%d)"
            % (
                result["dut_count"],
                result["spike_count"],
                result["cut_index"],
                result["cut_pc"],
                result["dut_lines"],
                result["spike_lines"],
            )
        )
        return
    divergence = result["first_divergence"]
    print(
        "COMPARE: fail reason=%s dut=%d/%d spike=%d/%d cut_index=%s cut_pc=%s"
        % (
            result["reason"],
            result["dut_count"],
            result["dut_lines"],
            result["spike_count"],
            result["spike_lines"],
            "none" if result["cut_index"] is None else result["cut_index"],
            "none" if result["cut_pc"] is None else result["cut_pc"],
        )
    )
    if divergence is not None:
        print("  first divergence at commit index %d (field %s)" % (divergence["index"], divergence["field"]))
        print("  dut  : %s" % divergence["dut"])
        print("  spike: %s" % divergence["spike"])


def write_results(path, result):
    directory = os.path.dirname(os.path.abspath(path))
    if directory:
        os.makedirs(directory, exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(result, handle, indent=2, sort_keys=True)
        handle.write("\n")


def run_file(dut_path, spike_path, cut_pcs):
    dut_entries = parse_trace(dut_path, "dut")
    spike_entries = parse_trace(spike_path, "spike")
    result = compare_traces(dut_entries, spike_entries, cut_pcs)
    result["dut"] = dut_path
    result["spike"] = spike_path
    return result


# --- the comparator's own negative controls ----------------------------------
# A comparator that cannot fail is not a comparator. --selftest synthesises
# traces, asserts the pass case, then mutates one field of one line and asserts
# the failure names the right index AND both lines. It also proves the cut-set
# behaviour that the real dumps depend on: the `fail` epilogue pc is in the set
# and never executes, the `pass` epilogue pc is where the traces stop, the tail
# after the cut is discarded, and a side that never reaches a cut pc fails by
# name instead of passing empty.
SELFTEST_DUT = [
    "0x00000000 x1 0x00000000 0x00000093",
    "0x00000004 x2 0x00000000 0x00000113",
    "0x00000008 x3 0x00000002 0x00000193",
    "0x00000074 - - 0x5c302023",
    "0x00000078 - - 0x0000006f",
]
SELFTEST_SPIKE = [
    "0x00000000 x1 0x00000000 0x00000093",
    "0x00000004 x2 0x00000000 0x00000113",
    "0x00000008 x3 0x00000002 0x00000193",
    "0x00000074 - - 0x5c302023",
    "0x00000078 - - 0x0000006f",
    "0x00000078 - - 0x0000006f",
    "0x00000078 - - 0x0000006f",
]
# The fail epilogue (0x68) never executes; the pass epilogue (0x74) does.
SELFTEST_CUT = {0x68, 0x74}


def write_lines(path, lines):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))
        handle.write("\n")


def selftest():
    failures = []
    checks = 0

    def check(name, condition, detail=""):
        nonlocal checks
        checks += 1
        if condition:
            print("SELFTEST: ok   %s" % name)
        else:
            print("SELFTEST: FAIL %s %s" % (name, detail))
            failures.append(name)

    tmp = tempfile.mkdtemp(prefix="spike-compare-selftest.")
    dut_path = os.path.join(tmp, "dut.trace")
    spike_path = os.path.join(tmp, "spike.trace")
    write_lines(dut_path, SELFTEST_DUT)
    write_lines(spike_path, SELFTEST_SPIKE)

    # 1. Identical traces (Spike has the post-cut tail): pass, cut inclusive.
    result = run_file(dut_path, spike_path, SELFTEST_CUT)
    print_verdict(result)
    check("identical traces pass", result["status"] == "pass", result)
    check("cut at the pass epilogue, not the fail one", result["cut_pc"] == "0x00000074", result["cut_pc"])
    check("cut index is the last compared line", result["cut_index"] == 3, result["cut_index"])
    check("the tail after the cut is discarded", result["dut_count"] == 4 and result["spike_count"] == 4,
          (result["dut_count"], result["spike_count"]))

    # 2. Mutate one field of one line, before the cut: the failure must name
    #    index 2 and both lines, and it must not be reported as a pass.
    mutated = list(SELFTEST_SPIKE)
    mutated[2] = "0x00000008 x3 0x00000003 0x00000193"
    mutated_path = os.path.join(tmp, "spike.mutated.trace")
    write_lines(mutated_path, mutated)
    result = run_file(dut_path, mutated_path, SELFTEST_CUT)
    print_verdict(result)
    check("mutated value fails", result["status"] == "fail", result)
    check("mutated value is caught at the right index",
          result["first_divergence"] is not None and result["first_divergence"]["index"] == 2,
          result["first_divergence"])
    if result["first_divergence"] is not None:
        check("failure shows the DUT line", result["first_divergence"]["dut"] == SELFTEST_DUT[2],
              result["first_divergence"]["dut"])
        check("failure shows the Spike line", result["first_divergence"]["spike"] == mutated[2],
              result["first_divergence"]["spike"])
        check("failure names the field", result["first_divergence"]["field"] == "val",
              result["first_divergence"]["field"])

    # 3. A side that never reaches a cut pc fails by name, not empty.
    try:
        run_file(dut_path, os.path.join(tmp, "does-not-exist.trace"), SELFTEST_CUT)
        raised = False
    except TraceError:
        raised = True
    check("missing trace raises, never passes", raised)
    truncated = os.path.join(tmp, "spike.truncated.trace")
    write_lines(truncated, SELFTEST_SPIKE[:3])
    result = run_file(dut_path, truncated, SELFTEST_CUT)
    print_verdict(result)
    check("spike without a cut pc fails naming spike", result["reason"] == "no_cut:spike", result["reason"])
    result = run_file(truncated, spike_path, SELFTEST_CUT)
    print_verdict(result)
    check("dut without a cut pc fails naming dut", result["reason"] == "no_cut:dut", result["reason"])
    result = run_file(truncated, truncated, {0x68})
    check("a cut set that never matches fails", result["reason"] == "no_cut:dut", result["reason"])

    if failures:
        print("SELFTEST: FAIL %d of %d check(s): %s" % (len(failures), checks, ", ".join(failures)))
        return 1
    print("SELFTEST: PASS %d check(s); the mutated case was caught" % checks)
    return 0


def parse_cut_pcs(text):
    pcs = set()
    for item in text.split(","):
        item = item.strip()
        if not item:
            continue
        try:
            pcs.add(int(item, 16))
        except ValueError:
            raise TraceError("--cut-pcs: %r is not a hex pc" % item)
    if not pcs:
        raise TraceError("--cut-pcs: empty")
    return pcs


def main(argv):
    parser = argparse.ArgumentParser(
        description="Compare a DUT commit trace against Spike's, by commit index."
    )
    parser.add_argument("--dut", help="canonical DUT trace (+RETIRE_LOG)")
    parser.add_argument("--spike", help="canonical Spike trace (normalize.py spike-log)")
    parser.add_argument("--cut-pcs", help="comma-separated hex pcs of the tohost store(s)")
    parser.add_argument("--out", help="results.json path")
    parser.add_argument("--rtl-digest", default="")
    parser.add_argument("--tb-digest", default="")
    parser.add_argument("--spike-commit", default="")
    parser.add_argument("--selftest", action="store_true",
                        help="run the comparator's own negative controls and exit")
    args = parser.parse_args(argv)

    if args.selftest:
        return selftest()

    missing = [name for name, value in (("--dut", args.dut), ("--spike", args.spike),
                                        ("--cut-pcs", args.cut_pcs), ("--out", args.out))
               if not value]
    if missing:
        parser.error("missing %s" % ", ".join(missing))

    try:
        cut_pcs = parse_cut_pcs(args.cut_pcs)
        result = run_file(args.dut, args.spike, cut_pcs)
    except TraceError as exc:
        # Unreadable or malformed input is a failure of the run, and it is
        # written down like any other: results.json must exist for the gate.
        result = {
            "status": "fail",
            "reason": "invalid_trace",
            "error": str(exc),
            "cut_pcs": [],
            "cut_index": None,
            "cut_pc": None,
            "dut_lines": 0,
            "spike_lines": 0,
            "dut_count": 0,
            "spike_count": 0,
            "first_divergence": None,
            "dut": args.dut,
            "spike": args.spike,
        }
        result["rtl_digest"] = args.rtl_digest
        result["tb_digest"] = args.tb_digest
        result["spike_commit"] = args.spike_commit
        print("COMPARE: fail reason=invalid_trace %s" % exc)
        write_results(args.out, result)
        return 1

    result["rtl_digest"] = args.rtl_digest
    result["tb_digest"] = args.tb_digest
    result["spike_commit"] = args.spike_commit
    print_verdict(result)
    write_results(args.out, result)
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
