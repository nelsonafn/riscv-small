# Verification Status

Traceability and honest status. The specification states the requirement; this file states what proves it.

| Field | Value |
|---|---|
| Status | draft |
| Version | v0.8 |
| Baseline | `doc/spec.md` v0.7.3 (RISC-V ISA v20260120; RISC-V Debug Specification v1.0); `rtl_digest` `sha256:0418049b...` after `FR-12`; `T-01`, `T-02` and `T-06` green at that digest (2026-10-28) |
| Implements | [spec.md](spec.md) |

## Tests

| ID | Test | Scope | Status |
|---|---|---|---|
| T-01 | `riscv_small_basic_load_store_test` | LW/SW through the pipeline | implemented |
| T-02 | `riscv_small_corner_test` | corner load/store addresses | implemented |
| T-06 | `riscv_small_subword_access_test` | `LB`/`LBU` at offsets 0-3 and `LH`/`LHU` at offsets 0 and 2 of one word; each loaded register is stored so the value crosses the data port | verified (`FR-12`) |
| T-03 | CSR and trap test | the `FR-50` map, `misa`, `mepc`/`mcause`/`mtval`, `mscratch`, the reset vector | deferred (`G-13`) |
| T-04 | timer and interrupt test | `mtip`/`meip`/`msip`, `mie`/`mip`/`mstatus`, entry stack, priority | deferred (`G-14`) |
| T-05 | debug test | hart-side run control, abstract commands, program buffer, triggers, single step, the `dbg_auth` strap; needs a Debug Module model | deferred (`G-23`) |

## Traceability

One row per functional requirement of `doc/spec.md` §4. Each row was derived in three passes: read the clause,
locate it in `rtl/`, then ask whether `tb/` observes it. `verified` needs a test that compares a value; only `T-01`
does, and only through the reference model and scoreboard, which understand `LW` and `SW` alone
(`tb/env/ref_model/riscv_small_ref_model.sv:74-116`), while `T-02` adds no stimulus
(`tb/tests/sequence_lib/riscv_small_corner_seq.sv:31`). `verified` therefore lags `implemented`: thirteen
`implemented` rows execute in RTL with no directed test, and all of them wait on `G-04` until the ISS grows beyond
`LW`/`SW`. A row is `partial` when the clause executes but a named gap shows it wrong for part of its domain — eight
rows, `FR-06`, `FR-07`, `FR-08`, `FR-11`, `FR-12`, `FR-17`, `FR-22` and `FR-41`; the
`deferred` rows keep the status of `doc/spec.md` §4 because the capability is absent, not because the intent is
doubtful.

The `Test` column names the manifest test (`scripts/verify/tests.tsv`) that is evidence for the row; `—` means no
test exercises it yet. That is the same statement as `no test (G-04)` in the evidence column, and it does not by
itself make a row `deferred`: `deferred` is about the capability, not about the test.

| Requirement | Test | Evidence | Status |
|---|---|---|---|
| FR-01 R-type ALU ops | — | `rtl/instruction_decode.sv:323-329`, `rtl/alu.sv:52-92`; no test (`G-04`) | implemented |
| FR-02 immediate ALU ops | — | `rtl/instruction_decode.sv:309-322`, `rtl/instruction_decode.sv:209-213`, `rtl/riscv_definitions_pkg.sv:276-282`; no test (`G-04`) | implemented |
| FR-03 shift-immediate ops | — | `rtl/instruction_decode.sv:312-318`, `rtl/alu.sv:56-81`; no test (`G-04`) | implemented |
| FR-04 LUI upper immediate | — | `rtl/instruction_decode.sv:248-253`, `rtl/instruction_decode.sv:221-223`; no test (`G-04`) | implemented |
| FR-05 AUIPC PC-relative | — | `rtl/instruction_decode.sv:254-260`, `rtl/alu.sv:53-55`; no test (`G-04`) | implemented |
| FR-06 JAL link and target | — | `rtl/instruction_decode.sv:261-268`, `rtl/jump_decision.sv:98-112`, `rtl/instruction_fetch.sv:88-101`; no test (`G-04`); backward offsets wrong (`G-20`) | partial |
| FR-07 JALR indirect target | — | `rtl/instruction_decode.sv:270-277`, `rtl/jump_decision.sv:103-111`; no test (`G-04`); bit 0 not cleared (`G-07`), backward offsets wrong (`G-20`) | partial |
| FR-08 six conditional branches | — | `rtl/instruction_decode.sv:279-282`, `rtl/jump_decision.sv:117-164`; no test (`G-04`); backward offsets wrong (`G-20`) | partial |
| FR-09 LW load word | `T-01` | `rtl/instruction_decode.sv:283-296`, `rtl/memory_access.sv:88-90`; `T-01`, `tb/env/top/riscv_small_scoreboard.sv:78-79` | verified |
| FR-10 SW store word | `T-01` | `rtl/instruction_decode.sv:297-308`, `rtl/execution.sv:89-108`, `rtl/riscv_small.sv:193-196`; `T-01`, `tb/env/top/riscv_small_scoreboard.sv:78-79` | verified |
| FR-11 SB and SH lane select | — | `rtl/instruction_decode.sv:297-308`, `rtl/execution.sv:157-174`; the store drives one lane only, never `data_addr[1:0]` (`G-08`, release blocker), and has no byte strobes (`G-22`). The width output is also wrong: `logic'(rd_wr_ctrl)` (`rtl/riscv_small.sv:118`) casts to the one-bit unsized `logic`, so the port carries `funct3[0]` and a word access reads `2'b00` — found by the `cp_width.word_w` coverage bin, which cannot fill. No test (`G-04`) | partial |
| FR-12 LB LH LBU LHU extend | `T-06` | `rtl/memory_access.sv:68-69` selects the lane from `alu_wb[1:0]`, `:91-105` extends it from `data.u_data` by indexed part-select; `T-06` drives 12 loads (`LB`/`LBU` at 4 offsets, `LH`/`LHU` at 2) and the scoreboard compares the stored value against the ISS | verified |
| FR-13 effective data address | — | `rtl/instruction_decode.sv:209-232`, `rtl/execution.sv:113-152`, `rtl/riscv_small.sv:119`; no test (`G-04`) | implemented |
| FR-14 x0 reads zero | — | `rtl/reg_file.sv:64-89`, `rtl/reg_file.sv:100-103`; no test (`G-04`) | implemented |
| FR-15 write-read same cycle | — | `rtl/reg_file.sv:71-73`, `rtl/reg_file.sv:83-85`; no test (`G-04`) | implemented |
| FR-16 arithmetic forwarding | — | `rtl/control.sv:184-227`, `rtl/execution.sv:113-152`; no test (`G-04`) | implemented |
| FR-17 load result to consumer | — | `rtl/control.sv:115-140`, `rtl/control.sv:184-227`; no test (`G-04`); write-back lost on the load-use freeze (`G-19`) | partial |
| FR-18 store data forwarding | — | `rtl/execution.sv:157-174`, `rtl/control.sv:205-227`; no test (`G-04`) | implemented |
| FR-19 branch operand forwarding | — | `rtl/instruction_decode.sv:134-173`, `rtl/control.sv:108-177`; no test (`G-04`) | implemented |
| FR-20 one fetch address per cycle | — | `rtl/control.sv:101`, `rtl/instruction_fetch.sv:63-77`; no test (`G-04`) | implemented |
| FR-21 load waits for data_ready | — | `rtl/control.sv:246-251`; no test (`G-04`) | implemented |
| FR-22 exception discards fetch | — | `rtl/control.sv:234-238`, `rtl/control.sv:255`, `rtl/instruction_fetch.sv:95-97`; no test (`G-04`); vector hardcoded to 1000 (`G-01`) | partial |
| FR-23 mepc and mcause | — | `rtl/control.sv:257-268`; trap state unreadable, no CSR port; no test (`G-01`, `G-02`, `G-13`) | deferred |
| FR-24 illegal-instruction trap | — | `rtl/instruction_decode.sv:238-247`, `rtl/instruction_decode.sv:325`; decode falls through to no-write; no test (`G-06`, `G-13`) | deferred |
| FR-25 ECALL and EBREAK trap | — | `rtl/instruction_decode.sv:333-335`; decoded as no-operation; no test (`G-06`, `G-13`) | deferred |
| FR-26 FENCE ordering | — | `rtl/instruction_decode.sv:330-332`; decoded as no-operation; no test (`G-06`) | deferred |
| FR-27 cache-line fetch burst | — | `rtl/instruction_fetch.sv:63-77`; one word address per cycle, no last-beat signal; no test (`G-15`) | deferred |
| FR-28 hold outstanding fetch | — | `rtl/control.sv:241-243`, `rtl/instruction_fetch.sv:84-103`; PC advances with the grant withheld; no test (`G-09`, `G-15`) | deferred |
| FR-29 mtvec direct mode | — | `rtl/control.sv:255`, `rtl/instruction_decode.sv:333-335`; constant vector, no CSR write; no test (`G-01`, `G-13`) | deferred |
| FR-30 mtvec vectored mode | — | `rtl/control.sv:255`; constant vector, no mode field; no test (`G-01`, `G-14`) | deferred |
| FR-31 fence.i invalidates cache | — | `rtl/instruction_decode.sv:330-335`; no-operation, no cache; no test (`G-06`, `G-15`) | deferred |
| FR-32 mhartid report | — | `rtl/riscv_small.sv:41-57`; no CSR and no hart-identity input; no test (`G-13`, `G-16`) | deferred |
| FR-33 per-hart behaviour | — | `rtl/riscv_small.sv:38-58`; single hart, no hart-count parameter; no test (`G-16`) | deferred |
| FR-34 configuration invariance | — | `rtl/riscv_small.sv:38-58`; no configuration parameters; no test (`G-15`, `G-16`) | deferred |
| FR-35 Zaamo and Zalrsc | — | `rtl/riscv_definitions_pkg.sv:129-187`, `rtl/instruction_decode.sv:323-329`; no A encodings; no test (`G-16`) | deferred |
| FR-36 machine software interrupt | — | `rtl/riscv_small.sv:44`; only the level-sensitive exception input; no test (`G-14`, `G-16`) | deferred |
| FR-37 misa advertises extensions | — | `rtl/instruction_decode.sv:333-335`; no CSR file; no test (`G-13`, `G-16`) | deferred |
| FR-38 store waits for grant | — | `rtl/control.sv:246`; stall also requires a load destination; no test (`G-18`) | deferred |
| FR-39 machine timer interrupt | — | `rtl/riscv_small.sv:44`; no interrupt input and no timer; no test (`G-14`) | deferred |
| FR-40 machine external interrupt | — | `rtl/riscv_small.sv:44`; no external interrupt path; no test (`G-14`) | deferred |
| FR-41 reset behaviour | — | `rtl/instruction_fetch.sv:69` and `rtl/control.sv:257` hardcode `or negedge rst_n`; there is no de-assertion synchroniser and no reset-style macro in `rtl/` (`G-21`); no test (`G-04`) | partial |
| FR-42 misaligned split | — | `rtl/riscv_small.sv:119` issues one access per instruction from `alu_ma`; there is no second beat, no address increment and no strobe recomputation (`G-22`); no test (`G-04`) | deferred |
| FR-43 `M` extension | — | `rtl/instruction_decode.sv:323-329` ignores every function bit but bit 5, so the `M` group aliases onto the base ALU (`G-06`); no test (`G-04`) | deferred |
| FR-44 `C` and `IALIGN=16` | — | `rtl/instruction_decode.sv:45` takes a 32-bit `inst` and `:247` decodes on the opcode field, so no 16-bit parcel is formed and a 32-bit instruction spanning two fetched words is not assembled (`G-06`); no test (`G-04`) | deferred |
| FR-45 `MRET` | — | `rtl/instruction_decode.sv:333-335` decodes the SYSTEM group as a no-operation; there is no `MRET` decode and no `mepc`/`mstatus` (`G-13`, `G-14`); no test (`G-04`) | deferred |
| FR-46 `WFI` | — | `rtl/instruction_decode.sv:333-335` decodes the whole SYSTEM group as a no-operation, so `WFI` currently retires as a legal no-op by accident; there is no `mstatus.TW` and no CSR file, which is what the row still needs (`G-13`); no test (`G-04`) | deferred |
| FR-47 `Zicsr` instructions | — | `rtl/instruction_decode.sv:333-335` decodes CSR encodings as a no-operation; no CSR file and no CSR port (`G-13`); no test (`G-04`) | deferred |
| FR-48 interrupt entry and priority | — | `rtl/control.sv:255-268` hardcodes the trap vector and ties the cause to zero; there is no `mstatus`/`mie`/`mip` and no interrupt input (`G-01`, `G-02`, `G-13`, `G-14`); no test (`G-04`) | deferred |
| FR-49 `Zicntr` | — | no CSR port and no CSR instruction, so `cycle`/`time`/`instret` are unreachable (`rtl/instruction_decode.sv:333-335`, `G-13`); no test (`G-04`) | deferred |
| FR-50 CSR file and map | — | no CSR file and no `CSR*` decoding: the whole SYSTEM opcode group is a no-operation (`rtl/instruction_decode.sv:333-335`) and the top has no CSR read or write port (`rtl/riscv_small.sv:41-57`) (`G-13`); no test (`G-04`) | deferred |
| FR-51 `mscratch` | — | no CSR file and no `CSR*` decoding (`rtl/instruction_decode.sv:333-335`, `rtl/riscv_small.sv:41-57`), so 0x340 is unreachable (`G-13`); no test (`G-04`) | deferred |
| FR-52 `mtval` | — | no CSR file and no `CSR*` decoding (`rtl/instruction_decode.sv:333-335`), and the cause the trap logic registers is tied to zero (`rtl/control.sv:257-268`) (`G-13`); no test (`G-04`) | deferred |
| FR-53 debug mode | — | the top has no debug port (`rtl/riscv_small.sv:41-57`), no debug mode and no `dcsr`/`dpc`/`dscratch`; the SYSTEM group is a no-operation (`rtl/instruction_decode.sv:333-335`) (`G-23`); no test (`G-04`) | deferred |
| FR-54 run control | — | no `dbg_*` port on the DUT (`rtl/riscv_small.sv:41-57`) and no debug state to control (`G-23`); no test (`G-04`) | deferred |
| FR-55 abstract commands | — | no debug port, no CSR file and no command channel (`rtl/riscv_small.sv:41-57`, `rtl/instruction_decode.sv:333-335`) (`G-23`); no test (`G-04`) | deferred |
| FR-56 program buffer | — | the fetch path takes instructions only from the instruction-memory port (`rtl/instruction_fetch.sv`), so a second instruction source does not exist (`G-23`); no test (`G-04`) | deferred |
| FR-57 `Sdtrig` triggers | — | no trigger unit and no `tselect`/`tdata`/`tinfo` decoding (`rtl/instruction_decode.sv:333-335`) (`G-24`); no test (`G-04`) | deferred |
| FR-58 single step | — | no debug mode to re-enter (`G-23`); no test (`G-04`) | deferred |
| FR-59 `dbg_auth` strap | — | no debug port, so there is nothing for the strap to gate (`rtl/riscv_small.sv:41-57`) (`G-23`); no test (`G-04`) | deferred |

## Signoff gate

`A-09` and `Q-11` fix the bar; `cmake -P scripts/verify/signoff_check.cmake` turns it into an exit code. The target is declared
in `CMakeLists.txt` §12, so `make signoff-check` and `make -C build signoff-check` are the same command. It writes
`build/signoff/report.md`; `make signoff-check SIGNOFF_ARGS="--wp <n>"` runs the work-package subset (checks 1-5,
7 and 11). Check 11 is what makes the work-package gate test-first rather than pass-only: a test written after its RTL has
no recorded failing run, so it has no red evidence at an older `rtl_digest`.

The tests run under CTest: `CMakeLists.txt` §12 declares one CTest test per line of `scripts/verify/tests.tsv`, with
the timeout and the `wp`/requirement labels. The verdict comes from the `UVM_RESULT: PASS` line the testbench
prints, because `xsim` exits `0` even when the run ends with `UVM_ERROR`s.

| # | Check | Fails when | 2026-10-28 |
|---|---|---|---|
| 1 | `make docs-check`, `make docs-figs-check` | exit != 0 | ok |
| 2 | `spec.md` x this file: same FR set, same status | count or status diverge | ok |
| 3 | every `verified` row names a `T-xx` in `scripts/verify/tests.tsv` and a file in `tb/tests/` | ghost test | ok |
| 4 | no open question, no expired `A-xx` | a `Q` open, or an `A-xx` past its due date | ok |
| 5 | latest `build/regress/*/results.json` | `fail`/`timeout` > 0, stale `rtl_digest`, older than 7 days | ok |
| 6 | `build/sanity/summary.json` (`NFR-05`) | absent, not measured, or any image fails | not measurable |
| 7 | `build/cov_report/summary.json` (`NFR-06`) | merge absent, no coverpoint, or measured at an older `rtl_digest` | ok (91.67 %, `word_w` open) |
| 8 | `doc/measurements/NFR-01..04-*.md` | a file is missing, has no method or no date | not measurable |
| 9 | `doc/measurements/NFR-07-*.md` | absent (no synthesis lint flow, `G-05`) | not measurable |
| 10 | `A-09`: every FR `verified` | any FR is not `verified` | blocked (3/59) |
| 11 | work-package gate: every WP test has a recorded red run at an older `rtl_digest` | no red run, missing log, or the red run is at the current digest | ok (WP-0) |

The work-package gate runs checks 1-5, 7 and 11. Checks 6 and 8-10 are release evidence and are reported as `skipped` in a
WP. Check 7 runs in both modes on purpose: a WP that changes behaviour without re-measuring coverage has no
evidence that its new bins were exercised, and a coverage merge older than the current `rtl_digest` is reported as
stale.

Exit codes: `0` `signoff-ready`, `1` `blocked`, `2` the gate could not run. The gate is **blocked** on 2026-10-28
and must stay blocked: `G-03`, `G-04`, `G-05`, `G-08`, `G-10`, `G-11`, `G-13`, `G-14`, `G-23`, `G-24` and the four
`TBD` non-functional targets leave 57 of 59 requirements unverified. A gate that passes here is a broken gate.

Evidence is tied to code by digest, not by commit: `results.json` carries `rtl_digest` and `tb_digest` (sha256 over
the `.sv`/`.svh` content of `rtl/` and `tb/`), because the project forbids automatic commits. A `verified` row whose
test passed at a different digest is not evidence.

## Gaps

Two gaps changed meaning in v0.2: `G-01` and `G-02` now name `mtvec` and `mcause` as their targets, because
the trap vector and the trap cause moved from "unspecified" to "supplied by a CSR" (`D-08`), and `G-09` was
promoted from a doubt about the fetch handshake to the prerequisite for the instruction cache. Six rows are
new: `G-13` to `G-18`.

v0.7 adds `G-23` and `G-24` for the debug subsystem that `FR-53`..`FR-59` require and the RTL does not have.

The `Owner` and `Target` columns are the commitments of `A-09`, confirmed by the designer on 2026-10-28 under
`Q-12`: the designer owns the spec and ISA gaps, the verification lead owns the DV gaps, and every target is
2026-12-31. They are commitments, not proposals.

| ID | Gap | Impact | Owner | Target |
|---|---|---|---|---|
| G-01 | `trap_addr` is hardcoded to 1000 (`rtl/control.sv:255`); v0.2 sets the target as the `mtvec` CSR with direct and vectored modes (`FR-29`, `FR-30`) | traps always land at the same address, and the vector cannot be changed by software | designer | 2026-12-31 |
| G-02 | `scause` is tied to zero (`rtl/control.sv:265`); v0.2 sets the target as `mcause` per the ratified privileged specification (`FR-23`) | no trap cause reported, so a handler cannot tell a timer tick from an illegal instruction | designer | 2026-12-31 |
| G-03 | `cg_sum` covergroup is empty (`tb/env/top/riscv_small_coverage.sv`) | no functional coverage, so `NFR-06` cannot be measured; a **release blocker** since `Q-11` fixed the signoff bar (`A-09`) | verification lead | 2026-12-31 |
| G-04 | Reference model and scoreboard cover only LW/SW | other opcodes are not checked; the twenty as-built requirements outside `LW`/`SW` cannot become `verified`, so the `Q-11` bar ("every `FR` row `verified`") cannot be met — a **release blocker** | verification lead | 2026-12-31 |
| G-05 | No timing, area, or power measurement exists | `NFR-01` to `NFR-04` and `NFR-07` cannot be verified; no frequency or part is recorded (`A-08`, `Q-08`) | designer | 2026-12-31 |
| G-06 | Unimplemented encodings execute as no-operations: unknown opcodes and RV32M aliases fall through the decode default (`rtl/instruction_decode.sv:238-247`, `rtl/instruction_decode.sv:325`), `FENCE` is an empty case (`rtl/instruction_decode.sv:330-332`) and `ECALL`/`EBREAK`/CSR are an empty case (`rtl/instruction_decode.sv:333-335`) | no illegal-instruction trap; `FR-24`, `FR-25`, `FR-26` stay `deferred`; `M` and `C` cannot be claimed in phase 1. Since `Q-05` (2026-10-28) every unimplemented encoding must trap, so this is a conformance blocker, not a scope choice; `FR-24`, `FR-25`, `FR-43` and `FR-44` stay `deferred` for lack of the trap; the `FENCE` half is the separate phase-1 row `FR-26`, blocked only by the decoder (`Q-15` was answered on 2026-10-28) | designer | 2026-12-31 |
| G-07 | `JALR` does not clear bit 0 of the target address (`rtl/jump_decision.sv:111`) | non-conformant indirect jump for odd targets; a **release blocker** since `Q-06` (2026-10-28), decided by `FR-07`'s acceptance | designer | 2026-12-31 |
| G-08 | Sub-word **stores** always drive one lane whatever `data_addr[1:0]` says (`rtl/execution.sv:157-174`, `rtl/riscv_small.sv:193`). The load half is closed: `T-06` shows `LB`/`LBU`/`LH`/`LHU` selecting the addressed lane (`rtl/memory_access.sv:68-69`, `:91-105`) | `SB`/`SH` behaviour still depends on an unspecified memory model; a **release blocker** since `Q-06` (2026-10-28), now decided by `FR-11` alone | designer | 2026-12-31 |
| G-09 | No fetch stall exists: while the fetch grant is withheld only the IF/ID registers are flushed (`rtl/control.sv:241-243`) and the program counter keeps advancing unless IF/ID is held (`rtl/instruction_fetch.sv:84-103`) | reframed in v0.2: this is no longer a doubt about the memory contract (`A-03` is retired) but the **prerequisite for the instruction cache**, because a cache miss must be able to hold the program counter for many cycles; `FR-28` is the requirement that closes it | designer | 2026-12-31 |
| G-10 | The sanity-test flow emits `build/sanity_tests/<test>.hex` (`scripts/verify/sanity.cmake`, configure mode) but no testbench path consumes a hex image — there is no `$readmemh` anywhere under `tb/` | `NFR-05` (RISC-V suite conformance) cannot be measured, so the `rv32ui-p-*` leg of the `Q-11` bar cannot run — a **release blocker** | verification lead | 2026-12-31 |
| G-11 | `T-02` adds no stimulus: `riscv_small_corner_seq::body()` only calls `super.body()` (`tb/tests/sequence_lib/riscv_small_corner_seq.sv:31`), so it repeats `T-01` | no requirement can cite `T-02`; boundary values are untested, so the coverage leg of the `Q-11` bar rests on `T-01` alone — a **release blocker** | verification lead | 2026-12-31 |
| G-12 | The top-level `clk_en` reaches only the trap-state registers (`rtl/riscv_small.sv:223`), while stage enables are generated inside `rtl/control.sv`; the port is described as a global clock enable but does not gate the pipeline (`rtl/control.sv:262` is its only use) | `C-02` is a description of the port, not a promise; integrators cannot pause the core with `clk_en` | designer | 2026-12-31 |
| G-13 | No CSR file and no CSR instruction: `CSR*` is decoded as a no-operation (`rtl/instruction_decode.sv:333-335`) and the trap state registers are unreadable (`rtl/control.sv:257-268`) | `FR-23`, `FR-24`, `FR-25`, `FR-29`, `FR-30`, `FR-32`, `FR-37`, `FR-45` to `FR-47`, `FR-49` to `FR-52`, and `Zicsr`/`Zicntr` in `§7.1`, stay `deferred` | designer | 2026-12-31 |
| G-14 | No machine-mode interrupt subsystem: the only trap request is the level-sensitive `exception` input (`rtl/riscv_small.sv:44`), with no `mip`/`mie`, no timer, and no external controller interface | `FR-39`, `FR-40`, `FR-36`, `FR-48`, and the vectored mode of `FR-30`, stay `deferred`; `D-01`'s preemption cannot be demonstrated | designer | 2026-12-31 |
| G-15 | No instruction cache and no line-based fetch: `rtl/instruction_fetch.sv:63-77` drives one word address per cycle with no burst and no last-beat signal, and neither `ICACHE_BYTES` nor `ICACHE_LINE` exists | `FR-27`, `FR-28`, `FR-31`, `FR-34` stay `deferred`; §5.2 of the specification is a target, not a description of the RTL; `NFR-02`'s condition cannot be met | designer | 2026-12-31 |
| G-16 | No multi-hart support: the top is a single hart (`rtl/riscv_small.sv:38-58`) with no hart-identity input, no `NUM_HARTS`, no `A` encodings (`rtl/riscv_definitions_pkg.sv:129-187`) and no software interrupt | `FR-32`, `FR-33`, `FR-35`, `FR-36` stay `deferred`; the `MCU_SMP` configuration of §5.2 cannot be built | designer | 2026-12-31 |
| G-17 | No decision log: `doc/decisions.md` does not exist, so `D-01` to `D-11` live in `doc/spec.md` §0.1 | decisions are not indexed beside the requirements they justify, and a superseded decision has nowhere to be retired | designer | 2026-12-31 |
| G-18 | Stores do not wait for the data grant: the stall condition at `rtl/control.sv:246` also requires a load destination, so a store asserts its strobe for one cycle whatever `data_ready` does | `FR-38` stays `deferred`; the store contract is the testbench's, which grants every access immediately, so the difference is invisible today | designer | 2026-12-31 |
| G-19 | A load-use insertion clears `id_ex_clk_en`, which is also the register file's clock enable (`rtl/instruction_decode.sv:195`, `rtl/riscv_small.sv:142`, `rtl/reg_file.sv:99`), while `ma_wb_clk_en` stays high (`rtl/control.sv:122`, `:158`, `:195`, `:219`) | an instruction in WB during that cycle is not written and is then dropped from MA/WB, so its architectural write is lost; not observed by `T-01` because the sequence spaces instructions | designer | 2026-12-31 |
| G-20 | Branch and jump targets add `imm[20:0]` as an unsigned slice (`rtl/jump_decision.sv:111`) | negative offsets land at `base + (imm mod 2^21)`; backward `JAL`, `JALR` and `B<cond>` targets are wrong, while forward offsets within +2^20 work; `FR-06`..`FR-08` are implemented for forward offsets only | designer | 2026-12-31 |
| G-21 | Reset is asynchronous on both edges: every DUT module hardcodes `or negedge rst_n` (`rtl/instruction_fetch.sv:69`, `rtl/control.sv:257`) and there is no de-assertion synchroniser and no `ASYNC_RESET`-style macro selection. `D-09` and `FR-41` require async assertion with a synchronised release | the release edge is asynchronous, so a de-assertion that arrives close to a clock edge can release different registers on different edges; the FPGA synchronous-reset variant cannot be built at all | designer | 2026-12-31 |
| G-22 | No byte write strobes and no misaligned split: the data port is `data_addr`/`data_wr`/`data_rd_wr_ctrl`/two enables (`rtl/riscv_small.sv:51-57`), `data_wr` is always `rs2` (`:193`) and `data_addr` is `alu_ma` (`:119`) | a store cannot say which bytes are valid, and an access that crosses a word boundary (`SH` at an odd address, `SW` off-word) has no way to complete, so `A-05`'s EEI guarantee is not met; `FR-11`, `FR-12` and `FR-42` carry the fix | designer | 2026-12-31 |
| G-23 | No debug subsystem: the DUT has no debug port, no debug mode, no `dcsr`/`dpc`/`dscratch` and no abstract-command or program-buffer path (`rtl/riscv_small.sv:41-57`, `rtl/instruction_decode.sv:333-335`) | `FR-53` to `FR-56`, `FR-58` and `FR-59` stay `deferred`, and `T-05` cannot exist until a Debug Module model is built | designer | 2026-12-31 |
| G-24 | No trigger unit: `tselect`/`tdata1`..`tdata3`/`tinfo` are not decoded and no address or data comparator exists (`rtl/instruction_decode.sv:333-335`) | `FR-57` stays `deferred`; breakpoints and watchpoints cannot be observed in any configuration | designer | 2026-12-31 |

## Notes

- `T-01`, `T-02` and `T-06` are the tests in `scripts/verify/tests.tsv`; `T-03`, `T-04` and `T-05` are v0.7 targets
  with no implementation yet (`G-04`, `G-13`, `G-14`, `G-23`).
- `T-01`, `T-02` and `T-06` are green at `rtl_digest` `sha256:0418049b…` (2026-10-28): 31, 31 and 12 scoreboard
  comparisons. `T-02` still repeats `T-01` (`G-11`).
- Functional coverage now exists (`cg_mem` in `tb/env/top/riscv_small_coverage.sv`, sampled in the monitor):
  `cp_width`, `cp_lane`, `cp_dir` and `cp_subword_lane`. It merges at 91.67 % over `T-01`/`T-02`/`T-06`; the one
  uncovered bin is `cp_width.word_w`, because the width output is one bit wide in effect (see `FR-11`). Evidence:
  `build/cov_report/functionalCoverageReport/xcrg_func_cov_report.txt`.
- `T-06` was red first: at `rtl_digest` `sha256:34db4d37…` and `tb_digest` `sha256:47058a92…` it failed 8 of 12
  cases — `LB` and `LBU` at offsets 0, 1 and 2, and `LH`/`LHU` at offset 0 — while `LB`/`LBU` at offset 3 and
  `LH`/`LHU` at offset 2 passed. The old code extended `s_bytes[0]`, and `dataBus_u` declares its byte array as
  `[0:3]`, so index 0 holds bits `[31:24]`: the *highest* byte address always won, which is why the offset-3 cases
  were the ones that survived. That is a stronger red than "nothing works", because a broken harness would fail
  every case. Log: `build/regress/2026-10-28T20-09-36Z/T-06.log`.
- A requirement is `verified` only when a test above exercises it; everything else stays `implemented` or
  `deferred`.
- No test states which configuration of `doc/spec.md` §5.2 it ran in, because no configuration exists yet
  (`G-15`, `G-16`). When parameters land, every regression result must name its configuration (`C-11`).
