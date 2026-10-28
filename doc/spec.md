# riscv-small Core Specification

| Field | Value |
|---|---|
| Status | draft |
| Version | v0.2.1 |
| Owner | TBD(designer, 2026-12-31) — see `Q-12` |
| Last reviewed | never — designer review requested |
| Baseline | commit `bb789bb` (v0.1, as-built); v0.2 adds intent only, no RTL change |
| Source | elicitation + reconstruction |

> **Provenance.** Two kinds of row live in this document, and the status tells them apart.
> Rows marked `implemented` or `verified` are **reverse-engineered** from `rtl/` and `tb/`; they cite
> `file:line` and record today's behaviour, not anyone's intent. Rows marked `deferred`, the decision table
> in §0.1, and the target ISA table in §7.1 come from the **2026-10-28 elicitation round**; they record the
> target, not the RTL. Where the two disagree, the difference is a gap (`G-xx`), never an edit to either
> side. Nothing becomes `implemented` in this revision: no RTL changed.

## Change log

| Date | Version | Change | Author | Reviewer |
|---|---|---|---|---|
| 2026-10-27 | v0.1 | First draft, **reverse-engineered** from `rtl/`, `tb/`, and `README.md`; no designer interview held; `Q-01..Q-12` raised for designer review | spec-author (reconstruction) | none yet — designer review requested |
| 2026-10-28 | v0.2 | Product intent recorded from the first elicitation round. Adds the MCU-plus-RTOS goal and SMP-ready target (`D-01`..`D-08`), a target ISA table with a phase per extension (§7.1), a synthesis configuration section (`NUM_HARTS`, `ENABLE_A`, `ICACHE_BYTES`, `ICACHE_LINE`; `C-06`..`C-11`), and `FR-27`..`FR-40`. Retires `A-03` (zero-latency fetch) in favour of a line-fill contract (`FR-27`, `FR-28`) and reframes `G-09` as a prerequisite for the I-cache. Adds `A-08`..`A-16` and `Q-13`..`Q-19`; all `TBD` owner dates moved to 2026-12-31. No RTL, testbench, or `doc/uarch.md` change; no row promoted to `implemented` or `verified` | spec-author (elicitation) | designer — pending |
| 2026-10-28 | v0.2.1 | Microarchitecture review: adds `G-19`/`G-20` notes to §4 and §9, closes `Q-19` as bookkeeping, adds `Q-20` (MVP atomics). No requirement text changed | docs-coordinator | designer — pending |

## 0. Interview log

Evidence that the requirements came from someone, not only from the code.

| Round | Date | Participants | Questions | Artifacts |
|---|---|---|---|---|
| reconstruction | 2026-10-27 | none — no designer available | none asked; 12 raised for later | `rtl/riscv_small.sv`, `rtl/instruction_fetch.sv`, `rtl/instruction_decode.sv`, `rtl/execution.sv`, `rtl/memory_access.sv`, `rtl/control.sv`, `rtl/alu.sv`, `rtl/jump_decision.sv`, `rtl/reg_file.sv`, `rtl/riscv_definitions_pkg.sv`, `tb/tests/*.sv`, `tb/tests/sequence_lib/*.sv`, `tb/env/ref_model/*`, `tb/env/top/riscv_small_coverage.sv`, `tb/env/agents/riscv_small_agent/riscv_small_driver.sv`, `README.md`; `F-01`..`F-08`, `FR-01`..`FR-26`, `NFR-01`..`NFR-07`, `C-01`..`C-05`, `A-01`..`A-07`, `Q-01`..`Q-12` |
| 1 | 2026-10-28 | designer; spec-author (answers relayed by `docs-coordinator`) | eight items put, six answered. **1** RTOS mode is a software build choice, so the hardware must support preemption. **2** 2 kB direct-mapped I-cache by default, configurable, no D-cache, `fence.i` flushes it. **3** Instruction fetch fills per line (burst), replacing the per-word contract. **4** `NUM_HARTS` in the main configuration package, default 1; `mhartid` is an input. **6** A data transfer completes on the grant at the clock edge, no write-response channel, must stay compatible with a future D-cache or TCDM. **7** Trap vector is the `mtvec` CSR, no vector input port. Items **5** and **8** were not answered: 5 was `fmax`/part (`Q-08`) and 8 the signoff bar (`Q-11`, `Q-12`); `Q-19` closed as bookkeeping | §0.1 `D-01`..`D-08`; §0.2; `FR-27`..`FR-40`; `C-06`..`C-11`; `A-08`..`A-16` |

Mode: **elicitation** for everything v0.2 adds, **reconstruction** for the as-built rows inherited from v0.1
(those cite `file:line`). The elicitation evidence is the designer's answers as relayed by the coordinator;
the RTL was not re-read to confirm intent, only to state what exists.

### 0.1 Decisions (2026-10-28)

A decision is a choice with a reason; it is not a requirement. Where a decision can be observed, the
requirement it produces is named. These rows live here because `doc/decisions.md` does not exist yet
(`G-17`); they move there unchanged when it does.

| ID | Decision | Reason | Requirements it produces | Status |
|---|---|---|---|---|
| D-01 | The product goal is an MCU that runs a simple RTOS; the RTOS mode (preemptive, cooperative, or hybrid) is a software build choice, so the hardware shall support preemption. | the customer wants one core, several software models | `FR-39`, `FR-40` (timer and external interrupt); `FR-36` (phase 2 IPI) | confirmed |
| D-02 | SMP is a later milestone, and the ISA and the interfaces shall not preclude it. | avoid a second tape-out for the same product | `FR-33`, `FR-34`, `FR-35` | confirmed |
| D-03 | `NUM_HARTS` ∈ {1, 2, 4} is a synthesis parameter in the main configuration package; the core stays hart-agnostic; the hart identifier is an input, not a parameter; default 1. | one RTL, three products; identity cannot be a compile-time constant if the SoC wires harts differently | `C-06`, `FR-32`, `FR-33` | confirmed |
| D-04 | A 2 kB direct-mapped instruction cache is the default, configurable; there is no data cache in any phase; `fence.i` flushes the I-cache. | instruction fetch stalls dominate an MCU running from flash; a D-cache would force coherence in SMP | `C-08`, `FR-31` | confirmed |
| D-05 | A compiled binary is valid only for the configuration it was built for; ISA differences between variants are not binary-portable. | keeps `NUM_HARTS` and `ENABLE_A` free instead of freezing one ABI | `C-11` — proposed, tracked as `A-12` (`Q-16`) | proposed |
| D-06 | `A` (Zaamo + Zalrsc) enters the target ISA in phase 2 and is not advertised in `misa` before it is implemented. | atomics are needed only when harts can race | `C-07`, `FR-35`, `FR-37` | confirmed |
| D-07 | `M` and `C` are fixed on and are not parameters. | every target toolchain emits them; a build without them saves nothing | `C-10`, §7.1 | confirmed |
| D-08 | The normative source is the latest **ratified** RISC-V specification; drafts are advisory only, so `mtvec`/`mepc`/`mcause`/`mstatus`/`mie`/`mip` follow the ratified privileged spec and neither RVM23 nor CLIC is adopted. | a draft can change under a validated product | `FR-29`, `FR-30`, `FR-37`; `A-14` | confirmed |

### 0.2 Answers recorded, with their classification

| # | Answer (paraphrased back to the designer) | Classified as | Recorded in |
|---|---|---|---|
| 1 | The hardware must support preemption, but preemptive, cooperative, and hybrid are software build choices rather than synthesis choices. | decision `D-01`; requirements `FR-39`, `FR-40` | §0.1, §4 |
| 2 | The MVP ships a 2 kB direct-mapped instruction cache, sized by a parameter, with no data cache, invalidated by `fence.i`. | decision `D-04`; constraints `C-08`, `C-09`; requirement `FR-31` | §0.1, §5.1, §5.2, §4 |
| 3 | A fetch fills a whole line as one burst, so the per-word `inst_ready` contract is replaced. | requirement `FR-27`; assumption `A-10` (burst shape) | §4, §9 |
| 4 | The hart count is a parameter with default 1, held in the main configuration package, while the hart identifier arrives as an input. | decision `D-03`; constraint `C-06`; requirements `FR-32`, `FR-33` | §0.1, §5.1, §5.2, §4 |
| 6 | A load or a store completes on the data memory's grant at the clock edge, with no write-response channel, and the contract must survive a later D-cache or TCDM. | requirement `FR-38`; assumption `A-01` (load half confirmed) | §4, §9 |
| 7 | A trap vector comes from the `mtvec` CSR; there is no vector input port. | decision `D-08`; requirements `FR-29`, `FR-30` | §0.1, §4 |
| 5 | Item 5 was the `fmax` and target-part question, and item 8 the signoff bar. Neither was answered; they stay `Q-08`, `Q-11` and `Q-12`, and `Q-19` closes as bookkeeping. | no new artifact | `Q-08`, `Q-11`, `Q-12` |

## 1. Purpose and scope

This document specifies the externally observable behaviour of the `riscv_small` core, and the behaviour its
product intends. The product is a 32-bit RISC-V MCU core that runs a simple RTOS: an RTOS mode is a software
build choice, and the hardware obligation is that a preemption source exists and that a trap can be taken and
returned from (`D-01`). Multi-hart execution is a later milestone that the instruction set and the memory
interfaces must not preclude (`D-02`).

The document therefore has two layers. The **as-built** layer (v0.1, reconstructed) states which instructions
the core executes today, how it interacts with external instruction and data memories, how it resolves data
hazards, and what it does on a trap. The **target** layer (v0.2, elicited) states the extension set with a
phase per extension (§7.1), the synthesis configuration (§5.2), and the requirements that follow from them,
each with its phase in the status or the row text.

In scope: the decoded instruction subset; address generation for loads, stores, branches and jumps; the
instruction-fill and data-grant contracts; the register-file contract; forwarding and stall obligations on
software; trap entry and return; machine-mode CSRs as far as they are required by the rows above; and the
non-functional targets that are currently unmeasured.

Out of scope (non-goals), so that scope is not re-argued:

- Supervisor and user mode, an MMU, floating point, vector, and hypervisor extensions. Not targeted; §7.1
  records them as absent with no claim.
- A data cache and any cache-coherence protocol, in every phase (`D-04`, `A-15`).
- Debug, trace, and JTAG. No requirement is made.
- The choice of interrupt controller (CLINT plus PLIC versus CLIC) and the boot protocol of secondary harts.
  Those are SoC concerns, recorded as `Q-17` and `Q-18`; the core-level obligation is only that a timer, an
  external, and (phase 2) a software interrupt be taken as traps (`FR-39`, `FR-40`, `FR-36`).
- Timing, area, power, and verification signoff. No measurement exists (`G-05`).

The as-built rows of v0.1 remain the description of today's RTL. Where an as-built row conflicts with a
target row, the as-built row keeps its status and the difference is a `G-xx`: v0.2 adds intent, it does not
upgrade capability.

## 2. Stakeholders and concerns

| Stakeholder | Concern | Addressed by |
|---|---|---|
| RTL designer | confirm or correct reconstructed behaviour; close `Q-01`..`Q-20`; own the ISA and spec gaps | §4, §5, §9 |
| Verification engineer | what to test, what is already covered, and which configuration is under test | acceptance column, §5, §5.2, `G-03`, `G-04` |
| SoC integrator | memory handshake, clock and reset, trap vector source, hart identity, interrupt wiring | §5.2, §6, `A-01`, `A-16`, `G-14`, `G-18` |
| RTOS and application developer | preemption and its latency, CSR visibility, cache behaviour around self-modifying code | `FR-29`..`FR-31`, `FR-39`, `FR-40` |
| Compiler and toolchain owner | the exact ISA subset, alignment, `x0`, which extensions may be assumed | §4.1, §7, §7.1, `A-02`, `A-05`, `A-12` |
| Reviewer and auditor | traceability and honest status | §8, [verification.md](verification.md) |

## 3. Features

| ID | Feature | Notes |
|---|---|---|
| F-01 | Integer arithmetic and logic execution | the decoded subset is enumerated in §4.1, not the full RV32I |
| F-02 | Control transfer: six conditional branches, `JAL`, `JALR` | taken branches and jumps redirect the fetch stream; the redirect penalty is unmeasured (`G-05`) |
| F-03 | Word and sub-word load and store through an external data port | width is driven out of the core; sub-word lane handling is `G-08`; the grant contract is `FR-38` |
| F-04 | Instruction fetch through an external instruction port | as built: one word per cycle (`FR-20`); target: a line fill (`FR-27`, `FR-28`, `G-15`) |
| F-05 | Hazard-free single-issue execution | forwarding plus automatic stalls; software needs no inserted NOPs (`FR-15`..`FR-19`) |
| F-06 | Architectural register file with hardwired `x0` | `A-02`; post-reset contents are unspecified (`A-04`) |
| F-07 | One clock domain, a global clock enable, asynchronous active-low reset | `C-01`, `C-02` |
| F-08 | Trap entry and return | as built: fixed vector, no cause, no software access (`G-01`, `G-02`); target: `mtvec` direct and vectored entry (`FR-29`, `FR-30`) |
| F-09 | Machine-mode privileged architecture: CSR file, trap CSRs, counters | phase 1 target; absent today (`G-13`) |
| F-10 | Instruction cache with line fills, invalidated by `fence.i` | phase 1 target; absent today (`G-15`) |
| F-11 | Configurable hart count with atomics and inter-processor interrupts | phase 2 target; absent today (`G-16`) |

## 4. Functional requirements

Read the `Evidence` column as "where this behaviour is visible in the RTL today". Status is `implemented`
when the RTL exists, `verified` only where `T-01`/`T-02` observe it, and `deferred` for capability that is
absent. A row whose Status says `deferred` and whose text names phase 2 is a commitment to the SMP milestone,
not to the MVP.

| ID | Requirement (shall) | Evidence (source) | Acceptance | Traces to | Status |
|---|---|---|---|---|---|
| FR-01 | The core shall execute the register-register integer instructions `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND`, with `SUB` and `SRA` selected by bit 5 of the register-form function field. | `rtl/instruction_decode.sv:323-329`, `rtl/alu.sv:52-92` | A directed test per encoding writes a known `rs1`/`rs2` pair and reads `rd` back through a store; any mismatch against the architectural model fails. No such test exists (`G-04`). | `F-01`, `BLK-ID`, `BLK-ALU` | implemented |
| FR-02 | The core shall execute the immediate integer instructions `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI` with the 12-bit immediate sign-extended. | `rtl/instruction_decode.sv:309-322`, `rtl/instruction_decode.sv:209-213` | Directed test per encoding, including negative immediates, compared against the model (`G-04`). | `F-01`, `BLK-ID`, `BLK-ALU` | implemented |
| FR-03 | The core shall execute `SLLI`, `SRLI` and `SRAI`, taking the shift amount from the low five bits of the immediate and choosing logical or arithmetic from the high function bit. | `rtl/instruction_decode.sv:312-318`, `rtl/alu.sv:56-81` | Shift by 0, 1, 31 and the logical/arithmetic pair compared against the model (`G-04`). | `F-01`, `BLK-ALU` | implemented |
| FR-04 | `LUI` shall write the upper 20 immediate bits shifted left by 12 into `rd`. | `rtl/instruction_decode.sv:248-253`, `rtl/instruction_decode.sv:221-223` | `rd` value read back for immediates `0x00000` and `0xFFFFF` (`G-04`). | `F-01`, `BLK-ID` | implemented |
| FR-05 | `AUIPC` shall write the address of the instruction plus the upper 20 immediate bits shifted left by 12 into `rd`. | `rtl/instruction_decode.sv:254-260` | `rd` value read back at two different program addresses (`G-04`); depends on `G-09`. | `F-01`, `BLK-ID` | implemented |
| FR-06 | `JAL` shall write the address of the next instruction into `rd` and continue at the current address plus the sign-extended jump offset. | `rtl/instruction_decode.sv:261-268`, `rtl/jump_decision.sv:98-112`, `rtl/instruction_fetch.sv:88-101` | Forward and backward jump with `rd != x0`, checking both the link value and the landed address (`G-04`). | `F-02`, `BLK-JMP`, `BLK-IF` | implemented |
| FR-07 | `JALR` shall write the address of the next instruction into `rd` and continue at `rs1` plus the sign-extended 12-bit offset. | `rtl/instruction_decode.sv:270-277`, `rtl/jump_decision.sv:103-111` | Indirect jump through an address built by a preceding `LUI`/`ADDI`, checking the landed address (`G-04`). The RV32I requirement to clear bit 0 of the target is **not** implemented (`G-07`). | `F-02`, `BLK-JMP` | implemented |
| FR-08 | The core shall decide `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` from the source values, continuing at the branch target when the condition holds and at the next instruction otherwise. | `rtl/instruction_decode.sv:279-282`, `rtl/jump_decision.sv:117-164` | Taken and not-taken case for each of the six conditions, with one signed and one unsigned boundary pair each (`G-04`). | `F-02`, `BLK-JMP` | implemented |
| FR-09 | `LW` shall read the 32-bit word at the effective address and write it into `rd`. | `rtl/instruction_decode.sv:283-296`, `rtl/memory_access.sv:88-90` | `T-01`: 31 random loads whose values are then stored; the stored data is compared against the reference model; verified by `T-01`. | `F-03`, `BLK-MA` | verified |
| FR-10 | `SW` shall write the value of `rs2` to the 32-bit word at the effective address and assert the write strobe for that access. | `rtl/instruction_decode.sv:297-308`, `rtl/execution.sv:193-196` | `T-01`: 31 random stores; address and data are compared against the reference model; verified by `T-01`. | `F-03`, `BLK-MA` | verified |
| FR-11 | `SB` and `SH` shall write the low byte or low halfword of `rs2` and report the access width (byte or halfword) on the width output. | `rtl/instruction_decode.sv:303-307`, `rtl/riscv_small.sv:118`, `rtl/execution.sv:157-174` | Store of two distinct bytes and two distinct halfwords to one word address, read back with full-word loads (`G-08`, `G-04`). | `F-03`, `BLK-MA` | implemented |
| FR-12 | `LB`, `LH`, `LBU` and `LHU` shall extend the low byte or low halfword of the returned word, sign-extending for `LB`/`LH` and zero-extending for `LBU`/`LHU`. | `rtl/memory_access.sv:80-102` | Load of `0x80`, `0xFF80` and `0x8000` patterns through each of the four encodings, checked for the expected signed or unsigned value (`G-08`, `G-04`). | `F-03`, `BLK-MA` | implemented |
| FR-13 | The core shall form the effective data address of a load or store as `rs1` plus the sign-extended offset and present it as a byte address. | `rtl/instruction_decode.sv:209-232`, `rtl/execution.sv:113-152`, `rtl/riscv_small.sv:119` | Addresses with a non-zero base register and offsets of `-2048` and `+2047` observed on the data address port (`G-04`). | `F-03`, `BLK-EX` | implemented |
| FR-14 | Architectural register `x0` shall read as zero and shall discard every write. | `rtl/reg_file.sv:64-89`, `rtl/reg_file.sv:100-103` | Write a non-zero value to `x0` and read it back as zero; read `x0` as a load base and observe address 0 (`G-04`, `A-02`). | `F-06`, `BLK-REG` | implemented |
| FR-15 | A read of a register that is being written in the same cycle shall return the value being written. | `rtl/reg_file.sv:71-73`, `rtl/reg_file.sv:83-85` | Back-to-back producer/consumer pair with no intervening instruction, compared against the model (`G-04`). | `F-05`, `BLK-REG` | implemented |
| FR-16 | A consumer of an arithmetic result produced one or two instructions earlier shall observe that result without software-inserted NOPs. | `rtl/control.sv:184-227`, `rtl/execution.sv:113-152` | Producer/consumer distance of 1 and 2 for both source operands, compared against the model (`G-04`). | `F-05`, `BLK-CTL`, `BLK-EX` | implemented |
| FR-17 | A consumer of a load result shall observe the loaded value, with the wait required by the load absorbed by the core. | `rtl/control.sv:115-140`, `rtl/control.sv:184-227` | Load followed immediately by an ALU consumer, and load followed immediately by a conditional branch, both compared against the model (`G-04`). | `F-05`, `BLK-CTL` | implemented |
| FR-18 | Store data shall be sourced from `rs2`, including when `rs2` is produced by the immediately preceding instruction. | `rtl/execution.sv:157-174`, `rtl/control.sv:205-227` | Producer of distance 1 and 2 followed by a store of that register, address and data compared against the model (`G-04`). | `F-05`, `BLK-EX`, `BLK-CTL` | implemented |
| FR-19 | Conditional-branch operands shall be sourced from the newest available value of `rs1` and `rs2`, including values produced by instructions still in flight. | `rtl/instruction_decode.sv:134-173`, `rtl/control.sv:108-177` | Branch where each operand is produced 0, 1 and 2 instructions earlier, decided as the model predicts (`G-04`). | `F-02`, `F-05`, `BLK-JMP`, `BLK-CTL` | implemented |
| FR-20 | The core shall present one instruction address per cycle while it is running and assert the fetch request in the same cycle. | `rtl/control.sv:101`, `rtl/instruction_fetch.sv:63-77` | The fetch address and the request are observed cycle by cycle for a straight-line program, advancing by four bytes per running cycle (`G-09`). Superseded for the target by `FR-27` and `FR-28`; kept because it describes today's RTL. | `F-04`, `BLK-IF` | implemented |
| FR-21 | The core shall treat a load as complete only when the data memory reports the data ready. | `rtl/control.sv:246-251` | A memory model that grants one cycle late and one that grants immediately both give identical architectural results (`A-01`, `G-09`). A store is not covered by this row: see `FR-38` and `G-18`. | `F-03`, `BLK-CTL` | implemented |
| FR-22 | On an asserted `exception` input the core shall discard the fetched and decoded instructions and continue at the trap vector. | `rtl/control.sv:234-238`, `rtl/control.sv:255`, `rtl/instruction_fetch.sv:95-97` | Assert `exception` for one cycle between two known instructions; the next fetched address is the trap vector and no register write from a discarded instruction is observed. An instruction already past decode still completes (`G-01`). | `F-08`, `BLK-CTL`, `BLK-IF` | implemented |
| FR-23 | The core shall report the interrupted instruction address and a trap cause to software in `mepc` and `mcause`. | `rtl/control.sv:257-268` | A CSR read returns the interrupted address and the ratified cause code after a trap. The registers exist but are unreadable, because no CSR instruction is decoded and no CSR port exists (`G-01`, `G-02`, `G-13`). | `F-08`, `F-09`, `BLK-CTL` | deferred |
| FR-24 | An instruction whose encoding is not implemented shall raise an illegal-instruction trap. | `rtl/instruction_decode.sv:228-230` falls to a no-write default; `rtl/instruction_decode.sv:325` ignores all function bits but bit 5 | An unimplemented encoding, and a multiply encoding, both raise a trap (`G-06`, `G-13`). | `F-01`, `F-09`, `BLK-ID` | deferred |
| FR-25 | `ECALL` and `EBREAK` shall raise a trap. | `rtl/instruction_decode.sv:333-335` | `ECALL` transfers control to the `mtvec` entry (`G-06`, `G-13`). | `F-01`, `F-09`, `BLK-ID` | deferred |
| FR-26 | `FENCE` shall order memory accesses as the ratified ISA requires. | `rtl/instruction_decode.sv:330-332` | `FENCE` between a store and a dependent load preserves program order at the data port. An implementation that adds no work shall be acceptable only if it is justified in writing by the single-outstanding, blocking data interface (`A-13`); until that justification exists the row stays `deferred` (`G-06`). | `F-01`, `BLK-ID`, `BLK-CTL` | deferred |
| FR-27 | The core shall request instruction memory in whole cache lines and accept the line as a variable-length burst that ends on a last-beat indication. | there is no burst as built: `rtl/instruction_fetch.sv:63-77` drives one word address per cycle and no last-beat signal exists (`G-15`) | With a memory model that returns a line in four beats, the core issues one request per line instead of one per word; with eight beats the same line is accepted; the next request follows at the line base plus the line size. Burst shape is `A-10`, phase 1. | `F-04`, `F-10`, `BLK-IF`, `G-15` | deferred |
| FR-28 | The core shall keep the address of an outstanding fetch stable and shall not consume an instruction it has not received. | `rtl/control.sv:241-243` flushes only IF/ID while the fetch grant is withheld (`inst_ready` low), and `rtl/instruction_fetch.sv:84-103` advances the program counter regardless (`G-09`) | Hold the fetch grant low for three cycles inside a straight-line program: the address accepted next is the one that was held, the instruction at every address is consumed exactly once, and a PC-relative result (`AUIPC`, `JAL`, branch) lands where the model says. Phase 1. | `F-04`, `F-10`, `BLK-IF`, `BLK-CTL`, `G-09`, `G-15` | deferred |
| FR-29 | On a trap the core shall enter the handler at the address held in `mtvec` with the mode field clear (direct mode). | `rtl/control.sv:255` assigns a constant address; no CSR file and no CSR instruction exist (`rtl/instruction_decode.sv:333-335`) (`G-01`, `G-13`) | Write `mtvec` with `0x8000_0100` and with `0x0000_0040`, assert `exception` for one cycle each time; the next fetch address equals the value written, exactly. Phase 1. | `F-08`, `F-09`, `BLK-CTL`, `BLK-IF`, `G-01`, `G-13` | deferred |
| FR-30 | When `mtvec` selects vectored mode, the core shall enter an interrupt handler at the base plus four times the interrupt cause, while an exception still enters at the base. | absent: the vector is a constant and there is no mode field (`rtl/control.sv:255`, `G-01`, `G-14`) | With `mtvec` = base with mode 1, a machine timer interrupt enters at base + 28 and a machine external interrupt at base + 44; an illegal-instruction exception enters at the base. Phase 1. | `F-08`, `F-09`, `BLK-CTL`, `BLK-IF`, `G-01`, `G-13`, `G-14` | deferred |
| FR-31 | Executing `fence.i` shall make stores that precede it visible to instruction fetches that follow it, by invalidating the instruction cache. | `rtl/instruction_decode.sv:330-335` decodes `fence`, `fence.i` and the system opcodes as no-operations, and no cache exists (`G-06`, `G-15`) | Store a new instruction word over an address that has already been executed, execute `fence.i`, then jump to that address: the new instruction executes. Without `fence.i` the stale line may execute, so the row is observed as a difference between the two runs. Phase 1. | `F-10`, `BLK-IF`, `BLK-ID`, `D-04`, `G-15` | deferred |
| FR-32 | The core shall report the value presented on its hart-identity input when software reads `mhartid`. | no CSR file and no hart-identity input in the port list (`rtl/riscv_small.sv:41-57`) (`G-13`, `G-16`) | Drive the input with 0, 1 and 3: `mhartid` reads back the driven value each time and no other instruction result changes. Phase 2. | `F-09`, `F-11`, `C-06`, `G-16` | deferred |
| FR-33 | The core shall produce identical per-hart architectural behaviour for every legal `NUM_HARTS`, with harts interacting only through the memory interface. | the top is a single hart with no hart-count parameter and no cross-hart state (`rtl/riscv_small.sv:38-58`) (`G-16`) | The same program, each hart given a private data region, retires the same per-hart instruction trace for `NUM_HARTS` = 1, 2 and 4. Phase 2. | `F-11`, `C-06`, `G-16` | deferred |
| FR-34 | The same program shall produce the same architectural results in every named configuration of §5.2. | no configuration parameters exist (`G-15`, `G-16`); `M` and `C` are absent (`G-06`) | One assembly program that avoids timing-dependent and hart-count-dependent behaviour, built once per variant (`A-12`) and run in `MCU_MIN`, `MCU_RTOS` and `MCU_SMP`, retires the same architectural result. Phase 1 for the cache dimension, phase 2 for the hart dimension. | `F-10`, `F-11`, `C-06`, `C-08`, `G-15` | deferred |
| FR-35 | The core shall implement `Zaamo` and `Zalrsc` so that load-reserved/store-conditional pairs and atomic memory operations are atomic with respect to other harts. | no `A` encodings exist (`rtl/riscv_definitions_pkg.sv:129-187`) and the register-form decoder ignores the function field above bit 5 (`rtl/instruction_decode.sv:323-329`) (`G-16`) | Two harts each add N times to one shared counter with load-reserved/store-conditional: the result is 2N and every failed store-conditional reports failure. An `AMOADD` pair by two harts likewise loses no update. Phase 2. | `F-11`, `C-07`, `D-06`, `G-16` | deferred |
| FR-36 | The core shall take a machine software interrupt as a trap, so that one hart can interrupt another. | only the level-sensitive `exception` input exists (`rtl/riscv_small.sv:44`) (`G-14`, `G-16`) | With machine software interrupts enabled, a request raised by another hart enters the handler with the machine-software cause and returns to the interrupted instruction. Phase 2. | `F-11`, `D-01`, `D-02`, `G-14`, `G-16` | deferred |
| FR-37 | The `misa` register shall advertise exactly the extensions implemented in the current configuration and shall read zero for every extension that is not. | no CSR exists, so nothing is advertised (`G-13`, `G-16`) | With `ENABLE_A` = 0 the `A` bit reads zero; with `ENABLE_A` = 1 it reads one; every set bit corresponds to a row of §7.1 whose status is not `absent`. Phase 2 for the `A` bit, phase 1 for the rest. | `F-09`, `C-07`, `C-10`, `D-06`, `G-13` | deferred |
| FR-38 | A store shall complete only in a cycle in which the data memory grants it, and the core shall require no separate write response. | `rtl/control.sv:246` stalls only when the write-back path selects memory, so a store drives its strobe for one cycle regardless of the data grant (`G-18`) | A data memory that withholds the grant for two cycles still receives exactly one store, with the same address and data, and no further access address appears until it is granted; no write-response channel is observed. Phase 1. | `F-03`, `BLK-MA`, `BLK-CTL`, `G-18` | deferred |
| FR-39 | The core shall take a machine timer interrupt as a trap whose cause identifies it. | no interrupt input, no `mip`/`mie`, no timer (`rtl/riscv_small.sv:44`) (`G-14`) | With the timer interrupt enabled, raise it: the handler is entered with the machine-timer cause and `mret` returns to the interrupted instruction. Phase 1. | `F-09`, `D-01`, `G-14` | deferred |
| FR-40 | The core shall take a machine external interrupt as a trap whose cause identifies it. | no interrupt input and no external interrupt path (`rtl/riscv_small.sv:44`) (`G-14`) | With the external interrupt enabled, raise it: the handler is entered with the machine-external cause and `mret` returns to the interrupted instruction. Phase 1. | `F-09`, `D-01`, `G-14` | deferred |

Notes on the rows above:

- `FR-22` is reconstruction of an existing mechanism, not a claim that the vector or the cause is correct:
  the vector is a constant (`G-01`) and the cause register is tied low (`G-02`). Its target successor is
  `FR-29`, and `FR-22` stays until the CSR path replaces the constant.
- `FR-09` and `FR-10` are the only rows a test observes. `T-01` checks stores directly; the load result is
  checked only through the value that is subsequently stored, which is why `FR-09` and not only `FR-10` can
  be marked `verified`.
- Every other as-built row is `implemented` unless its Status column says `deferred`; nothing in the
  repository observes those rows, and `G-04` explains why the existing scoreboard cannot.
- `FR-20` and `FR-21` describe today's per-word fetch and load-only stall. They are not withdrawn, because
  the RTL still does this; the target rows `FR-27`, `FR-28` and `FR-38` supersede them for the product, and
  `A-03` is retired.
- `FR-26` is the row the elicitation round promoted from "unspecified" to a phase-1 obligation with ratified
  semantics; it did not need a new ID, so it keeps `FR-26` and changes text and acceptance only.
- Rows `FR-27`..`FR-40` were written after the 2026-10-28 round. They are `deferred` because no RTL exists,
  not because the intent is doubtful: each names the phase in its acceptance text.
- `FR-06`..`FR-08` are `implemented` for forward offsets only. `G-20` records that the target adds an unsigned
  `imm[20:0]`, so backward branches and jumps are wrong; `G-19` records a write-back that a load-use freeze can
  suppress.

### 4.1 Decoded instruction subset (as built)

This table is what `rtl/instruction_decode.sv` actually decodes today. It is **not** the target ISA of §7.1
and it is not what `README.md` claims.

| Opcode (binary) | Mnemonic | Accepted `funct3` | Function-field handling | Decode site |
|---|---|---|---|---|
| `0110111` | `LUI` | undefined | upper immediate only | `rtl/instruction_decode.sv:248-253` |
| `0010111` | `AUIPC` | undefined | upper immediate only | `rtl/instruction_decode.sv:254-260` |
| `1101111` | `JAL` | undefined | jump immediate | `rtl/instruction_decode.sv:261-268` |
| `1100111` | `JALR` | not checked — every `funct3` is accepted | I-type immediate | `rtl/instruction_decode.sv:270-277` |
| `1100011` | `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` | `000`, `001`, `100`, `101`, `110`, `111` | `010` and `011` fall to the not-taken default | `rtl/instruction_decode.sv:279-282`, `rtl/jump_decision.sv:117-164` |
| `0000011` | `LB`, `LH`, `LW`, `LBU`, `LHU` | `000`, `001`, `010`, `100`, `101` | `011`, `110`, `111` fall to the full-word default | `rtl/instruction_decode.sv:283-296`, `rtl/memory_access.sv:80-102` |
| `0100011` | `SB`, `SH`, `SW` | `000`, `001`, `010` | width driven out as the low two bits of `funct3` (`00` byte, `01` halfword, `10` word) | `rtl/instruction_decode.sv:297-308`, `rtl/riscv_small.sv:118` |
| `0010011` | `ADDI`, `SLLI`, `SLTI`, `SLTIU`, `XORI`, `SRLI`, `SRAI`, `ORI`, `ANDI` | `000`, `001`, `010`, `011`, `100`, `101`, `110`, `111` | shift amount and arithmetic/logical choice from the immediate's high bits | `rtl/instruction_decode.sv:309-322` |
| `0110011` | `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND` | `000`..`111` | only bit 5 of the register function field is examined | `rtl/instruction_decode.sv:323-329` |
| `0001111` | `FENCE` (and `FENCE.I`, aliased) | — | decoded as no operation | `rtl/instruction_decode.sv:330-332` |
| `1110011` | `ECALL`, `EBREAK`, `CSR*` | — | decoded as no operation | `rtl/instruction_decode.sv:333-335` |

Absent entirely from the decoder: RV32M (`funct7 = 0000001` shares opcode `0110011` and therefore
**aliases onto the base ALU operations**), RV32A, RV32C, RV32F/D, `Zicsr`, `Zifencei`, and every supervisor or
hypervisor encoding (`G-06`). `M` and `C` are nevertheless part of the target ISA in phase 1 (`D-07`), which
is why the gap, not the decoder, is the open item.

## 5. Non-functional requirements

No timing, area, power, or coverage number exists anywhere in the repository. Rows that need one carry
`TBD` and a gap; the rows whose target is countable (a pass/fail bar) state it and name the gap that blocks
it. The dates are the date by which the owner must supply a number, not a target value. v0.2 moved every
`TBD` date to 2026-12-31, the deadline agreed in the 2026-10-28 round; no number was invented.

| ID | Requirement (shall) | Target | Condition | Method | Traces to | Status |
|---|---|---|---|---|---|---|
| NFR-01 | The core shall meet its clock-frequency target in the chosen implementation flow. | TBD(designer, 2026-12-31) — target part and frequency are unspecified (`A-08`, `Q-08`) | worst-case slow corner, target part, for each named configuration of §5.2 | post-implementation static timing report, worst negative slack over all paths | `G-05` | deferred |
| NFR-02 | The core shall meet its throughput target on a named benchmark kernel. | TBD(designer, 2026-12-31) | kernel and memory latency model fixed, instruction cache enabled | cycles retired over cycles spent, counted in simulation | `G-05` | deferred |
| NFR-03 | The core shall meet its area target on the target part. | TBD(designer, 2026-12-31) | default synthesis settings, target part, cache included and excluded | post-synthesis resource or gate-count report | `G-05` | deferred |
| NFR-04 | The core shall meet its power target. | TBD(designer, 2026-12-31) | activity from a named simulation vector | post-implementation vector-based power analysis | `G-05` | deferred |
| NFR-05 | The core shall pass every applicable `rv32ui-p-*` test of the bundled RISC-V test suite. | 0 failures over the applicable subset | Vivado XSim, images generated by the sanity-test flow; the applicable subset is fixed by §7.1 phase 1 and by the signoff bar (`A-09`, `Q-11`) | compile each test image, simulate it, record pass or fail per test | `G-04`, `G-10` | deferred |
| NFR-06 | Functional coverage shall close on the instruction set and memory behaviour it claims. | one bin per decoded instruction of §4.1 plus one per extension of §7.1 phase 1, and one bin per data width (`A-09`, `Q-11`) | covergroup populated and sampled by the regression | coverage report from `xcrg` or IMC, with uncovered bins enumerated | `G-03` | deferred |
| NFR-07 | The core shall synthesise with no inferred latches and no combinational loops. | 0 latches, 0 loops | default synthesis settings, target part, every named configuration | synthesis and lint report | `G-05` | deferred |

## 5.1 Constraints

| ID | Constraint | Origin | Impact |
|---|---|---|---|
| C-01 | One clock domain; reset is asynchronous and active-low; the core has no internal reset synchroniser. | `rtl/riscv_small.sv:41-43`, `rtl/instruction_fetch.sv:84-87` | reset de-assertion must be synchronised by the integrator (`A-06`) |
| C-02 | A top-level clock-enable input exists, but in the current RTL it reaches only the trap-state registers; the pipeline is not gated by it. | `rtl/riscv_small.sv:223`, `rtl/control.sv:262` | pausing `clk_en` does not pause the core (`G-12`) |
| C-03 | Instruction and data memories are external ports; no cache and no memory are instantiated inside the core today. | `rtl/riscv_small.sv:45-57` | memory latency and behaviour are the integrator's contract (`A-01`, `A-10`); the target adds an instruction cache inside the core (`D-04`, `C-08`) |
| C-04 | Simulation and elaboration are Vivado XSim 2024.1 or newer, driven by CMake and `make`. | `README.md`, `CMakeLists.txt` | no other simulator is targeted or checked |
| C-05 | The default DUT top is `riscv_small` and the default verification top is `riscv_small_tb`. | `srclist/riscv_small.srclist`, `CMakeLists.txt` | port names and widths are fixed by these files |
| C-06 | `NUM_HARTS` shall be a synthesis parameter of the main configuration package with legal values 1, 2 and 4 and default 1; the hart identifier shall be an input, not a parameter. | `D-03` | one RTL serves one, two or four harts (`FR-33`); the SoC must wire each instance's identity; elaboration fails on any other value |
| C-07 | `ENABLE_A` shall gate the `A` extension, default 0 in phase 1, and elaboration shall fail when `NUM_HARTS > 1` and `ENABLE_A = 0`. | `D-03`, `D-06` | an SMP build cannot be produced without atomics; `misa` follows the parameter (`FR-37`) |
| C-08 | `ICACHE_BYTES` shall select the instruction cache size from 0, 1024, 2048 and 4096 bytes, default 2048; the value 0 shall remove the cache; elaboration shall fail when `ICACHE_BYTES > 0` and `Zifencei` is not enabled. | `D-04` | a cache that software cannot invalidate is not buildable (`FR-31`); `ICACHE_BYTES = 0` is the flash-resident build |
| C-09 | `ICACHE_LINE` shall be 32 bytes (8 words) in phase 1 and shall not be independently tunable. | `D-04`, `A-11` | the fill burst length follows from the line size (`FR-27`); a different line size is a new variant, not a knob |
| C-10 | `M` and `C` shall always be enabled and shall not be parameters. | `D-07` | every toolchain target emits them; `misa` reports them on unconditionally (`FR-37`) |
| C-11 | A compiled binary shall be valid only for the configuration it was built for; nothing is binary-portable across `NUM_HARTS`, `ENABLE_A` or `ICACHE_BYTES`. | `D-05`, `A-12` | releases are named per variant; a test run must state the configuration it exercised |

## 5.2 Configuration

The parameters below are the whole configuration surface of the product. Every legal combination is formed
from these four; the three names after the table are the ones this specification uses elsewhere. A
configuration is chosen at synthesis and is not discoverable at run time except through `misa` (`FR-37`).

| Parameter | Legal values | Default | Effect on behaviour | Constraint |
|---|---|---|---|---|
| `NUM_HARTS` | 1, 2, 4 | 1 | number of harts the design instantiates; each hart sees the same core and a distinct identifier | `C-06`, `FR-33` |
| `ENABLE_A` | 0, 1 | 0 | the `A` extension (Zaamo and Zalrsc) is present and advertised only when 1 | `C-07`, `FR-35`, `FR-37` |
| `ICACHE_BYTES` | 0, 1024, 2048, 4096 | 2048 | instruction cache capacity; 0 removes the cache, so no fetch can hit | `C-08`, `FR-27`, `FR-31` |
| `ICACHE_LINE` | 32 | 32 | cache-line size in bytes, hence the fill burst length | `C-09`, `FR-27` |

| Named configuration | `NUM_HARTS` | `ENABLE_A` | `ICACHE_BYTES` | Product it serves |
|---|---|---|---|---|
| `MCU_MIN` | 1 | 0 | 0 | smallest area, code executed in place from fast memory, no cache |
| `MCU_RTOS` | 1 | 0 | 2048 | the MVP: a preemptive RTOS on one hart (`D-01`, `D-04`) |
| `MCU_SMP` | 4 | 1 | 2048 | the SMP milestone (`D-02`); `NUM_HARTS` = 2 is the same configuration with fewer harts |

Elaboration shall reject an illegal configuration rather than silently substitute a default:

| Check | Fails elaboration when | Source |
|---|---|---|
| hart count | `NUM_HARTS` is not 1, 2 or 4 | `C-06` |
| atomics with multiple harts | `NUM_HARTS > 1` and `ENABLE_A = 0` | `C-07` |
| cache without invalidation | `ICACHE_BYTES > 0` and `Zifencei` is not enabled | `C-08` |
| line size | `ICACHE_LINE` is not 32 | `C-09` |

None of these checks exists in the RTL today: there is no configuration package, no cache, and no `A`
(`G-13`, `G-15`, `G-16`). The table is the target of the parameters, and §7.1 says which phase each one lands in.

One detail is deliberately left out of the table because nobody has decided it: whether a cache-less build
(`ICACHE_BYTES` = 0) keeps the same line-based instruction interface or falls back to single-word fetches.
It changes the integrator's memory model, so it is part of `Q-13` rather than a default in this document.

## 6. Interfaces (summary)

One row per external interface, with the contract this specification promises; the interface catalogue is in
`doc/uarch.md` section 4.1 and the full port table in section 4.4. The `Status` column separates the contract as built from the contract the product
intends, because a reader of a specification should not have to guess which one is being described.

| Interface | Direction | Summary (target) | Contract | Status |
|---|---|---|---|---|
| Instruction memory | master | line address, burst request and accept, beat data, beat valid, last-beat | a whole cache line is fetched per request and the burst ends on last-beat (`FR-27`); an outstanding fetch is never lost and its address stays stable (`FR-28`) | target: line fill; as built it is one word per cycle with a per-word ready (`FR-20`, `G-15`) |
| Data memory | master | address, write data, byte strobes, 2-bit width, read data, grant | a load or a store completes on the grant at the clock edge; there is no write-response channel (`FR-21`, `FR-38`); the contract must survive a later D-cache or TCDM | loads as built; the store grant is absent (`G-18`) |
| Hart identity | input | hart identifier value | `mhartid` reads the input (`FR-32`); no other result depends on it | absent (`G-16`) |
| Interrupt requests | input | machine timer and machine external interrupt requests | each is taken as a trap with its own cause (`FR-39`, `FR-40`); phase 2 adds a machine software request (`FR-36`) | absent; the level-sensitive `exception` input is the only request today (`rtl/riscv_small.sv:44`) |
| Trap vector | — | none — the vector is software state | `mtvec` supplies the entry address, direct or vectored (`FR-29`, `FR-30`) | no port by decision (`D-08`); today the address is a constant inside the core (`G-01`) |
| Control | input | `clk`, `clk_en`, `rst_n`, `exception` | one clock domain, asynchronous active-low reset, no internal reset synchroniser (`C-01`) | as built (`C-02`, `G-12`) |

The detailed handshake semantics of the instruction port are not yet specified beyond `FR-27` and `FR-28`;
`A-10` records the proposed burst shape and `Q-13` asks for it to be confirmed.

## 7. Compliance and ISA scope

Two columns, because the v0.1 rows were written when only one answer existed. "As built" is what the RTL
does; "target" is what §7.1 commits to and by when.

| Item | As built | Target | Evidence |
|---|---|---|---|
| RV32I arithmetic, logic, shift, upper-immediate, jump, branch, load, store | partial — exactly the subset in §4.1 | complete in phase 1 | `rtl/instruction_decode.sv:247-336`, `G-06` |
| RV32I `FENCE` | no — executes as a no-operation | ordering in phase 1 (`FR-26`) | `G-06`, `A-13` |
| RV32I `ECALL` / `EBREAK` | no — executes as a no-operation | trap in phase 1 (`FR-25`) | `G-06`, `G-13` |
| RV32I illegal-instruction exception | no — unimplemented encodings execute as no-operations | trap in phase 1 (`FR-24`) | `G-06`, `G-13` |
| RV32I misaligned-access exception | no — addresses are passed to the memory unchecked | unchanged, no requirement (`A-05`) | `G-08` |
| `M` (multiply and divide) | no — encodings alias onto base ALU operations | fixed on in phase 1 (`D-07`) | `rtl/riscv_definitions_pkg.sv:129-187`, `G-06` |
| `C` (compressed) | no | fixed on in phase 1 (`D-07`) | absent from the decoder, `G-06` |
| `Zicsr` and machine-mode CSRs | no — no CSR instruction is decoded and no CSR port exists | phase 1 (`FR-23`, `FR-29`, `FR-32`, `FR-37`) | `G-13` |
| `Zifencei` | no | phase 1 (`FR-31`) | `G-06`, `G-15` |
| `Zicntr` (`cycle`, `time`, `instret`) | no | phase 1 | `G-13` |
| Machine trap entry | partial — fixed vector, no cause, no software-visible state | phase 1, `mtvec` direct and vectored (`FR-29`, `FR-30`) | `G-01`, `G-02`, `G-13` |
| Machine timer and external interrupts | no | phase 1 (`FR-39`, `FR-40`) | `G-14` |
| `A` (Zaamo + Zalrsc) | no | phase 2 (`FR-35`, `D-06`) | `G-16` |
| Machine software interrupt (IPI) | no | phase 2 (`FR-36`) | `G-14`, `G-16` |
| `mhartid` and more than one hart | no | phase 2 (`FR-32`, `FR-33`) | `G-16` |
| `F`, `D`, `V`, supervisor and user mode, MMU, debug, trace | no | not targeted | absent; §1 non-goals |

### 7.1 Target ISA and phases

Phase 1 is the MVP: one hart running a preemptive RTOS (`D-01`). Phase 2 is the SMP milestone (`D-02`). A
row's phase is a commitment to a milestone, not a promise that it exists: the last column states today's
status with the v0.1 evidence, and a row cannot move to `implemented` in this document until the RTL shows it.
The normative reference for every row is the latest **ratified** specification (`D-08`); RVM23 and CLIC are
drafts and are advisory only. Nothing is advertised in `misa` before it is implemented (`FR-37`).

| Extension | Why | Phase | Status today |
|---|---|---|---|
| `I` (RV32I base) | the instruction set the toolchain targets | 1 | partial: the subset of §4.1, with `G-06` (no illegal-instruction trap), `G-07` (`JALR`), `G-08` (sub-word lanes) |
| `M` | fixed on (`D-07`); multiply and divide without a helper library | 1 | absent: the encodings alias onto the base ALU (`rtl/instruction_decode.sv:323-329`, `G-06`) |
| `C` | fixed on (`D-07`); code size for a small MCU | 1 | absent: not decoded (`G-06`) |
| `Zicsr` | required for `mtvec`, the trap CSRs, `mhartid` and `misa` | 1 | absent: `CSR*` is a no-operation (`rtl/instruction_decode.sv:333-335`, `G-13`) |
| `Zifencei` | `fence.i` makes the cache coherent with stores (`D-04`) | 1 | absent: `fence.i` is a no-operation (`G-06`, `G-15`) |
| `Zicntr` | a tick source that does not consume a timer peripheral | 1 | absent (`G-13`) |
| Machine trap architecture: `mtvec`, `mepc`, `mcause`, `mstatus`, `mtval`, `mscratch`, `mret` | trap entry and return, the precondition for any RTOS | 1 | partial: an entry mechanism with a constant vector and a cause tied to zero, and no CSR visibility (`G-01`, `G-02`, `G-13`) |
| Machine timer interrupt (`MTIP`) | the preemption tick of `D-01` | 1 | absent (`G-14`) |
| Machine external interrupt (`MEIP`) | device service without polling | 1 | absent (`G-14`) |
| `A`: Zaamo + Zalrsc | atomics for harts that can race (`D-06`) | 2 | absent (`G-16`) |
| Machine software interrupt (`MSIP`, IPI) | cross-hart wake-up and scheduling in SMP | 2 | absent (`G-14`, `G-16`) |
| `mhartid` with `NUM_HARTS > 1` | hart identification (`D-03`) | 2 | absent (`G-16`) |
| `Zihpm`, `S`/`U` mode, Sv32 MMU, `F`, `D`, `V`, debug, trace | outside the product scope (§1) | — | absent; no requirement is made |

## 8. Traceability summary

- Forward index: the `Traces to` column of §4 and §5 (requirement to block and to test).
- Reverse index: [verification.md](verification.md).
- Verified today: `FR-09`, `FR-10` to `T-01`.
- Orphans (implemented, no observing test): `FR-01` to `FR-08` and `FR-11` to `FR-22`, all to `G-04`. The
  single root cause is that the reference model and scoreboard understand only `LW` and `SW`.
- Unimplemented as-built requirements: `FR-23`, `FR-24`, `FR-25`, `FR-26` (`G-01`, `G-02`, `G-06`, `G-13`);
  and every `NFR-01` to `NFR-07` (`G-03`, `G-04`, `G-05`, `G-10`).
- Target requirements with no implementation: `FR-27`, `FR-28`, `FR-31`, `FR-34` (`G-15`); `FR-29`,
  `FR-30`, `FR-32`, `FR-37` (`G-13`); `FR-39`, `FR-40` (`G-14`); `FR-33`, `FR-35`, `FR-36` (`G-16`);
  `FR-38` (`G-18`).
- `T-02` is registered but adds no new stimulus, so nothing cites it (`G-11`).
- Every target row from `FR-27` to `FR-40` names its phase in the acceptance text, so a reader can tell a
  phase-1 gap from a phase-2 commitment without leaving this document; the as-built `deferred` rows
  (`FR-23` to `FR-26`) inherit their phase from §7.1.

## 9. Assumptions, gaps, and open questions

### Assumptions

`A-01` to `A-07` were inferred in v0.1 from the RTL or the testbench. `A-08` to `A-16` are the proposed
defaults of the 2026-10-28 round: each is in force until the designer says otherwise, and each names what
changes if it is wrong. Status is `open` while the default is unconfirmed, `confirmed` once the designer has
said so, and `superseded` when a later answer replaced it — a superseded row is kept, never renumbered, and
must not be cited.

| ID | Statement | Owner | Method | Due | If false | Status |
|---|---|---|---|---|---|---|
| A-01 | The data memory asserts the grant in the cycle its read data is valid, and the core may stall indefinitely while the grant is withheld. | integrator | protocol review against `rtl/control.sv:246-251` | 2026-12-31 | `FR-21` is wrong and every load gains or loses a wait state (`G-09`) | confirmed 2026-10-28 for loads (answer 6); the store half moved to `FR-38` |
| A-02 | `x0` is hardwired to zero and writes to it are discarded as a deliberate architectural choice, not a placeholder. | designer | designer confirmation | 2026-12-31 | `FR-14` becomes an implementation detail rather than a promise | open |
| A-03 | **Superseded 2026-10-28, do not cite.** The instruction memory presents data and ready in the same cycle as the address, so a fetch has zero latency. | integrator | replaced by the line-fill contract | 2026-12-31 | nothing is lost by retiring it: the replacement is `FR-27` (a line per fill) and `FR-28` (a real stall), and `G-09` became a prerequisite rather than a doubt | superseded |
| A-04 | The contents of the general-purpose registers after reset are unspecified; software initialises every register it reads. | designer | designer confirmation | 2026-12-31 | a zero-initialised register file is required, changing reset cost and `FR-14`'s testing | open |
| A-05 | Address alignment is the responsibility of the memory, not of the core: misaligned loads and stores are passed through unchanged. | integrator | protocol review | 2026-12-31 | a misaligned-access trap is needed, adding a requirement and a trap cause | open |
| A-06 | Reset is de-asserted synchronously by the integrator; the core does not need a reset synchroniser. | integrator | integration review | 2026-12-31 | the core must add reset synchronisation, adding latency and a constraint change to `C-01` | open |
| A-07 | A single hart has one outstanding instruction fetch and one outstanding data access, and no ordering between the two ports is promised. | designer | designer confirmation | 2026-12-31 | a memory-ordering requirement is missing from §4 and §5; with `NUM_HARTS > 1` the per-hart reading stands and the cross-hart reading falls to `A-15` | open |
| A-08 | No clock-frequency target and no target part are recorded; the default is "unmeasured", not a frequency. | designer | designer supplies a frequency and a part (`Q-08`) | 2026-12-31 | `NFR-01` stays `TBD` and `G-05` stays open; no requirement changes | open |
| A-09 | The signoff bar is: every `FR` row `verified`, one functional-coverage bin per decoded instruction and per memory width, and the applicable `rv32ui-p-*` images green. Spec and ISA gaps are owned by the designer, DV gaps by the verification lead. | designer, verification lead | designer confirmation (`Q-11`, `Q-12`) | 2026-12-31 | `NFR-05`, `NFR-06` keep no target and the gap owners in `doc/verification.md` stay proposed | open |
| A-10 | The instruction-fill burst is a simple request, length, valid and last-beat handshake in every configuration, not an AXI-style channel with identifiers and separate read-data beats, and a cache-less build keeps the same line interface. | designer | designer confirmation (`Q-13`) | 2026-12-31 | `FR-27` is re-written against the chosen protocol, the interface summary in §6 changes shape, and the integrator needs two memory models | open |
| A-11 | The instruction cache line is 32 bytes, eight words, in phase 1. | designer | designer confirmation (`Q-14`) | 2026-12-31 | the fill length in `FR-27` and the parameter row for `ICACHE_LINE` in §5.2 change together | open |
| A-12 | A compiled binary is valid only for the configuration it was built for; `NUM_HARTS`, `ENABLE_A` and `ICACHE_BYTES` are not binary-portable. | designer | designer confirmation of `D-05` (`Q-16`) | 2026-12-31 | a single binary must run on every variant, so `ENABLE_A` and `NUM_HARTS` need run-time discovery and `misa` becomes mandatory in phase 1 | open |
| A-13 | `fence` carries full ordering semantics; an implementation that adds no work is acceptable only if the memory interface is single-outstanding and blocking, and that justification is written into `FR-26`. | designer | designer confirmation (`Q-15`) | 2026-12-31 | `FR-26` requires real ordering machinery, or the no-op stays unjustified and the row cannot leave `deferred` | open |
| A-14 | The interrupt controller is the ratified CLINT (timer) plus PLIC (external), and CLIC is not used, consistently with `D-08`. | designer | designer confirmation (`Q-17`) | 2026-12-31 | the core keeps its `MTIP`/`MEIP` obligation but the SoC-level integration and the vectored question in `FR-30` are re-opened | open |
| A-15 | There is no data cache in any phase, so shared memory needs no coherence protocol, and inter-hart ordering is limited to what fences and atomics provide. | designer | design review of `D-04` | 2026-12-31 | a coherence or TCDM protocol becomes a requirement and `FR-35` changes | open |
| A-16 | Every hart leaves reset at the same fetch address and the core does not designate a boot hart; hart selection is done by software or by the SoC. | designer | designer confirmation (`Q-18`) | 2026-12-31 | the core needs a boot-hart mechanism and `FR-33` gains a clause | open |

### Gaps

The canonical gap table, with owners and targets, is in `doc/verification.md`. Rows introduced or reframed in
this revision: `G-01` and `G-02` now name `mtvec` and `mcause` as their targets; `G-09` changed from "a doubt
about the fetch handshake" to "the prerequisite for the instruction cache", because with a 2 kB cache a miss
is the normal case and the core must be able to hold its program counter. New rows: `G-13` (no CSR file), `G-14`
(no interrupt subsystem), `G-15` (no cache and no line fetch), `G-16` (no multi-hart support), `G-17` (no
decision log), `G-18` (stores ignore the data grant).

| Gap | Statement | Impact on this document |
|---|---|---|
| `G-04` | Only `LW`/`SW` are model-checked. | 20 as-built rows cannot become `verified` |
| `G-06` | Unimplemented encodings execute as no-operations. | `FR-24` to `FR-26` stay `deferred`; §7 marks RV32I partial; `M` and `C` cannot be claimed in phase 1 |
| `G-08` | Sub-word accesses always use the lowest lane. | `FR-11`/`FR-12` describe observed, not intended, behaviour |
| `G-09` | No fetch stall exists; the program counter advances while the grant is withheld. | prerequisite for `G-15`: a cache cannot stall a core that cannot stall; `FR-28` is the requirement that closes it |
| `G-13` | No CSR file and no CSR instruction. | `FR-23`, `FR-29`, `FR-30`, `FR-32`, `FR-37` stay `deferred` |
| `G-14` | No machine-mode interrupt subsystem: no timer, no external controller, no software interrupt. | `FR-39`, `FR-40`, `FR-36`, and the vectored mode of `FR-30`, stay `deferred` |
| `G-15` | No instruction cache and no line-based fetch; `ICACHE_BYTES` and `ICACHE_LINE` do not exist. | `FR-27`, `FR-28`, `FR-31`, `FR-34` stay `deferred`; §5.2 is a target, not a description |
| `G-16` | No multi-hart support: no hart-identity input, no `NUM_HARTS`, no `A` extension. | `FR-32`, `FR-33`, `FR-35`, `FR-36` stay `deferred`; `MCU_SMP` cannot be built |
| `G-17` | No decision log: `doc/decisions.md` does not exist, so `D-01` to `D-08` live in §0.1. | decisions are not indexed beside the requirements they justify |
| `G-18` | Stores do not wait for the data grant: the stall condition needs a load destination. | `FR-38` stays `deferred`; the store contract is the testbench's, not the core's |
| `G-19` | A load-use freeze also disables the register-file write. | a WB commit can be lost; no registered test observes it |
| `G-20` | The jump/branch target adds an unsigned 21-bit immediate slice. | backward control transfers are wrong; `FR-06`..`FR-08` hold for forward offsets only |

### Open questions

The interview ledger is [spec-questions.md](spec-questions.md). Answered in the 2026-10-28 round: `Q-01`,
`Q-02`, `Q-03`, `Q-07`, and `Q-04` in part; `Q-19` closed as bookkeeping. Still open with a proposed default in
force: `Q-05`, `Q-06`, `Q-08` to `Q-18`, and `Q-20`.

| Topic | Open question | Owner | Status |
|---|---|---|---|
| illegal encodings | `Q-05` — must an unimplemented encoding trap instead of executing as a no-operation | designer | open |
| ISA deviations | `Q-06` — `JALR` target bit 0, and sub-word lane selection | designer | open |
| performance | `Q-08`, `Q-09`, `Q-10` — frequency and part, throughput, area and power | designer | open |
| signoff | `Q-11`, `Q-12` — coverage bar and gap ownership | verification lead | open |
| memory contract | `Q-13` to `Q-15` — burst shape, line size, `fence` semantics | designer | open |
| product variants | `Q-16` — is a binary per configuration accepted | designer | open |
| SMP integration | `Q-17`, `Q-18` — interrupt controller, and how secondary harts start | designer, integrator | open |
| round provenance | `Q-19` — closed: item 5 was `fmax`/part (`Q-08`) | designer | closed |
| MVP atomics | `Q-20` — does `MCU_RTOS` need `ENABLE_A=1` (Zephyr) or `=0` (FreeRTOS)? | designer | open |

## 10. References

- ISA: *The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA* (RV32I, `Zicsr`, `Zifencei`, `Zicntr`,
  `M`, `C`, `A`), latest **ratified** revision — drafts are advisory only (`D-08`).
- Privileged: *The RISC-V Instruction Set Manual, Volume II: Privileged Architecture*, machine-level chapter:
  `mtvec`, `mepc`, `mcause`, `mstatus`, `mie`, `mip`, `mtval`, `mscratch`, `mret`, `mhartid`, `misa`.
- Microarchitecture: [uarch.md](uarch.md) — blocks `BLK-IF`, `BLK-ID`, `BLK-EX`, `BLK-MA`, `BLK-CTL`, `BLK-REG`, `BLK-ALU`, `BLK-JMP`.
- Verification: [verification.md](verification.md) — tests `T-01`, `T-02`, gaps `G-01` to `G-18`.
- Interview ledger: [spec-questions.md](spec-questions.md).
- Conflict resolution: when this document and the RTL disagree, open a gap; do not silently edit either.
