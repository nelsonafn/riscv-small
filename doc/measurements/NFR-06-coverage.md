# NFR-06 - functional coverage

| Field | Value |
|---|---|
| Requirement | Functional coverage shall close on the instruction set and memory behaviour it claims. |
| Gap | `G-04`, `G-11` |
| Owner | verification lead |
| Status | **bins closed** - 40 of the 40 `A-09` bar bins and 52 of the 52 report bins hit over 6 coverpoints, `G-03` closed 2026-11-06. `NFR-06` itself stays `partial`: its acceptance also needs every `FR` `verified` (`A-09`) |

## Method

The `A-09` bar is **40 bins**: one per instruction that `doc/spec.md` §4.1 says `rtl/instruction_decode.sv`
decodes today (37) plus one per memory width (3). It is declared as a covergroup, not as prose: `cg_inst` /
`cp_inst` for the instructions and `cg_mem` / `cp_width` for the widths, both in
`tb/env/top/riscv_small_coverage.sv` and both sampled from the **monitor** analysis port — never from the driver,
the sequence or the reference model. A third covergroup, `cg_beat` / `cp_beat` (`split_beat1`, `split_beat2`),
samples the same port and counts the two beats of an access the core split across a word boundary (`FR-42`,
`G-22`); it is outside the bar on purpose, because it proves that the split was **measured** and not that a
required instruction class was exercised, and its two bins must both be hit for that claim — one bin alone says
the core issued one half of a crossing access.

`scripts/verify/coverage.cmake` runs the manifest tests against the instrumented snapshot, merges the databases
with `xcrg` and reads the text report per coverpoint and per bin. It publishes two different totals, and they must
not be confused:

- `bins_covered` / `bins_total` — the whole report (currently 52: the 40 bar bins, `cp_lane` / `cp_dir` /
  `cp_subword_lane` as ten further memory bins that predate the bar, and `cp_beat`'s two bins that WP-13 added);
- `bar_covered` / `bar_total` — only `cp_inst` + `cp_width`, i.e. the `A-09` bar (40). The bar is derived in
  `scripts/verify/coverage.cmake:333` (`BAR_COVERPOINTS "cp_inst;cp_width"`), not written as a constant, so a new
  covergroup moves the report total and leaves the bar where it is.

The bar is also executable: `--require-bins <cp.bin,...>` fails when a bin is **absent from the report** (the
covergroup never declared it) or **present with zero hits** (declared, unstimulated), and reports the two cases
separately.

Two limits apply to every number below. A hit is a **fetch**, not a retire: `if_id_flush`
(`rtl/control.sv:265-286`) can discard an instruction the monitor already published, so a bin proves the class
accepted on the fetch handshake (`inst_rd_en && inst_ready`); the collector has not been migrated to the retire
stream (`G-28` is closed, the bins are still fetch-based). And a hit verifies no `FR` on its own, because the model
executes the load/store subset but publishes only `SW` predictions (`G-04`) — the requirement-to-bin map is in [verification.md](../verification.md#coverage-bins).

## Command

```bash
make coverage                 # elaborate + simulate + xcrg merge
make coverage COVERAGE_ARGS="--test T-01 --seed 42"
make coverage COVERAGE_ARGS="--require-bins cp_beat.split_beat1,cp_beat.split_beat2"  # green: the split was measured, both beats hit
make coverage COVERAGE_ARGS="--require-bins cp_inst.nosuchbin"                        # red: absent from the report
```

## Result

Measured 2026-11-19 over the **46** manifest tests the coverage run executes (`T-01`, `T-02`, `T-06`,
`T-08`..`T-46`, `T-50`..`T-53`; the three `spike:` rows `T-47`..`T-49` are trace comparisons and not coverage
runs, so 46 of the 49 manifest rows), at `rtl_digest` `sha256:f84ea86b…` and `tb_digest` `sha256:7860d1b0…`
(`build/cov_report/summary.json`):

| Metric | Value |
|---|---|
| Coverpoints | 6 |
| Whole report | **52 of 52** bins (`uncovered` empty, `xcrg` score 100 %) |
| `A-09` bar | **40 of 40** |
| `cp_inst` | **37 of 37** |
| `cp_width` | **3 of 3** |
| `cg_mem` | **13 of 13** |
| `cg_beat` | **2 of 2** (`split_beat1` 63 hits, `split_beat2` 63 hits) |

WP-6 had taken the bar to 21/40 by decoding the width from `funct3` and closing `sb`/`sh`. WP-7 closed the last
nineteen with one image per instruction — `jalr` (`T-17`, plus the local odd-target image `T-37`) and the
eighteen `T-19`..`T-36` — and the bar is now full. `T-38`..`T-43` were added afterwards as `FR` evidence
(`bne`, `ori`, `slli`, `lui`, `auipc`, `add`); they closed no bin, because those bins were already hit. WP-13 added
the two `cp_beat` bins and no bar bin, because the bar was already full: `T-52` (`sanity:rv32ui-p-ma_data`) runs
the image that crosses a word boundary and hit both bins 63 times, so the report now says the split was measured
rather than only that a testbench checker accepted it (`FR-42`, `G-22` closed 2026-11-19). No bin is hit by an accident: each one has a
manifest row and a mutant that makes that row fail (check 11, 47 mutant-bearing rows).

What a hit does **not** mean is unchanged: it is an accepted **fetch**, not a retire (`G-28` is closed but the
collector is still fetch-based), and it
verifies no `FR` by itself (`G-04`). Closing `G-03` closes the *bins*; `A-09` still needs every `FR` row
`verified`. Code coverage is instrumented with `--cc_type sbct --cc_libs` and merged by the same `xcrg` run.

## History

| Date | RTL digest | Coverpoints | Functional | Bar | Method |
|---|---|---|---|---|---|
| 2026-10-28 | `sha256:0418049b...` | 4 | 91.67 % (`word_w` open, `FR-11`) | not declared as bins | `xcrg` over T-01/T-02/T-06 |
| 2026-11-04 | `sha256:d12dc1a2...` | 4 | 91.67 % (`word_w` open, `FR-11`) | not declared as bins | `xcrg` over the eight manifest tests (TB `f542affd...`) |
| 2026-11-05 | `sha256:d12dc1a2...` | 5 | 27/50 bins (`xcrg` score 66.1036 %; `cp_inst` 15/37, `word_w` open) | **17/40** | WP-5: `cg_inst` added, report parsed per bin (TB `506d4810...`) |
| 2026-11-05 | `sha256:f48ab029...` | 5 | 31/50 bins (`xcrg` score 74.3243 %; `cp_inst` 18/37, `cg_mem` 13/13) | **21/40** | WP-6: width decoded, `sb`/`sh`/`st_ld` tests added (TB `ae4e6c79...`) |
| 2026-11-06 | `sha256:3541dfb8...` | 5 | 50/50 bins, `uncovered` empty (100 %; `cp_inst` 37/37) | **40/40** | WP-7: one image per instruction, 19 bins closed (TB `ae4e6c79...`) |
| 2026-11-07 | `sha256:120b211f...` | 5 | 50/50 bins, `uncovered` empty (100 %; `cp_inst` 37/37) | **40/40** | WP-8: retire probe added; the collector filters retire events out of `cg_mem` (TB `86bcd471...`) |
| 2026-11-18 | `sha256:120b211f...` | 5 | 50/50 bins, `uncovered` empty (100 %; `cp_inst` 37/37) | **40/40** | WP-9: re-measured unchanged; the three `spike:` manifest rows are trace comparisons and not coverage runs (TB `c8ba82d7...`) |
| 2026-11-18 | `sha256:b914f2e1...` | 5 | 50/50 bins, `uncovered` empty (100 %; `cp_inst` 37/37) | **40/40** | WP-11: re-measured unchanged after every image moved to `0x80000000`; the manifest carries 46 rows, 43 of them coverage runs (TB `c4bad285...`) |
| 2026-11-18 | `sha256:b914f2e1...` | 5 | 50/50 bins, `uncovered` empty (100 %; `cp_inst` 37/37) | **40/40** | Re-run after the driver fix in `tb/env/agents/riscv_small_agent/riscv_small_driver.sv` (an unmatched fetch is answered with `inst_ready` before the program is entered); unchanged, same 5 coverpoints and no uncovered bin, and the RTL digest did not move — only the testbench's (TB `066dce85...`) |
| 2026-11-19 | `sha256:f84ea86b...` | 6 | 52/52 bins, `uncovered` empty (100 %; `cp_inst` 37/37, `cg_mem` 13/13, `cg_beat` 2/2) | **40/40** | WP-13: `cg_beat`/`cp_beat` added (2 bins; `split_beat1` and `split_beat2` 63 hits each) for the word-crossing split (`FR-42`, `G-22`), so the report grows by 2 and the bar does not; 46 of 49 manifest rows are coverage runs (TB `7860d1b0...`) |

The 2026-11-04 figure is not comparable with the 2026-11-05 one: the first measured four memory coverpoints and
nothing of the instruction set, so it was true and flattering at the same time. From 2026-11-05 the headline is the
bar, and it is read together with the uncovered names.
