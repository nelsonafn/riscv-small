# NFR-06 - functional coverage

| Field | Value |
|---|---|
| Requirement | Functional coverage shall close on the instruction set and memory behaviour it claims. |
| Gap | `G-03`, `G-04`, `G-11` |
| Owner | verification lead |
| Status | partial - `cg_mem` closed, 19 instruction bins owed to `E4` |

## Method

The `A-09` bar is **40 bins**: one per instruction that `doc/spec.md` §4.1 says `rtl/instruction_decode.sv`
decodes today (37) plus one per memory width (3). It is declared as a covergroup, not as prose: `cg_inst` /
`cp_inst` for the instructions and `cg_mem` / `cp_width` for the widths, both in
`tb/env/top/riscv_small_coverage.sv` and both sampled from the **monitor** analysis port — never from the driver,
the sequence or the reference model.

`scripts/verify/coverage.cmake` runs the manifest tests against the instrumented snapshot, merges the databases
with `xcrg` and reads the text report per coverpoint and per bin. It publishes two different totals, and they must
not be confused:

- `bins_covered` / `bins_total` — the whole report (currently 50, because `cp_lane`, `cp_dir` and
  `cp_subword_lane` are ten further bins that predate the bar);
- `bar_covered` / `bar_total` — only `cp_inst` + `cp_width`, i.e. the `A-09` bar (40).

The bar is also executable: `--require-bins <cp.bin,...>` fails when a bin is **absent from the report** (the
covergroup never declared it) or **present with zero hits** (declared, unstimulated), and reports the two cases
separately.

Two limits apply to every number below. A hit is a **fetch**, not a retire: `if_id_flush`
(`rtl/control.sv:246-258`) can discard an instruction the monitor already published, so a bin proves the class
accepted on the fetch handshake (`inst_rd_en && inst_ready`, `G-28`, `E3`). And a hit verifies no `FR` on its own, because the reference model still covers only
`LW`/`SW` (`G-04`) — the requirement-to-bin map is in [verification.md](../verification.md#coverage-bins).

## Command

```bash
make coverage                 # elaborate + simulate + xcrg merge
make coverage COVERAGE_ARGS="--test T-01 --seed 42"
make coverage COVERAGE_ARGS="--require-bins cp_inst.addi,cp_inst.beq"   # green: both bins hit
make coverage COVERAGE_ARGS="--require-bins cp_inst.slti"               # red until E4: present, zero hits
```

## Result

Measured 2026-11-05 over all eleven manifest tests (`T-01`, `T-02`, `T-06`, `T-08`, `T-09`, `T-10`, `T-11`,
`T-12`, `T-13`, `T-14`, `T-15`), at `rtl_digest` `sha256:f48ab029…b9586d` and `tb_digest` `sha256:ae4e6c79…8b5764`
(`build/cov_report/summary.json`):

| Metric | Value |
|---|---|
| Coverpoints | 5 |
| Whole report | 31 of 50 bins (`xcrg` score 74.3243 %, the mean of the two covergroups) |
| `A-09` bar | **21 of 40** |
| `cp_inst` | 18 of 37 |
| `cp_width` | **3 of 3** |

`cg_mem` is now **13 of 13**: WP-6 decoded the width from `funct3` (`access_size`, `rtl/riscv_definitions_pkg.sv`)
instead of the one-bit `logic'(rd_wr_ctrl)` cast, so `cp_width.word_w` fills. The three images added by the same WP
(`T-13` `sb`, `T-14` `sh`, `T-15` `st_ld`) also closed `cp_inst.sb` and `cp_inst.sh`, and their `la` prologue
reached `cp_inst.auipc`.

The 19 open `cp_inst` bins are all stimulus, not collector, gaps, and all belong to `E4`: `jalr`, four branches,
six immediates (`slti`, `sltiu`, `xori`, `srli`, `srai`, `andi`) and eight ALU operations (`sub`, `sll`, `slt`,
`sltu`, `xor_`, `srl`, `sra`, `or_`). Code coverage is instrumented with `--cc_type sbct --cc_libs` and merged by
the same `xcrg` run.

## History

| Date | RTL digest | Coverpoints | Functional | Bar | Method |
|---|---|---|---|---|---|
| 2026-10-28 | `sha256:0418049b...` | 4 | 91.67 % (`word_w` open, `FR-11`) | not declared as bins | `xcrg` over T-01/T-02/T-06 |
| 2026-11-04 | `sha256:d12dc1a2...` | 4 | 91.67 % (`word_w` open, `FR-11`) | not declared as bins | `xcrg` over the eight manifest tests (TB `f542affd...`) |
| 2026-11-05 | `sha256:d12dc1a2...` | 5 | 27/50 bins (`xcrg` score 66.1036 %; `cp_inst` 15/37, `word_w` open) | **17/40** | WP-5: `cg_inst` added, report parsed per bin (TB `506d4810...`) |
| 2026-11-05 | `sha256:f48ab029...` | 5 | 31/50 bins (`xcrg` score 74.3243 %; `cp_inst` 18/37, `cg_mem` 13/13) | **21/40** | WP-6: width decoded, `sb`/`sh`/`st_ld` tests added (TB `ae4e6c79...`) |

The 2026-11-04 figure is not comparable with the 2026-11-05 one: the first measured four memory coverpoints and
nothing of the instruction set, so it was true and flattering at the same time. From 2026-11-05 the headline is the
bar, and it is read together with the uncovered names.
