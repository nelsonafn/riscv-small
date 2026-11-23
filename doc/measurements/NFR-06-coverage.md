# NFR-06 - functional coverage

| Field | Value |
|---|---|
| Requirement | Functional coverage shall close on the instruction set and memory behaviour it claims. |
| Gap | `G-04`, `G-11` |
| Owner | verification lead |
| Status | **bins closed** - 40 of the 40 `A-09` bar bins and **66 of the 66** report bins hit over **9** coverpoints, `G-03` closed 2026-11-06 and the report re-measured on 2026-11-21 at RTL `sha256:2e91301d…`. `NFR-06` itself stays `partial`: its acceptance also needs every **phase-1** `FR` `verified` (`A-09`, re-scoped by the designer on 2026-11-19 to `FR-01`..`FR-31` and `FR-37`..`FR-52`, 47 of the 59 rows), and that is not a coverage question - the bins this file measures are the other half; 24 of the 47 are `verified` today |

## Method

The `A-09` **bin bar** is **40 bins** — the coverage clause of `A-09`, and a different half of the same
assumption from the `FR` bar, which the designer re-scoped on 2026-11-19 to 47 phase-1 rows; this file measures
only the bins: one per instruction that `doc/spec.md` §4.1 says `rtl/instruction_decode.sv`
decodes today (37) plus one per memory width (3). It is declared as a covergroup, not as prose: `cg_inst` /
`cp_inst` for the instructions and `cg_mem` / `cp_width` for the widths, both in
`tb/env/top/riscv_small_coverage.sv` and both sampled from the **monitor** analysis port — never from the driver,
the sequence or the reference model. A third covergroup, `cg_beat` / `cp_beat` (`split_beat1`, `split_beat2`),
samples the same port and counts the two beats of an access the core split across a word boundary (`FR-42`,
`G-22`); it is outside the bar on purpose, because it proves that the split was **measured** and not that a
required instruction class was exercised, and its two bins must both be hit for that claim — one bin alone says
the core issued one half of a crossing access. A fourth covergroup, `cg_csr` / `cp_csr_op`, `cp_csr_group` and
`cp_trap_cause` (6, 5 and 3 bins), samples the same port and records the **trap path** rather than a new
instruction family: which of the six `Zicsr` operations ran, which of the five register groups it addressed, and
which cause a trap carried (`FR-47`, `FR-50`, `FR-22`).

`scripts/verify/coverage.cmake` runs the manifest tests against the instrumented snapshot, merges the databases
with `xcrg` and reads the text report per coverpoint and per bin. It publishes two different totals, and they must
not be confused:

- `bins_covered` / `bins_total` — the whole report (**66** today: the 40 bar bins, `cp_lane` / `cp_dir` /
  `cp_subword_lane` as ten further memory bins that predate the bar, `cp_beat`'s two bins that WP-13 added, and
  `cg_csr`'s fourteen that WP-14 added — `cp_csr_op` 6, `cp_csr_group` 5, `cp_trap_cause` 3);
- `bar_covered` / `bar_total` — only `cp_inst` + `cp_width`, i.e. the `A-09` bin bar (40). The bar is derived in
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

Measured 2026-11-21 over the **47** manifest tests the coverage run executes (`T-01`, `T-02`, `T-03`, `T-06`,
`T-08`..`T-46`, `T-50`..`T-53`; the three `spike:` rows `T-47`..`T-49` are trace comparisons and not coverage
runs, so 47 of the 50 manifest rows), at `rtl_digest` `sha256:2e91301d…` and `tb_digest` `sha256:0091e260…`
(`build/cov_report/summary.json`):

| Metric | Value |
|---|---|
| Coverpoints | 9 |
| Whole report | **66 of 66** bins (`uncovered` empty, `xcrg` score 100 %) |
| `A-09` bin bar (its coverage clause only) | **40 of 40** |
| `cp_inst` | **37 of 37** |
| `cp_width` | **3 of 3** |
| `cg_mem` | **13 of 13** |
| `cg_beat` | **2 of 2** (`split_beat1` 63 hits, `split_beat2` 63 hits) |
| `cg_csr` | **14 of 14** (`cp_csr_op` 6/6, `cp_csr_group` 5/5, `cp_trap_cause` 3/3) |

WP-6 had taken the bar to 21/40 by decoding the width from `funct3` and closing `sb`/`sh`. WP-7 closed the last
nineteen with one image per instruction — `jalr` (`T-17`, plus the local odd-target image `T-37`) and the
eighteen `T-19`..`T-36` — and the bar is now full. `T-38`..`T-43` were added afterwards as `FR` evidence
(`bne`, `ori`, `slli`, `lui`, `auipc`, `add`); they closed no bin, because those bins were already hit. WP-13 added
the two `cp_beat` bins and no bar bin, because the bar was already full: `T-52` (`sanity:rv32ui-p-ma_data`) runs
the image that crosses a word boundary and hit both bins 63 times, so the report now says the split was measured
rather than only that a testbench checker accepted it (`FR-42`, `G-22` closed 2026-11-19). WP-14 added
`cg_csr`'s fourteen bins and, again, no bar bin: `T-03` (`riscv_small_csr_test`) exercises the six `Zicsr`
operations, the five register groups and three trap causes, so the report says the **trap path** was walked
rather than only that a checker accepted it (`FR-47`, `FR-50`, `FR-22`) — it is not a new instruction family,
which is why the bar stays at 40. No bin is hit by an accident: each one has a
manifest row and a mutant that makes that row fail (check 11, 48 mutant-bearing rows).

What a hit does **not** mean is unchanged: it is an accepted **fetch**, not a retire (`G-28` is closed but the
collector is still fetch-based), and it
verifies no `FR` by itself (`G-04`). Closing `G-03` closes the *bins*; `A-09` still needs every **phase-1** `FR`
row `verified` — `FR-01`..`FR-31` and `FR-37`..`FR-52`, 47 of the 59 rows since the 2026-11-19 re-scope, the
twelve outside it being `FR-32`..`FR-36` (phase 2) and `FR-53`..`FR-59` (debug) — so the evidence here closes
the coverage clause of the bar and nothing else. Code coverage is instrumented with `--cc_type sbct --cc_libs` and merged by the same `xcrg` run.

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
| 2026-11-21 | `sha256:2e91301d...` | 9 | 66/66 bins, `uncovered` empty (100 %; `cp_inst` 37/37, `cg_mem` 13/13, `cg_beat` 2/2, `cg_csr` 14/14) | **40/40** | WP-14: `cg_csr` added (14 bins: `cp_csr_op` 6, `cp_csr_group` 5, `cp_trap_cause` 3) for the CSR file and the trap path (`FR-47`, `FR-50`, `FR-22`), so the report grows by 14 and the bar does not; the manifest carries 50 rows, 47 of them coverage runs (`T-03` added, the three `spike:` rows excluded) (TB `0091e260...`) |

The 2026-11-04 figure is not comparable with the 2026-11-05 one: the first measured four memory coverpoints and
nothing of the instruction set, so it was true and flattering at the same time. From 2026-11-05 the headline is the
bar, and it is read together with the uncovered names.
