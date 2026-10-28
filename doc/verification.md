# Verification Status

Traceability and honest status. The specification states the requirement; this file states what proves it.

| Field | Value |
|---|---|
| Status | draft |
| Version | v0.2 |
| Baseline | commit `bb789bb` (tests unchanged since v0.1) |
| Implements | [spec.md](spec.md) |

## Tests

| ID | Test | Scope | Status |
|---|---|---|---|
| T-01 | `riscv_small_basic_load_store_test` | LW/SW through the pipeline | implemented |
| T-02 | `riscv_small_corner_test` | corner load/store addresses | implemented |

## Traceability

Filled after `doc/spec.md` exists. One row per requirement, with the evidence and the status.

| Requirement | Evidence | Status |
|---|---|---|
| | | |

## Gaps

Two gaps changed meaning in v0.2: `G-01` and `G-02` now name `mtvec` and `mcause` as their targets, because
the trap vector and the trap cause moved from "unspecified" to "supplied by a CSR" (`D-08`), and `G-09` was
promoted from a doubt about the fetch handshake to the prerequisite for the instruction cache. Six rows are
new: `G-13` to `G-18`.

The `Owner` and `Target` columns carry the proposed assignments of `A-09`, which the designer has not yet
confirmed (`Q-12`). Treat them as proposals, not commitments.

| ID | Gap | Impact | Owner | Target |
|---|---|---|---|---|
| G-01 | `trap_addr` is hardcoded to 1000 (`rtl/control.sv:255`); v0.2 sets the target as the `mtvec` CSR with direct and vectored modes (`FR-29`, `FR-30`) | traps always land at the same address, and the vector cannot be changed by software | designer (proposed) | 2026-12-31 |
| G-02 | `scause` is tied to zero (`rtl/control.sv:265`); v0.2 sets the target as `mcause` per the ratified privileged specification (`FR-23`) | no trap cause reported, so a handler cannot tell a timer tick from an illegal instruction | designer (proposed) | 2026-12-31 |
| G-03 | `cg_sum` covergroup is empty (`tb/env/top/riscv_small_coverage.sv`) | no functional coverage; `NFR-06` has no target until `A-09` is confirmed | verification lead (proposed) | 2026-12-31 |
| G-04 | Reference model and scoreboard cover only LW/SW | other opcodes are not checked; the twenty as-built requirements outside `LW`/`SW` cannot become `verified` | verification lead (proposed) | 2026-12-31 |
| G-05 | No timing, area, or power measurement exists | `NFR-01` to `NFR-04` and `NFR-07` cannot be verified; no frequency or part is recorded (`A-08`, `Q-08`) | designer (proposed) | 2026-12-31 |
| G-06 | Unimplemented encodings execute as no-operations: unknown opcodes and RV32M aliases fall through the decode default (`rtl/instruction_decode.sv:228-230`, `rtl/instruction_decode.sv:325`), `FENCE` is an empty case (`rtl/instruction_decode.sv:330-332`) and `ECALL`/`EBREAK`/CSR are an empty case (`rtl/instruction_decode.sv:333-335`) | no illegal-instruction trap; `FR-24`, `FR-25`, `FR-26` stay `deferred`; `M` and `C` cannot be claimed in phase 1 | designer (proposed) | 2026-12-31 |
| G-07 | `JALR` does not clear bit 0 of the target address (`rtl/jump_decision.sv:111`) | non-conformant indirect jump for odd targets | designer (proposed) | 2026-12-31 |
| G-08 | Sub-word loads always extend the lowest lane and sub-word stores always drive the lowest lane; address bits [1:0] are never used to select a lane (`rtl/memory_access.sv:80-102`, `rtl/execution.sv:157-174`) | `SB`/`SH`/`LB`/`LH` behaviour depends on an unspecified memory model; `FR-11`/`FR-12` describe observed, not intended, behaviour | designer (proposed) | 2026-12-31 |
| G-09 | No fetch stall exists: while the fetch grant is withheld only the IF/ID registers are flushed (`rtl/control.sv:241-243`) and the program counter keeps advancing unless IF/ID is held (`rtl/instruction_fetch.sv:84-103`) | reframed in v0.2: this is no longer a doubt about the memory contract (`A-03` is retired) but the **prerequisite for the instruction cache**, because a cache miss must be able to hold the program counter for many cycles; `FR-28` is the requirement that closes it | designer (proposed) | 2026-12-31 |
| G-10 | The sanity-test flow emits `build/sanity_tests/<test>.hex` (`scripts/compile_sanity_tests.cmake:13`) but no testbench path consumes a hex image — there is no `$readmemh` anywhere under `tb/` | `NFR-05` (RISC-V suite conformance) cannot be measured | verification lead (proposed) | 2026-12-31 |
| G-11 | `T-02` adds no stimulus: `riscv_small_corner_seq::body()` only calls `super.body()` (`tb/tests/sequence_lib/riscv_small_corner_seq.sv:31`), so it repeats `T-01` | no requirement can cite `T-02`; boundary values are untested | verification lead (proposed) | 2026-12-31 |
| G-12 | The top-level `clk_en` reaches only the trap-state registers (`rtl/riscv_small.sv:223`), while stage enables are generated inside `rtl/control.sv`; the port is described as a global clock enable but does not gate the pipeline (`rtl/control.sv:262` is its only use) | `C-02` is a description of the port, not a promise; integrators cannot pause the core with `clk_en` | designer (proposed) | 2026-12-31 |
| G-13 | No CSR file and no CSR instruction: `CSR*` is decoded as a no-operation (`rtl/instruction_decode.sv:333-335`) and the trap state registers are unreadable (`rtl/control.sv:257-268`) | `FR-23`, `FR-24`, `FR-25`, `FR-29`, `FR-30`, `FR-32`, `FR-37`, and `Zicsr`/`Zicntr` in `§7.1`, stay `deferred` | designer (proposed) | 2026-12-31 |
| G-14 | No machine-mode interrupt subsystem: the only trap request is the level-sensitive `exception` input (`rtl/riscv_small.sv:44`), with no `mip`/`mie`, no timer, and no external controller interface | `FR-39`, `FR-40`, `FR-36`, and the vectored mode of `FR-30`, stay `deferred`; `D-01`'s preemption cannot be demonstrated | designer (proposed) | 2026-12-31 |
| G-15 | No instruction cache and no line-based fetch: `rtl/instruction_fetch.sv:63-77` drives one word address per cycle with no burst and no last-beat signal, and neither `ICACHE_BYTES` nor `ICACHE_LINE` exists | `FR-27`, `FR-28`, `FR-31`, `FR-34` stay `deferred`; §5.2 of the specification is a target, not a description of the RTL; `NFR-02`'s condition cannot be met | designer (proposed) | 2026-12-31 |
| G-16 | No multi-hart support: the top is a single hart (`rtl/riscv_small.sv:38-58`) with no hart-identity input, no `NUM_HARTS`, no `A` encodings (`rtl/riscv_definitions_pkg.sv:129-187`) and no software interrupt | `FR-32`, `FR-33`, `FR-35`, `FR-36` stay `deferred`; the `MCU_SMP` configuration of §5.2 cannot be built | designer (proposed) | 2026-12-31 |
| G-17 | No decision log: `doc/decisions.md` does not exist, so `D-01` to `D-08` live in `doc/spec.md` §0.1 | decisions are not indexed beside the requirements they justify, and a superseded decision has nowhere to be retired | designer (proposed) | 2026-12-31 |
| G-18 | Stores do not wait for the data grant: the stall condition at `rtl/control.sv:246` also requires a load destination, so a store asserts its strobe for one cycle whatever `data_ready` does | `FR-38` stays `deferred`; the store contract is the testbench's, which grants every access immediately, so the difference is invisible today | designer (proposed) | 2026-12-31 |
| G-19 | A load-use insertion clears `id_ex_clk_en`, which is also the register file's clock enable (`rtl/instruction_decode.sv:195`, `rtl/riscv_small.sv:142`, `rtl/reg_file.sv:99`), while `ma_wb_clk_en` stays high (`rtl/control.sv:122`, `:158`, `:195`, `:219`) | an instruction in WB during that cycle is not written and is then dropped from MA/WB, so its architectural write is lost; not observed by `T-01` because the sequence spaces instructions | designer (proposed) | 2026-12-31 |
| G-20 | Branch and jump targets add `imm[20:0]` as an unsigned slice (`rtl/jump_decision.sv:111`) | negative offsets land at `base + (imm mod 2^21)`; backward `JAL`, `JALR` and `B<cond>` targets are wrong, while forward offsets within +2^20 work; `FR-06`..`FR-08` are implemented for forward offsets only | designer (proposed) | 2026-12-31 |

## Notes

- `T-01` and `T-02` are the only tests registered under `tb/tests/`.
- A requirement is `verified` only when a test above exercises it; everything else stays `implemented` or
  `deferred`.
- No test states which configuration of `doc/spec.md` §5.2 it ran in, because no configuration exists yet
  (`G-15`, `G-16`). When parameters land, every regression result must name its configuration (`C-11`).
