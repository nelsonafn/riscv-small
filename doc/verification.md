# Verification Status

Traceability and honest status. The specification states the requirement; this file states what proves it.

| Field | Value |
|---|---|
| Status | draft |
| Version | v0.5 |
| Baseline | `doc/spec.md` v0.5 (RISC-V ISA v20260120); `rtl/` unchanged since `bb789bb`, no test added since v0.1 |
| Implements | [spec.md](spec.md) |

## Tests

| ID | Test | Scope | Status |
|---|---|---|---|
| T-01 | `riscv_small_basic_load_store_test` | LW/SW through the pipeline | implemented |
| T-02 | `riscv_small_corner_test` | corner load/store addresses | implemented |

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

| Requirement | Evidence | Status |
|---|---|---|
| FR-01 R-type ALU ops | `rtl/instruction_decode.sv:323-329`, `rtl/alu.sv:52-92`; no test (`G-04`) | implemented |
| FR-02 immediate ALU ops | `rtl/instruction_decode.sv:309-322`, `rtl/instruction_decode.sv:209-213`, `rtl/riscv_definitions_pkg.sv:276-282`; no test (`G-04`) | implemented |
| FR-03 shift-immediate ops | `rtl/instruction_decode.sv:312-318`, `rtl/alu.sv:56-81`; no test (`G-04`) | implemented |
| FR-04 LUI upper immediate | `rtl/instruction_decode.sv:248-253`, `rtl/instruction_decode.sv:221-223`; no test (`G-04`) | implemented |
| FR-05 AUIPC PC-relative | `rtl/instruction_decode.sv:254-260`, `rtl/alu.sv:53-55`; no test (`G-04`) | implemented |
| FR-06 JAL link and target | `rtl/instruction_decode.sv:261-268`, `rtl/jump_decision.sv:98-112`, `rtl/instruction_fetch.sv:88-101`; no test (`G-04`); backward offsets wrong (`G-20`) | partial |
| FR-07 JALR indirect target | `rtl/instruction_decode.sv:270-277`, `rtl/jump_decision.sv:103-111`; no test (`G-04`); bit 0 not cleared (`G-07`), backward offsets wrong (`G-20`) | partial |
| FR-08 six conditional branches | `rtl/instruction_decode.sv:279-282`, `rtl/jump_decision.sv:117-164`; no test (`G-04`); backward offsets wrong (`G-20`) | partial |
| FR-09 LW load word | `rtl/instruction_decode.sv:283-296`, `rtl/memory_access.sv:88-90`; `T-01`, `tb/env/top/riscv_small_scoreboard.sv:78-79` | verified |
| FR-10 SW store word | `rtl/instruction_decode.sv:297-308`, `rtl/execution.sv:89-108`, `rtl/riscv_small.sv:193-196`; `T-01`, `tb/env/top/riscv_small_scoreboard.sv:78-79` | verified |
| FR-11 SB and SH lane select | `rtl/instruction_decode.sv:297-308`, `rtl/riscv_small.sv:118`, `rtl/execution.sv:157-174`; the data port drives the lowest lane only, never `data_addr[1:0]` (`G-08`, release blocker), and has no byte strobes (`G-22`); no test (`G-04`) | partial |
| FR-12 LB LH LBU LHU extend | `rtl/memory_access.sv:80-102` reads `data.s_bytes[0]`/`s_half[0]`, so the addressed lane is never selected (`G-08`, release blocker); no test (`G-04`) | partial |
| FR-13 effective data address | `rtl/instruction_decode.sv:209-232`, `rtl/execution.sv:113-152`, `rtl/riscv_small.sv:119`; no test (`G-04`) | implemented |
| FR-14 x0 reads zero | `rtl/reg_file.sv:64-89`, `rtl/reg_file.sv:100-103`; no test (`G-04`) | implemented |
| FR-15 write-read same cycle | `rtl/reg_file.sv:71-73`, `rtl/reg_file.sv:83-85`; no test (`G-04`) | implemented |
| FR-16 arithmetic forwarding | `rtl/control.sv:184-227`, `rtl/execution.sv:113-152`; no test (`G-04`) | implemented |
| FR-17 load result to consumer | `rtl/control.sv:115-140`, `rtl/control.sv:184-227`; no test (`G-04`); write-back lost on the load-use freeze (`G-19`) | partial |
| FR-18 store data forwarding | `rtl/execution.sv:157-174`, `rtl/control.sv:205-227`; no test (`G-04`) | implemented |
| FR-19 branch operand forwarding | `rtl/instruction_decode.sv:134-173`, `rtl/control.sv:108-177`; no test (`G-04`) | implemented |
| FR-20 one fetch address per cycle | `rtl/control.sv:101`, `rtl/instruction_fetch.sv:63-77`; no test (`G-04`) | implemented |
| FR-21 load waits for data_ready | `rtl/control.sv:246-251`; no test (`G-04`) | implemented |
| FR-22 exception discards fetch | `rtl/control.sv:234-238`, `rtl/control.sv:255`, `rtl/instruction_fetch.sv:95-97`; no test (`G-04`); vector hardcoded to 1000 (`G-01`) | partial |
| FR-23 mepc and mcause | `rtl/control.sv:257-268`; trap state unreadable, no CSR port; no test (`G-01`, `G-02`, `G-13`) | deferred |
| FR-24 illegal-instruction trap | `rtl/instruction_decode.sv:238-247`, `rtl/instruction_decode.sv:325`; decode falls through to no-write; no test (`G-06`, `G-13`) | deferred |
| FR-25 ECALL and EBREAK trap | `rtl/instruction_decode.sv:333-335`; decoded as no-operation; no test (`G-06`, `G-13`) | deferred |
| FR-26 FENCE ordering | `rtl/instruction_decode.sv:330-332`; decoded as no-operation; no test (`G-06`) | deferred |
| FR-27 cache-line fetch burst | `rtl/instruction_fetch.sv:63-77`; one word address per cycle, no last-beat signal; no test (`G-15`) | deferred |
| FR-28 hold outstanding fetch | `rtl/control.sv:241-243`, `rtl/instruction_fetch.sv:84-103`; PC advances with the grant withheld; no test (`G-09`, `G-15`) | deferred |
| FR-29 mtvec direct mode | `rtl/control.sv:255`, `rtl/instruction_decode.sv:333-335`; constant vector, no CSR write; no test (`G-01`, `G-13`) | deferred |
| FR-30 mtvec vectored mode | `rtl/control.sv:255`; constant vector, no mode field; no test (`G-01`, `G-14`) | deferred |
| FR-31 fence.i invalidates cache | `rtl/instruction_decode.sv:330-335`; no-operation, no cache; no test (`G-06`, `G-15`) | deferred |
| FR-32 mhartid report | `rtl/riscv_small.sv:41-57`; no CSR and no hart-identity input; no test (`G-13`, `G-16`) | deferred |
| FR-33 per-hart behaviour | `rtl/riscv_small.sv:38-58`; single hart, no hart-count parameter; no test (`G-16`) | deferred |
| FR-34 configuration invariance | `rtl/riscv_small.sv:38-58`; no configuration parameters; no test (`G-15`, `G-16`) | deferred |
| FR-35 Zaamo and Zalrsc | `rtl/riscv_definitions_pkg.sv:129-187`, `rtl/instruction_decode.sv:323-329`; no A encodings; no test (`G-16`) | deferred |
| FR-36 machine software interrupt | `rtl/riscv_small.sv:44`; only the level-sensitive exception input; no test (`G-14`, `G-16`) | deferred |
| FR-37 misa advertises extensions | `rtl/instruction_decode.sv:333-335`; no CSR file; no test (`G-13`, `G-16`) | deferred |
| FR-38 store waits for grant | `rtl/control.sv:246`; stall also requires a load destination; no test (`G-18`) | deferred |
| FR-39 machine timer interrupt | `rtl/riscv_small.sv:44`; no interrupt input and no timer; no test (`G-14`) | deferred |
| FR-40 machine external interrupt | `rtl/riscv_small.sv:44`; no external interrupt path; no test (`G-14`) | deferred |
| FR-41 reset behaviour | `rtl/instruction_fetch.sv:69` and `rtl/control.sv:257` hardcode `or negedge rst_n`; there is no de-assertion synchroniser and no reset-style macro in `rtl/` (`G-21`); no test (`G-04`) | partial |
| FR-42 misaligned split | `rtl/riscv_small.sv:119` issues one access per instruction from `alu_ma`; there is no second beat, no address increment and no strobe recomputation (`G-22`); no test (`G-04`) | deferred |

## Gaps

Two gaps changed meaning in v0.2: `G-01` and `G-02` now name `mtvec` and `mcause` as their targets, because
the trap vector and the trap cause moved from "unspecified" to "supplied by a CSR" (`D-08`), and `G-09` was
promoted from a doubt about the fetch handshake to the prerequisite for the instruction cache. Six rows are
new: `G-13` to `G-18`.

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
| G-06 | Unimplemented encodings execute as no-operations: unknown opcodes and RV32M aliases fall through the decode default (`rtl/instruction_decode.sv:238-247`, `rtl/instruction_decode.sv:325`), `FENCE` is an empty case (`rtl/instruction_decode.sv:330-332`) and `ECALL`/`EBREAK`/CSR are an empty case (`rtl/instruction_decode.sv:333-335`) | no illegal-instruction trap; `FR-24`, `FR-25`, `FR-26` stay `deferred`; `M` and `C` cannot be claimed in phase 1. Since `Q-05` (2026-10-28) every unimplemented encoding must trap, so this is a conformance blocker, not a scope choice; `FR-24` and `FR-25` stay `deferred` for lack of the trap; the `FENCE` half is the separate phase-1 row `FR-26`, blocked only by the decoder (`Q-15` was answered on 2026-10-28) | designer | 2026-12-31 |
| G-07 | `JALR` does not clear bit 0 of the target address (`rtl/jump_decision.sv:111`) | non-conformant indirect jump for odd targets; a **release blocker** since `Q-06` (2026-10-28), decided by `FR-07`'s acceptance | designer | 2026-12-31 |
| G-08 | Sub-word loads always extend the lowest lane and sub-word stores always drive the lowest lane; address bits [1:0] are never used to select a lane (`rtl/memory_access.sv:80-102`, `rtl/execution.sv:157-174`) | `SB`/`SH`/`LB`/`LH` behaviour depends on an unspecified memory model; a **release blocker** since `Q-06` (2026-10-28), decided by the acceptance of `FR-11` and `FR-12` | designer | 2026-12-31 |
| G-09 | No fetch stall exists: while the fetch grant is withheld only the IF/ID registers are flushed (`rtl/control.sv:241-243`) and the program counter keeps advancing unless IF/ID is held (`rtl/instruction_fetch.sv:84-103`) | reframed in v0.2: this is no longer a doubt about the memory contract (`A-03` is retired) but the **prerequisite for the instruction cache**, because a cache miss must be able to hold the program counter for many cycles; `FR-28` is the requirement that closes it | designer | 2026-12-31 |
| G-10 | The sanity-test flow emits `build/sanity_tests/<test>.hex` (`scripts/compile_sanity_tests.cmake:13-14`) but no testbench path consumes a hex image — there is no `$readmemh` anywhere under `tb/` | `NFR-05` (RISC-V suite conformance) cannot be measured, so the `rv32ui-p-*` leg of the `Q-11` bar cannot run — a **release blocker** | verification lead | 2026-12-31 |
| G-11 | `T-02` adds no stimulus: `riscv_small_corner_seq::body()` only calls `super.body()` (`tb/tests/sequence_lib/riscv_small_corner_seq.sv:31`), so it repeats `T-01` | no requirement can cite `T-02`; boundary values are untested, so the coverage leg of the `Q-11` bar rests on `T-01` alone — a **release blocker** | verification lead | 2026-12-31 |
| G-12 | The top-level `clk_en` reaches only the trap-state registers (`rtl/riscv_small.sv:223`), while stage enables are generated inside `rtl/control.sv`; the port is described as a global clock enable but does not gate the pipeline (`rtl/control.sv:262` is its only use) | `C-02` is a description of the port, not a promise; integrators cannot pause the core with `clk_en` | designer | 2026-12-31 |
| G-13 | No CSR file and no CSR instruction: `CSR*` is decoded as a no-operation (`rtl/instruction_decode.sv:333-335`) and the trap state registers are unreadable (`rtl/control.sv:257-268`) | `FR-23`, `FR-24`, `FR-25`, `FR-29`, `FR-30`, `FR-32`, `FR-37`, and `Zicsr`/`Zicntr` in `§7.1`, stay `deferred` | designer | 2026-12-31 |
| G-14 | No machine-mode interrupt subsystem: the only trap request is the level-sensitive `exception` input (`rtl/riscv_small.sv:44`), with no `mip`/`mie`, no timer, and no external controller interface | `FR-39`, `FR-40`, `FR-36`, and the vectored mode of `FR-30`, stay `deferred`; `D-01`'s preemption cannot be demonstrated | designer | 2026-12-31 |
| G-15 | No instruction cache and no line-based fetch: `rtl/instruction_fetch.sv:63-77` drives one word address per cycle with no burst and no last-beat signal, and neither `ICACHE_BYTES` nor `ICACHE_LINE` exists | `FR-27`, `FR-28`, `FR-31`, `FR-34` stay `deferred`; §5.2 of the specification is a target, not a description of the RTL; `NFR-02`'s condition cannot be met | designer | 2026-12-31 |
| G-16 | No multi-hart support: the top is a single hart (`rtl/riscv_small.sv:38-58`) with no hart-identity input, no `NUM_HARTS`, no `A` encodings (`rtl/riscv_definitions_pkg.sv:129-187`) and no software interrupt | `FR-32`, `FR-33`, `FR-35`, `FR-36` stay `deferred`; the `MCU_SMP` configuration of §5.2 cannot be built | designer | 2026-12-31 |
| G-17 | No decision log: `doc/decisions.md` does not exist, so `D-01` to `D-09` live in `doc/spec.md` §0.1 | decisions are not indexed beside the requirements they justify, and a superseded decision has nowhere to be retired | designer | 2026-12-31 |
| G-18 | Stores do not wait for the data grant: the stall condition at `rtl/control.sv:246` also requires a load destination, so a store asserts its strobe for one cycle whatever `data_ready` does | `FR-38` stays `deferred`; the store contract is the testbench's, which grants every access immediately, so the difference is invisible today | designer | 2026-12-31 |
| G-19 | A load-use insertion clears `id_ex_clk_en`, which is also the register file's clock enable (`rtl/instruction_decode.sv:195`, `rtl/riscv_small.sv:142`, `rtl/reg_file.sv:99`), while `ma_wb_clk_en` stays high (`rtl/control.sv:122`, `:158`, `:195`, `:219`) | an instruction in WB during that cycle is not written and is then dropped from MA/WB, so its architectural write is lost; not observed by `T-01` because the sequence spaces instructions | designer | 2026-12-31 |
| G-20 | Branch and jump targets add `imm[20:0]` as an unsigned slice (`rtl/jump_decision.sv:111`) | negative offsets land at `base + (imm mod 2^21)`; backward `JAL`, `JALR` and `B<cond>` targets are wrong, while forward offsets within +2^20 work; `FR-06`..`FR-08` are implemented for forward offsets only | designer | 2026-12-31 |
| G-21 | Reset is asynchronous on both edges: every DUT module hardcodes `or negedge rst_n` (`rtl/instruction_fetch.sv:69`, `rtl/control.sv:257`) and there is no de-assertion synchroniser and no `ASYNC_RESET`-style macro selection. `D-09` and `FR-41` require async assertion with a synchronised release | the release edge is asynchronous, so a de-assertion that arrives close to a clock edge can release different registers on different edges; the FPGA synchronous-reset variant cannot be built at all | designer | 2026-12-31 |
| G-22 | No byte write strobes and no misaligned split: the data port is `data_addr`/`data_wr`/`data_rd_wr_ctrl`/two enables (`rtl/riscv_small.sv:51-57`), `data_wr` is always `rs2` (`:193`) and `data_addr` is `alu_ma` (`:119`) | a store cannot say which bytes are valid, and an access that crosses a word boundary (`SH` at an odd address, `SW` off-word) has no way to complete, so `A-05`'s EEI guarantee is not met; `FR-11`, `FR-12` and `FR-42` carry the fix | designer | 2026-12-31 |

## Notes

- `T-01` and `T-02` are the only tests registered under `tb/tests/`.
- A requirement is `verified` only when a test above exercises it; everything else stays `implemented` or
  `deferred`.
- No test states which configuration of `doc/spec.md` §5.2 it ran in, because no configuration exists yet
  (`G-15`, `G-16`). When parameters land, every regression result must name its configuration (`C-11`).
