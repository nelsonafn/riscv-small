# riscv-small Core Specification

| Field | Value |
|---|---|
| Status | draft |
| Version | v0.5 |
| Date | 2026-10-28 |
| Owner | designer — spec and ISA gaps; verification lead — DV gaps; every target 2026-12-31 (`A-09`, `Q-12`) |
| Last reviewed | never — designer review requested |
| Baseline | commit `bb789bb` (v0.1, as-built); v0.2 to v0.5 add intent only, no RTL change |
| Source | elicitation + reconstruction |
| Normative ISA | RISC-V ISA **v20260120**, volume I (unprivileged) and volume II (privileged) |

> **Provenance.** Two kinds of row live in this document, and the status tells them apart.
> Rows marked `implemented`, `partial` or `verified` are **reverse-engineered** from `rtl/` and `tb/`; they cite
> `file:line` and record today's behaviour, not anyone's intent. Rows marked `deferred`, the decision table
> in §0.1, and the target ISA table in §7.1 come from the **2026-10-28 elicitation rounds**; they record the
> target, not the RTL. Where the two disagree, the difference is a gap (`G-xx`), never an edit to either
> side. Nothing becomes `implemented` in this revision: no RTL changed.
>
> The four status values are shared with [verification.md](verification.md) and mean the same in both files:
> `implemented` = the RTL does what the clause says and no gap contradicts it; `partial` = the clause executes
> in the RTL but a named gap shows it wrong for part of its domain, and the gap is cited in the row;
> `verified` = a test in this repository observes it; `deferred` = the capability is absent and the clause
> states the target.
>
> **Where a claim comes from, since v0.4.** A row the standard decides cites the normative text by volume and
> section. A row the standard leaves open says so and records a **project decision** with its reason. The two
> are never mixed silently: `x0` (volume I §1.1.1) and misaligned support (volume I §1.1.6) are cited rules,
> while the reset style is a project decision (`D-09`, `A-06`) precisely because the ISA says nothing about it.

## Change log

| Date | Version | Change | Author | Reviewer |
|---|---|---|---|---|
| 2026-10-27 | v0.1 | First draft, **reverse-engineered** from `rtl/`, `tb/`, and `README.md`; no designer interview held; `Q-01..Q-12` raised for designer review | spec-author (reconstruction) | none yet — designer review requested |
| 2026-10-28 | v0.2 | Product intent recorded from the first elicitation round. Adds the MCU-plus-RTOS goal and SMP-ready target (`D-01`..`D-08`), a target ISA table with a phase per extension (§7.1), a synthesis configuration section (`NUM_HARTS`, `ENABLE_A`, `ICACHE_BYTES`, `ICACHE_LINE`; `C-06`..`C-11`), and `FR-27`..`FR-40`. Retires `A-03` (zero-latency fetch) in favour of a line-fill contract (`FR-27`, `FR-28`) and reframes `G-09` as a prerequisite for the I-cache. Adds `A-08`..`A-16` and `Q-13`..`Q-19`; all `TBD` owner dates moved to 2026-12-31. No RTL, testbench, or `doc/uarch.md` change; no row promoted to `implemented` or `verified` | spec-author (elicitation) | designer — pending |
| 2026-10-28 | v0.2.1 | Microarchitecture review: adds `G-19`/`G-20` notes to §4 and §9, closes `Q-19` as bookkeeping, adds `Q-20` (MVP atomics). No requirement text changed | docs-coordinator | designer — pending |
| 2026-10-28 | v0.3 | Round 2 of the elicitation: the designer accepted all eight proposed defaults, so `Q-05` (unimplemented encodings trap, no silent no-op), `Q-06` (both ISA deviations fixed before signoff), `Q-13` (instruction-fill burst shape, and the cache-less build keeps the line interface), `Q-14` (32-byte, eight-word line), `Q-16` (one binary per configuration), `Q-17` (CLINT plus PLIC, no CLIC), `Q-18` (every hart leaves reset at the same address) and `Q-20` (`ENABLE_A` = 0 for `MCU_RTOS`) are confirmed. Rewrites `FR-24`, `FR-25`, `FR-27` and §4.1 (now a phase-1 conformance list); sharpens the acceptance criteria of `FR-07`, `FR-11`, `FR-12`; makes `G-07` and `G-08` release blockers; accepts `D-05` and adds the phase/configuration note to `C-07`; moves `A-10`, `A-11`, `A-12`, `A-14`, `A-15` and `A-16` to `confirmed` (`A-13` stays `open`). Also fixes two reconstruction cites: `FR-10` no longer points past the end of `rtl/execution.sv` (the file has 185 lines) but at the EX/MA register in `rtl/execution.sv:89-108` and the store data and write-enable ports in `rtl/riscv_small.sv:193-196`; `FR-24` no longer cites the immediate generator's fall-through (its default arm) but the decoder's, `rtl/instruction_decode.sv:238-247`. No requirement status changes, no RTL, testbench, or `doc/uarch.md` change; `NFR-01`..`NFR-06` keep `TBD` | spec-author (elicitation) | designer — round 2 answers |
| 2026-10-28 | v0.3.1 | Status vocabulary aligned with `doc/verification.md` (`partial` for `FR-06`, `FR-07`, `FR-08`, `FR-17`, `FR-22`, with the governing gap named in each row, and the four values defined in the provenance note); the `Q-06` clauses of `FR-07`, `FR-11` and `FR-12` restated as intent instead of as the observed behaviour; §7 evidence corrected (`G-08` → `A-05` for the misaligned-access row); `Q-21` recorded in `FR-27` as the open question on early burst termination. No requirement status promoted, no RTL, testbench, or `doc/uarch.md` change | spec-author (elicitation) | designer — round 2 answers |
| 2026-10-28 | v0.3.2 | `FR-11` and `FR-12` reclassified `implemented` → `partial`: the `Q-06` clause requires lane selection and the RTL never reads `data_addr[1:0]` (`G-08`, release blocker); `doc/verification.md` moves with them, so the two tables still agree row for row | docs-coordinator | designer — pending |
| 2026-10-28 | v0.4 | Rounds 3 and 4 applied. **Round 3** (`Q-08`..`Q-12`, `Q-15`, `Q-21`): the four non-functional targets stay `TBD` but their measurement method becomes normative ("measure first, then fix the number"); the signoff bar of `A-09` is confirmed and `G-03`, `G-04`, `G-10`, `G-11` become release blockers; gap ownership is fixed in §2 and §9; `fence` is full ordering, so `FR-26` is a phase-1 obligation blocked only by the RTL; a short instruction burst becomes a protocol error, deleting `FR-27`'s provisional 4-beat tolerance. **Round 4** (`Q-22`..`Q-27`) answered against RISC-V ISA v20260120: `x0` becomes constraint `C-12` citing volume I §1.1.1 with the `rd = x0` companion rule of §1.1.6 and retires `A-02`; `A-04` is rewritten from volume II §2.1.4 ("All other hart state is UNSPECIFIED") with the software obligation; `A-05` is rewritten as an EEI guarantee from volume I §1.1.6, which also settles the lane contract in §6; `A-06` is revised to the hybrid reset and produces `D-09`, `FR-41`, `C-01`, the `RESET_SYNC_STAGES` parameter and `G-21`; `A-07` is confirmed as microarchitecture with `Q-27` opened on fetch-side ordering. Adds `A-17` (`Q-04`) and `A-18` (`Q-27`) as the only `open` assumptions. Fixes the malformed `v0.3.2` change-log row. No RTL, testbench, or `doc/uarch.md` change | spec-author (elicitation) | designer — rounds 3 and 4 |
| 2026-10-28 | v0.5 | Round 5: `Q-28` and `Q-29`, both settled by comparing maintained open cores. `Q-28` gives the data port an explicit `data_wr_strb[3:0]`: the core places the value in the addressed lane and asserts the strobes for the bytes it drives, and the memory never shifts, justifies or masks — the port set in §6 is now named signal by signal and grows from fifteen to sixteen. `Q-29` keeps `A-05`'s EEI guarantee and says how it is discharged: an access that crosses a word boundary is split into two word-aligned transactions by the core, non-atomically, as Ibex and CV32E40P do (PicoRV32's bus-error route was rejected). Adds `FR-42` (split, `deferred`), `G-22` (no strobes, no second beat) and rewrites `FR-11`, `FR-12`, `FR-13`, `A-05`, the §6 data-memory row and the §6 lane contract. No requirement status promoted, no RTL, testbench, `doc/uarch.md` or `doc/verification.md` change | spec-author (elicitation) | designer — round 5 |

## 0. Interview log

Evidence that the requirements came from someone, not only from the code.

| Round | Date | Participants | Questions | Artifacts |
|---|---|---|---|---|
| reconstruction | 2026-10-27 | none — no designer available | none asked; 12 raised for later | `rtl/riscv_small.sv`, `rtl/instruction_fetch.sv`, `rtl/instruction_decode.sv`, `rtl/execution.sv`, `rtl/memory_access.sv`, `rtl/control.sv`, `rtl/alu.sv`, `rtl/jump_decision.sv`, `rtl/reg_file.sv`, `rtl/riscv_definitions_pkg.sv`, `tb/tests/*.sv`, `tb/tests/sequence_lib/*.sv`, `tb/env/ref_model/*`, `tb/env/top/riscv_small_coverage.sv`, `tb/env/agents/riscv_small_agent/riscv_small_driver.sv`, `README.md`; `F-01`..`F-08`, `FR-01`..`FR-26`, `NFR-01`..`NFR-07`, `C-01`..`C-05`, `A-01`..`A-07`, `Q-01`..`Q-12` |
| 1 | 2026-10-28 | designer; spec-author (answers relayed by `docs-coordinator`) | eight items put, six answered. **1** RTOS mode is a software build choice, so the hardware must support preemption. **2** 2 kB direct-mapped I-cache by default, configurable, no D-cache, `fence.i` flushes it. **3** Instruction fetch fills per line (burst), replacing the per-word contract. **4** `NUM_HARTS` in the main configuration package, default 1; `mhartid` is an input. **6** A data transfer completes on the grant at the clock edge, no write-response channel, must stay compatible with a future D-cache or TCDM. **7** Trap vector is the `mtvec` CSR, no vector input port. Items **5** and **8** were not answered: 5 was `fmax`/part (`Q-08`) and 8 the signoff bar (`Q-11`, `Q-12`); `Q-19` closed as bookkeeping | §0.1 `D-01`..`D-08`; §0.2; `FR-27`..`FR-40`; `C-06`..`C-11`; `A-08`..`A-16` |
| 2 | 2026-10-28 | designer; spec-author (answers relayed by `docs-coordinator`) | eight questions put (`Q-05`, `Q-06`, `Q-13`, `Q-14`, `Q-16`, `Q-17`, `Q-18`, `Q-20`); every proposed default accepted, no counter-proposal. **Q-05** every encoding outside the implemented subset traps, including `ECALL`, `EBREAK`, CSR and multiply encodings; no silent no-operation. **Q-06** both known ISA deviations are fixed before signoff. **Q-13** simple request/length/valid/last-beat burst, no identifiers, no separate read-data channel, same line interface when `ICACHE_BYTES` = 0. **Q-14** 32-byte line, fixed in phase 1. **Q-16** one binary per configuration; `NUM_HARTS`, `ENABLE_A` and `ICACHE_BYTES` are not binary-portable. **Q-17** CLINT plus PLIC, not CLIC; no data cache, so no coherence protocol. **Q-18** every hart leaves reset at the same fetch address; no boot hart. **Q-20** `ENABLE_A` = 0 for `MCU_RTOS`: the MVP RTOS masks interrupts for critical sections, so `A` stays phase 2 and `MCU_SMP` stays the only configuration that carries it | §0.3; `D-05`; `FR-07`, `FR-11`, `FR-12`, `FR-24`, `FR-25`, `FR-27`; §4.1; `C-07`; §5.2; §6; §7.1; `A-10`..`A-12`, `A-14`..`A-16` |
| 3 | 2026-10-28 | designer; spec-author (answers relayed by `docs-coordinator`) | seven questions put (`Q-08`, `Q-09`, `Q-10`, `Q-11`, `Q-12`, `Q-15`, `Q-21`); all seven defaults accepted. **Q-08**-**Q-10** measure first, then fix the number, so the four non-functional targets keep `TBD` and the method becomes the requirement. **Q-11** the signoff bar of `A-09` is confirmed. **Q-12** gap ownership confirmed: designer for spec and ISA gaps, verification lead for DV gaps, all targets 2026-12-31. **Q-15** `fence` is full ordering, not a no-op justified by the port. **Q-21** a short burst is a protocol error, so the 4-beat tolerance goes | §0.4; `NFR-01`..`NFR-06`; `FR-26`; `FR-27`; `A-08`, `A-09`, `A-13`; §9 |
| 4 | 2026-10-28 | designer; spec-author (answers relayed by `docs-coordinator`) | five assumptions put (`Q-22`..`Q-26`) and answered by asking what the normative text says; `Q-27` opened by the last answer. **Q-22** `x0` is the ISA rule (volume I §1.1.1), so `A-02` retires into `C-12`. **Q-23** everything but the listed state is UNSPECIFIED after reset (volume II §2.1.4), so `A-04` is rewritten. **Q-24** misaligned behaviour is EEI-dependent (volume I §1.1.6) and this EEI guarantees support, so `A-05` is rewritten and the lane contract is fixed. **Q-25** the ISA is silent on reset style, so the project picks the hybrid reset (`D-09`, `FR-41`, `G-21`). **Q-26** the ISA constrains ordering, not the in-flight count, so `A-07` is microarchitecture and `Q-27` asks about the fetch side once the cache lands | §0.5; `C-12`; `D-09`; `FR-41`; §6; `A-02`, `A-04`..`A-07`; §9 |
| 5 | 2026-10-28 | designer; spec-author (answers relayed by `docs-coordinator`) | two questions put, both answered by comparing maintained open cores. **Q-28** the data port gains `data_wr_strb[3:0]`, because PicoRV32 exposes `mem_wstrb[3:0]`, Ibex `data_be_o[3:0]` with a word-aligned address and CV32E40P OBI byte enables, so this port was the outlier; the core places the value in the lane and the memory never justifies. **Q-29** an access that straddles two aligned words is split into two word-aligned transactions, as Ibex and CV32E40P do; PicoRV32's bus-error route was rejected, so `A-05`'s guarantee survives and is now implementable | §0.6; §6; `FR-11`, `FR-12`, `FR-13`, `FR-42`; `A-05`; `G-22` |

Mode: **elicitation** for everything v0.2 to v0.5 add, **reconstruction** for the as-built rows inherited from
v0.1 (those cite `file:line`). The elicitation evidence is the designer's answers as relayed by the
coordinator; the RTL was not re-read to confirm intent, only to state what exists.

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
| D-05 | A compiled binary is valid only for the configuration it was built for; ISA differences between variants are not binary-portable. | keeps `NUM_HARTS` and `ENABLE_A` free instead of freezing one ABI | `C-11` — accepted 2026-10-28, `A-12` confirmed (`Q-16`) | confirmed |
| D-06 | `A` (Zaamo + Zalrsc) enters the target ISA in phase 2 and is not advertised in `misa` before it is implemented. | atomics are needed only when harts can race | `C-07`, `FR-35`, `FR-37` | confirmed |
| D-07 | `M` and `C` are fixed on and are not parameters. | every target toolchain emits them; a build without them saves nothing | `C-10`, §7.1 | confirmed |
| D-08 | The normative source is the latest **ratified** RISC-V specification; drafts are advisory only, so `mtvec`/`mepc`/`mcause`/`mstatus`/`mie`/`mip` follow the ratified privileged spec and neither RVM23 nor CLIC is adopted. | a draft can change under a validated product | `FR-29`, `FR-30`, `FR-37`; `A-14` | confirmed |
| D-09 | The reset is **hybrid**: `rst_n` low asserts asynchronously, de-assertion is synchronised through `RESET_SYNC_STAGES` flops, and a global macro selects the style so an FPGA build can use a synchronous reset. | the ISA says nothing about reset style, so this is a project choice; an asynchronous reset arriving from an external pin needs a de-assertion synchroniser, and the project's RTL guidance already partitions the two styles by macro (`.opencode/skills/systemverilog-rtl-verification/references/reset-and-fsm.md`, "Global reset selection", "Reset synchronizer") | `C-01`, `FR-41`, `A-06`; gap `G-21` | confirmed 2026-10-28 (`Q-25`) |

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

### 0.3 Round-2 answers (2026-10-28), with their classification

All eight were answered "yes" to the proposed default, so each row below is the default as the designer accepted
it, not a paraphrase of new intent. Nothing was overturned.

| Q | Answer (paraphrased back to the designer) | Classified as | Recorded in |
|---|---|---|---|
| `Q-05` | Every encoding outside the implemented subset raises a trap, including `ECALL`, `EBREAK`, CSR encodings and multiply/divide encodings; nothing executes silently as a no-operation. | requirement text `FR-24`, `FR-25`; conformance list §4.1; gap scope `G-06` | §4, §4.1, §9 |
| `Q-06` | Both known ISA deviations are fixed before signoff: `JALR` clears bit 0 of the target, and a sub-word access selects the addressed lane inside the word. | acceptance `FR-07`, `FR-11`, `FR-12`; `G-07`, `G-08` become release blockers | §4, §7.1, §9 |
| `Q-13` | The fill burst is one request per line with a length, a valid, and a last-beat flag on the final beat; no identifiers, no separate read-data channel; the cache-less build keeps the same line interface. | requirement `FR-27`; interface summary §6; assumption `A-10` confirmed | §4, §6, §9 |
| `Q-14` | The instruction-cache line is 32 bytes, eight words, fixed in phase 1 and not independently tunable. | constraint `C-09` (unchanged); parameter row `ICACHE_LINE`; assumption `A-11` confirmed | §5.1, §5.2, §9 |
| `Q-16` | One binary per configuration: `NUM_HARTS`, `ENABLE_A` and `ICACHE_BYTES` are not binary-portable. | decision `D-05` accepted; constraint `C-11`; assumption `A-12` confirmed | §0.1, §5.1, §9 |
| `Q-17` | The interrupt controller is the ratified CLINT for the timer plus the PLIC for external requests; CLIC is not used; nothing is cached in data memory, so no coherence protocol exists. | assumptions `A-14`, `A-15` confirmed; the `MTIP`/`MEIP` obligation and the vectored scope of `FR-30` stand | §1, §9 |
| `Q-18` | Every hart leaves reset at the same fetch address; the core designates no boot hart. | assumption `A-16` confirmed; `FR-33` unchanged | §1, §9 |
| `Q-20` | `ENABLE_A` = 0 for `MCU_RTOS`: the MVP RTOS masks interrupts for critical sections and needs no atomics; `A` stays phase 2 and `MCU_SMP` stays the only configuration that carries it. If Zephyr becomes the target, the default flips. | constraint `C-07` note; configuration table; §7.1 phase table; `FR-35` unchanged at phase 2 | §5.1, §5.2, §7.1 |

### 0.4 Round-3 answers (2026-10-28): seven more defaults accepted

| Q | Answer (paraphrased back to the designer) | Classified as | Recorded in |
|---|---|---|---|
| `Q-08` | No frequency and no part are recorded yet. The method is the requirement: the first synthesis reports achieved Fmax and the target part, and only then may a frequency become a requirement. | `NFR-01` target stays `TBD`, method becomes normative; assumption `A-08` confirmed and restated | §5, §9 |
| `Q-09` | Report measured cycles for one named kernel first; the throughput target is set from that number. | `NFR-02` `TBD`, method normative | §5 |
| `Q-10` | Report post-synthesis resources and vector-based power, with and without the cache, then set the budgets. | `NFR-03`, `NFR-04` `TBD`, method normative | §5 |
| `Q-11` | The signoff bar is exactly what `A-09` states: every `FR` `verified`, one functional-coverage bin per decoded instruction and per memory width, and the applicable `rv32ui-p-*` images green. | `NFR-05`, `NFR-06` targets confirmed; `G-03`, `G-04`, `G-10`, `G-11` release blockers | §5, §9 |
| `Q-12` | The designer owns the spec and ISA gaps, the verification lead owns the DV gaps, all targets 2026-12-31. | assumption `A-09` confirmed; ownership stated once in §2 and §9 | §2, §9 |
| `Q-15` | `fence` carries full ordering semantics, so `FR-26` is a phase-1 obligation. | `FR-26` phase 1, still `deferred` because the RTL does not implement it; `A-13` confirmed; `G-06`'s `FENCE` scope narrowed | §4, §9 |
| `Q-21` | The instruction memory delivers exactly the requested beat count; a short `last` is a protocol error. | `FR-27` acceptance loses the 4-beat tolerance and names the error | §4 |

### 0.5 Round-4 answers (2026-10-28): five assumptions answered against the standard

The designer asked what the normative text says and instructed that this specification follow it, so each answer
below is a citation where the standard decides and a project decision where it does not.

| Q | Answer (paraphrased back to the designer) | Citation or decision | Recorded in |
|---|---|---|---|
| `Q-22` | `x0` is hardwired to zero because volume I §1.1.1 says so: "Register `x0` is hardwired with all bits equal to 0". This is not a project choice, so it cannot be an assumption; the companion rule that a load with `rd = x0` still raises its exceptions and causes its side effects follows from §1.1.6. | cited rule; `A-02` retired, `C-12` added | §5.1, §9 |
| `Q-23` | After reset only the state listed in privileged volume II §2.1.4 is defined; "All other hart state is UNSPECIFIED", so no register value is a contract. | cited rule; `A-04` rewritten and confirmed | §9 |
| `Q-24` | Misaligned behaviour is EEI-dependent (§1.1.6), and this EEI guarantees full support, so the core passes every byte address through and raises no misaligned exception. The data memory returns the aligned word and the core selects the lane. | cited rule plus one EEI guarantee; `A-05` rewritten and confirmed; lane contract in §6 | §6, §9 |
| `Q-25` | The ISA says nothing about reset style. The project uses a hybrid reset: asynchronous assertion, de-assertion through a `RESET_SYNC_STAGES` synchroniser, style selected by a global macro. | project decision `D-09`, taken from `.opencode/skills/systemverilog-rtl-verification/references/reset-and-fsm.md`; `A-06` revised, `FR-41`, `G-21` | §0.1, §4, §5.1, §5.2, §9 |
| `Q-26` | The standard constrains ordering, never the number of in-flight transactions (RVWMO volume I chapter 17; `FENCE` §1.1.7; `FENCE.I` Zifencei chapter 4). One outstanding access per port is a microarchitecture choice whose remaining normative obligation is `FENCE` and `FENCE.I`. | cited rule; `A-07` confirmed as microarchitecture; `Q-27` opened | §9 |

### 0.6 Round-5 answers (2026-10-28): the data port, settled against maintained open cores

The audit found the data port describing a byte-strobe capability it did not have. The designer answered both
halves by comparing three maintained open cores rather than by preference.

| Q | Answer (paraphrased back to the designer) | Evidence and consequence | Recorded in |
|---|---|---|---|
| `Q-28` | The port gains `data_wr_strb[3:0]`. The core places the value in the addressed lane and asserts the strobes for the bytes it drives; the memory never shifts or justifies. | PicoRV32 exposes `mem_wstrb[3:0]`, Ibex `data_be_o[3:0]` with a word-aligned address, and CV32E40P carries OBI byte enables, so this port was the outlier; the §6 contract stops describing a signal the DUT does not have; `G-08` becomes a strobe-and-lane fix | §6, §4, §9 |
| `Q-29` | An access that straddles two aligned words is split by the core into two word-aligned transactions — the address advances, the strobes are recomputed for the second beat, the pipeline is held through both — and such an access is not atomic. | Ibex and CV32E40P split; PicoRV32 instead raises a bus error on a misaligned access, and that route was rejected. `A-05`'s EEI guarantee survives unchanged and is now implementable; `FR-42` carries it | §4, §9 |

## 1. Purpose and scope

This document specifies the externally observable behaviour of the `riscv_small` core, and the behaviour its
product intends. The product is a 32-bit RISC-V MCU core that runs a simple RTOS: an RTOS mode is a software
build choice, and the hardware obligation is that a preemption source exists and that a trap can be taken and
returned from (`D-01`). Multi-hart execution is a later milestone that the instruction set and the memory
interfaces must not preclude (`D-02`).

The document therefore has two layers. The **as-built** layer (v0.1, reconstructed) states which instructions
the core executes today, how it interacts with external instruction and data memories, how it resolves data
hazards, and what it does on a trap. The **target** layer (v0.2 to v0.5, elicited) states the extension set with a
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
- The choice of interrupt controller and the boot protocol of secondary harts, beyond the two answers of
  2026-10-28. The controller is the ratified CLINT (timer) plus the PLIC (external), not CLIC (`A-14`,
  `Q-17`); every hart leaves reset at the same fetch address and the core designates no boot hart (`A-16`,
  `Q-18`). Wiring and hart selection stay SoC concerns; the core-level obligation is only that a timer, an
  external, and (phase 2) a software interrupt be taken as traps (`FR-39`, `FR-40`, `FR-36`).
- Timing, area, power, and verification signoff. No measurement exists (`G-05`).

The as-built rows of v0.1 remain the description of today's RTL. Where an as-built row conflicts with a
target row, the as-built row keeps its status and the difference is a `G-xx`: v0.2 adds intent, it does not
upgrade capability.

## 2. Stakeholders and concerns

| Stakeholder | Concern | Addressed by |
|---|---|---|
| RTL designer | confirm or correct reconstructed behaviour; close `Q-01`..`Q-29`; own the spec and ISA gaps, with a 2026-12-31 target for each (`A-09`, `Q-12`) | §4, §5, §9 |
| Verification engineer | what to test, what is already covered, and which configuration is under test; own the DV gaps (`G-03`, `G-04`, `G-10`, `G-11`), which are release blockers | acceptance column, §5, §5.2, `G-03`, `G-04` |
| SoC integrator | memory handshake, clock and reset, trap vector source, hart identity, interrupt wiring, and a data memory that accepts any byte address | §5.2, §6, `A-01`, `A-05`, `A-16`, `G-14`, `G-18` |
| RTOS and application developer | preemption and its latency, CSR visibility, cache behaviour around self-modifying code, register state after reset | `FR-29`..`FR-31`, `FR-39`, `FR-40`, `A-04` |
| Compiler and toolchain owner | the exact ISA subset, alignment, `x0`, which extensions may be assumed | §4.1, §7, §7.1, `C-12`, `A-05`, `A-12` |
| Reviewer and auditor | traceability and honest status | §8, [verification.md](verification.md) |

## 3. Features

| ID | Feature | Notes |
|---|---|---|
| F-01 | Integer arithmetic and logic execution | the decoded subset is enumerated in §4.1, not the full RV32I |
| F-02 | Control transfer: six conditional branches, `JAL`, `JALR` | taken branches and jumps redirect the fetch stream; the redirect penalty is unmeasured (`G-05`) |
| F-03 | Word and sub-word load and store through an external data port | width is driven out of the core; sub-word lane handling is `G-08`; the grant contract is `FR-38` |
| F-04 | Instruction fetch through an external instruction port | as built: one word per cycle (`FR-20`); target: a line fill (`FR-27`, `FR-28`, `G-15`) |
| F-05 | Hazard-free single-issue execution | forwarding plus automatic stalls; software needs no inserted NOPs (`FR-15`..`FR-19`) |
| F-06 | Architectural register file with hardwired `x0` | `C-12` (the ISA rule); post-reset contents are unspecified (`A-04`) |
| F-07 | One clock domain, a global clock enable, hybrid reset: asynchronous assertion and synchronised de-assertion | `C-01`, `C-02`, `FR-41`, `D-09` |
| F-08 | Trap entry and return | as built: fixed vector, no cause, no software access (`G-01`, `G-02`); target: `mtvec` direct and vectored entry (`FR-29`, `FR-30`) |
| F-09 | Machine-mode privileged architecture: CSR file, trap CSRs, counters | phase 1 target; absent today (`G-13`) |
| F-10 | Instruction cache with line fills, invalidated by `fence.i` | phase 1 target; absent today (`G-15`) |
| F-11 | Configurable hart count with atomics and inter-processor interrupts | phase 2 target; absent today (`G-16`) |

## 4. Functional requirements

Read the `Evidence` column as "where this behaviour is visible in the RTL today". Status is `implemented`
when the RTL exists and no gap contradicts the clause, `partial` when the clause executes but a named gap
narrows it for part of its domain, `verified` only where `T-01`/`T-02` observe it, and `deferred` for
capability that is absent. A row whose Status says `deferred` and whose text names phase 2 is a commitment to
the SMP milestone, not to the MVP. The seven `partial` rows among the as-built rows are `FR-06`, `FR-07` and
`FR-08` (narrowed by `G-20`), `FR-11` and `FR-12` (narrowed by `G-08`), `FR-17` (`G-19`) and `FR-22`
(`G-01`); each names the gap in its Evidence cell, and the same seven rows carry `partial` in
[verification.md](verification.md). `FR-41` is the eighth `partial` row and the only one that is not as-built:
its assertion half exists, its synchronised release does not (`G-21`).

| ID | Requirement (shall) | Evidence (source) | Acceptance | Traces to | Status |
|---|---|---|---|---|---|
| FR-01 | The core shall execute the register-register integer instructions `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND`, with `SUB` and `SRA` selected by bit 5 of the register-form function field. | `rtl/instruction_decode.sv:323-329`, `rtl/alu.sv:52-92` | A directed test per encoding writes a known `rs1`/`rs2` pair and reads `rd` back through a store; any mismatch against the architectural model fails. No such test exists (`G-04`). | `F-01`, `BLK-ID`, `BLK-ALU` | implemented |
| FR-02 | The core shall execute the immediate integer instructions `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI` with the 12-bit immediate sign-extended. | `rtl/instruction_decode.sv:309-322`, `rtl/instruction_decode.sv:209-213` | Directed test per encoding, including negative immediates, compared against the model (`G-04`). | `F-01`, `BLK-ID`, `BLK-ALU` | implemented |
| FR-03 | The core shall execute `SLLI`, `SRLI` and `SRAI`, taking the shift amount from the low five bits of the immediate and choosing logical or arithmetic from the high function bit. | `rtl/instruction_decode.sv:312-318`, `rtl/alu.sv:56-81` | Shift by 0, 1, 31 and the logical/arithmetic pair compared against the model (`G-04`). | `F-01`, `BLK-ALU` | implemented |
| FR-04 | `LUI` shall write the upper 20 immediate bits shifted left by 12 into `rd`. | `rtl/instruction_decode.sv:248-253`, `rtl/instruction_decode.sv:221-223` | `rd` value read back for immediates `0x00000` and `0xFFFFF` (`G-04`). | `F-01`, `BLK-ID` | implemented |
| FR-05 | `AUIPC` shall write the address of the instruction plus the upper 20 immediate bits shifted left by 12 into `rd`. | `rtl/instruction_decode.sv:254-260` | `rd` value read back at two different program addresses (`G-04`); depends on `G-09`. | `F-01`, `BLK-ID` | implemented |
| FR-06 | `JAL` shall write the address of the next instruction into `rd` and continue at the current address plus the sign-extended jump offset. | `rtl/instruction_decode.sv:261-268`, `rtl/jump_decision.sv:98-112`, `rtl/instruction_fetch.sv:88-101`; forward offsets only, because the target adds `imm[20:0]` unsigned (`G-20`) | Forward and backward jump with `rd != x0`, checking both the link value and the landed address (`G-04`). | `F-02`, `BLK-JMP`, `BLK-IF` | partial |
| FR-07 | `JALR` shall write the address of the next instruction into `rd` and continue at the target address computed as `(rs1 + sign-extended 12-bit offset) & ~32'h1`, so bit 0 of the computed target is cleared. | `rtl/instruction_decode.sv:270-277`, `rtl/jump_decision.sv:103-111`; bit 0 is not cleared (`G-07`) and the offset is added unsigned (`G-20`) | Two indirect jumps whose `rs1` plus offset differ only in bit 0 land at the same address, the one with bit 0 cleared, and each writes the link value the model predicts to `rd` (`G-04`). `Q-06` (2026-10-28) fixed the deviation, so an implementation that keeps bit 0 is a release blocker (`G-07`). | `F-02`, `BLK-JMP` | partial |
| FR-08 | The core shall decide `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` from the source values, continuing at the branch target when the condition holds and at the next instruction otherwise. | `rtl/instruction_decode.sv:279-282`, `rtl/jump_decision.sv:117-164`; forward offsets only, because the target adds `imm[20:0]` unsigned (`G-20`) | Taken and not-taken case for each of the six conditions, with one signed and one unsigned boundary pair each (`G-04`). | `F-02`, `BLK-JMP` | partial |
| FR-09 | `LW` shall read the 32-bit word at the effective address and write it into `rd`. | `rtl/instruction_decode.sv:283-296`, `rtl/memory_access.sv:88-90` | `T-01`: 31 random loads whose values are then stored; the stored data is compared against the reference model; verified by `T-01`. | `F-03`, `BLK-MA` | verified |
| FR-10 | `SW` shall write the value of `rs2` to the 32-bit word at the effective address and assert the write strobe for that access. | `rtl/instruction_decode.sv:297-308`, `rtl/execution.sv:89-108` (the EX/MA register carrying `rd0_wr_en_ma` and `rs2_ma`), `rtl/riscv_small.sv:193-196` (store data and write-enable ports) | `T-01`: 31 random stores; address and data are compared against the reference model; verified by `T-01`. | `F-03`, `BLK-MA` | verified |
| FR-11 | `SB` and `SH` shall place the byte or halfword of `rs2` in the addressed lane of the word, selected by the low address bits, assert `data_wr_strb` for exactly the byte lanes it drives, and report the access width (byte or halfword) on the width output. | `rtl/instruction_decode.sv:303-307`, `rtl/riscv_small.sv:118`, `rtl/execution.sv:157-174`; the lowest lane is always used because `data_addr[1:0]` is never read, and there is no `data_wr_strb` port at all: `data_wr` is `rs2` unchanged (`G-08`, `G-22`) | Write a byte to each of the four byte offsets of one word, and a halfword to both halfword offsets, then read the word back: each store changes only the addressed lane, every other byte keeps its previous value, `data_wr_strb` is asserted for exactly the driven bytes and no others, and the memory performs no justification of its own (§6, `Q-28`). `Q-06` (2026-10-28) fixed the lane deviation, so always writing the lowest lane is a release blocker (`G-08`). | `F-03`, `BLK-MA` | partial |
| FR-12 | `LB`, `LH`, `LBU` and `LHU` shall select the byte lane or the halfword lane of the returned word addressed by the effective address, using the low address bits, and then sign-extend it for `LB`/`LH` or zero-extend it for `LBU`/`LHU`. | `rtl/memory_access.sv:80-102`; the lowest lane is always extended, for the same reason (`G-08`) | Load from each of the four byte offsets of a word holding `0x80FF7F01` through all four encodings: `LB` and `LBU` return the byte at the addressed offset and `LH` and `LHU` the halfword at the addressed offset, signed or zero-extended as the encoding requires (`G-04`). A halfword load at an odd address spans two words: the two transactions of `FR-42` are assembled into one value before the extension, and the bytes the memory returns are never shifted by the memory (§6, `A-05`). `Q-06` (2026-10-28) fixed the lane deviation, so always returning the lowest lane is a release blocker (`G-08`). | `F-03`, `BLK-MA` | partial |
| FR-13 | The core shall form the effective data address of a load or store as `rs1` plus the sign-extended offset and present it as a byte address, without alignment checking. | `rtl/instruction_decode.sv:209-232`, `rtl/execution.sv:113-152`, `rtl/riscv_small.sv:119` | Addresses with a non-zero base register and offsets of `-2048` and `+2047` observed on the data address port (`G-04`); an address whose low bits are non-zero is formed without an alignment check and raises no exception (`A-05`); as built the port then issues one transaction, and the two-transaction behaviour is the target of `FR-42`, not an observation (`G-22`). | `F-03`, `BLK-EX` | implemented |
| FR-14 | Architectural register `x0` shall read as zero and shall discard every write. | `rtl/reg_file.sv:64-89`, `rtl/reg_file.sv:100-103` | Write a non-zero value to `x0` and read it back as zero; read `x0` as a load base and observe address 0 (`G-04`). A load or store with `rd = x0` still raises the exceptions the access would raise and still causes its side effects, per `C-12` (`A-02` retired). | `F-06`, `BLK-REG`, `C-12` | implemented |
| FR-15 | A read of a register that is being written in the same cycle shall return the value being written. | `rtl/reg_file.sv:71-73`, `rtl/reg_file.sv:83-85` | Back-to-back producer/consumer pair with no intervening instruction, compared against the model (`G-04`). | `F-05`, `BLK-REG` | implemented |
| FR-16 | A consumer of an arithmetic result produced one or two instructions earlier shall observe that result without software-inserted NOPs. | `rtl/control.sv:184-227`, `rtl/execution.sv:113-152` | Producer/consumer distance of 1 and 2 for both source operands, compared against the model (`G-04`). | `F-05`, `BLK-CTL`, `BLK-EX` | implemented |
| FR-17 | A consumer of a load result shall observe the loaded value, with the wait required by the load absorbed by the core. | `rtl/control.sv:115-140`, `rtl/control.sv:184-227`; the load-use freeze also clears the register-file write, so an in-flight write-back can be lost (`G-19`) | Load followed immediately by an ALU consumer, and load followed immediately by a conditional branch, both compared against the model (`G-04`). | `F-05`, `BLK-CTL` | partial |
| FR-18 | Store data shall be sourced from `rs2`, including when `rs2` is produced by the immediately preceding instruction. | `rtl/execution.sv:157-174`, `rtl/control.sv:205-227` | Producer of distance 1 and 2 followed by a store of that register, address and data compared against the model (`G-04`). | `F-05`, `BLK-EX`, `BLK-CTL` | implemented |
| FR-19 | Conditional-branch operands shall be sourced from the newest available value of `rs1` and `rs2`, including values produced by instructions still in flight. | `rtl/instruction_decode.sv:134-173`, `rtl/control.sv:108-177` | Branch where each operand is produced 0, 1 and 2 instructions earlier, decided as the model predicts (`G-04`). | `F-02`, `F-05`, `BLK-JMP`, `BLK-CTL` | implemented |
| FR-20 | The core shall present one instruction address per cycle while it is running and assert the fetch request in the same cycle. | `rtl/control.sv:101`, `rtl/instruction_fetch.sv:63-77` | The fetch address and the request are observed cycle by cycle for a straight-line program, advancing by four bytes per running cycle (`G-09`). Superseded for the target by `FR-27` and `FR-28`; kept because it describes today's RTL. | `F-04`, `BLK-IF` | implemented |
| FR-21 | The core shall treat a load as complete only when the data memory reports the data ready. | `rtl/control.sv:246-251` | A memory model that grants one cycle late and one that grants immediately both give identical architectural results (`A-01`, `G-09`). A store is not covered by this row: see `FR-38` and `G-18`. | `F-03`, `BLK-CTL` | implemented |
| FR-22 | On an asserted `exception` input the core shall discard the fetched and decoded instructions and continue at the trap vector. | `rtl/control.sv:234-238`, `rtl/control.sv:255`, `rtl/instruction_fetch.sv:95-97`; the vector is a constant and not the `mtvec` CSR (`G-01`) | Assert `exception` for one cycle between two known instructions; the next fetched address is the trap vector and no register write from a discarded instruction is observed. An instruction already past decode still completes (`G-01`). | `F-08`, `BLK-CTL`, `BLK-IF` | partial |
| FR-23 | The core shall report the interrupted instruction address and a trap cause to software in `mepc` and `mcause`. | `rtl/control.sv:257-268` | A CSR read returns the interrupted address and the ratified cause code after a trap. The registers exist but are unreadable, because no CSR instruction is decoded and no CSR port exists (`G-01`, `G-02`, `G-13`). | `F-08`, `F-09`, `BLK-CTL` | deferred |
| FR-24 | An instruction whose encoding is outside the implemented subset of §4.1 shall raise an illegal-instruction trap instead of executing as a no-operation. | `rtl/instruction_decode.sv:238-247` pre-loads a no-write default and the decode case has no trap arm, so an unmatched encoding retires silently; `rtl/instruction_decode.sv:325` ignores every function bit but bit 5, so the `M` group aliases onto the base ALU (`G-06`) | For every family the §4.1 conformance table names as trapping — an unknown opcode, an unimplemented `funct3`, an unimplemented `funct7`, the whole `M` group, and a CSR encoding before `Zicsr` lands — one directed instruction enters the handler at the `mtvec` base with the illegal-instruction cause, and no register write or memory access from it is observed (`G-06`, `G-13`). Decided 2026-10-28 (`Q-05`); the row stays `deferred` until the RTL traps. | `F-01`, `F-09`, `BLK-ID` | deferred |
| FR-25 | `ECALL` and `EBREAK` shall raise a trap. | `rtl/instruction_decode.sv:333-335` decodes the system opcode as a no-operation (`G-06`) | `ECALL` and, in a separate run, `EBREAK` each enter the handler at the `mtvec` base and neither retires as a no-operation; the cause each reports distinguishes it from the other traps, with the exact set fixed by `Q-04`, still open (`G-06`, `G-13`). Decided 2026-10-28 (`Q-05`); the row stays `deferred` until the RTL traps. | `F-01`, `F-09`, `BLK-ID` | deferred |
| FR-26 | `FENCE` shall order memory accesses as the ratified ISA requires. | `rtl/instruction_decode.sv:330-332` decodes `FENCE` as an empty case, so no ordering is performed (`G-06`) | `FENCE` between a store and a dependent load preserves program order at the data port, and a `FENCE` between two stores preserves theirs. The blocking, single-outstanding interface is not accepted as a substitute: `Q-15` (2026-10-28) chose the ratified ordering semantics, so a no-operation is not admissible in any configuration (`A-13`). Phase 1; the row is `deferred` because the decoder orders nothing, not because the obligation was undecided. | `F-01`, `BLK-ID`, `BLK-CTL` | deferred |
| FR-27 | The core shall request instruction memory one whole cache line at a time, as a single request that carries the line address, the beat count and a valid qualifier, and accept the line as a burst of exactly the requested number of beats that ends on a last-beat indication on its final beat, with no transaction identifier and no separate read-data channel. | there is no burst as built: `rtl/instruction_fetch.sv:63-77` drives one word address per cycle and no last-beat signal exists (`G-15`) | A memory model that asserts last-beat on the final beat of the line sees exactly one request per line instead of one per word, with the beat count of the fixed 32-byte line (eight, `C-09`) and no identifier field; the next request follows at the line base plus the line size; and both observations repeat for a build with `ICACHE_BYTES` = 0. The memory delivers exactly the requested beat count: a burst that ends before it, or that runs past it, is a protocol error, must not load a partially valid line into the cache, and shall be flagged by the monitor (`Q-21`). Burst shape confirmed 2026-10-28 (`Q-13`, `A-10`), phase 1. | `F-04`, `F-10`, `BLK-IF`, `G-15` | deferred |
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
| FR-41 | The core shall assert its active-low reset asynchronously when `rst_n` goes low and shall release it synchronously, after `RESET_SYNC_STAGES` enabled clock edges, with the reset style selected by a global macro so that a synchronous FPGA build is possible. | `rtl/instruction_fetch.sv:69` and `rtl/instruction_fetch.sv:84` (and the five other sequential modules) write `always_ff @(posedge clk or negedge rst_n)`: assertion is asynchronous but release is not synchronised, and no style macro exists (`G-21`) | Pull `rst_n` low between two clock edges: every architectural register is reset without a clock edge. Release it with `clk_en` high: no architectural state changes before `RESET_SYNC_STAGES` edges (2 by default) have elapsed, and no register captures a value from the release edge. Elaborate with the synchronous-style macro and repeat: `rst_n` is then sampled only on the clock and the same program produces the same architectural result. Phase 1, `D-09`. | `F-07`, `BLK-IF`, `BLK-CTL`, `D-09`, `G-21` | partial |
| FR-42 | The core shall complete an access whose effective address crosses a word boundary as two word-aligned transactions: the first covering the bytes below the boundary, the second at `base + 4`, with the value reassembled on a load, the byte strobes recomputed for the second beat on a store, and the pipeline held until both beats are granted. Such an access is not atomic. | no split logic exists: `data_addr = alu_ma` drives one access per instruction (`rtl/riscv_small.sv:119`), `data_wr` is `rs2` unchanged (`rtl/riscv_small.sv:193`), and there is no address increment and no strobe recomputation (`G-22`) | A halfword load at an odd address whose halfword spans words N and N+1 produces two accesses, one per word, the second at `base + 4`; the register receives the two bytes from each transaction assembled in address order before extension. The same `SH` drives both words with strobes computed per beat, and a word access at `base + 2` behaves the same way in both directions. Exactly one instruction retires for the pair, and an interrupt raised between the two beats is taken between them, which is what "not atomic" means here (`A-05`). Phase 1. | `F-03`, `BLK-MA` | deferred |

Notes on the rows above:

- `FR-22` is reconstruction of an existing mechanism, not a claim that the vector or the cause is correct:
  the vector is a constant (`G-01`) and the cause register is tied low (`G-02`). Its target successor is
  `FR-29`, and `FR-22` stays until the CSR path replaces the constant.
- `FR-09` and `FR-10` are the only rows a test observes. `T-01` checks stores directly; the load result is
  checked only through the value that is subsequently stored, which is why `FR-09` and not only `FR-10` can
  be marked `verified`.
- Every as-built row is `implemented`, `partial` or `verified` unless its Status column says `deferred`;
  nothing in the repository observes any of them, and `G-04` explains why the existing scoreboard cannot. The
  `partial` rows are the ones a named gap narrows, and each cites it in the Evidence cell.
- `FR-20` and `FR-21` describe today's per-word fetch and load-only stall. They are not withdrawn, because
  the RTL still does this; the target rows `FR-27`, `FR-28` and `FR-38` supersede them for the product, and
  `A-03` is retired.
- `FR-26` is the row the elicitation round promoted from "unspecified" to a phase-1 obligation with ratified
  semantics; it did not need a new ID, so it keeps `FR-26` and changes text and acceptance only. `Q-15`
  (2026-10-28) settled the semantics as full ordering, so the row is `deferred` because the decoder orders
  nothing, not because the obligation was open.
- Rows `FR-27`..`FR-40` were written after the 2026-10-28 round. They are `deferred` because no RTL exists,
  not because the intent is doubtful: each names the phase in its acceptance text.
- `FR-41` was written in round 4 and is the only requirement that is not as-built and still `partial`: the
  asynchronous assertion half is what `rtl/` already does, while the synchronised release and the style macro
  do not exist (`G-21`). It is in §4 rather than §5 because a reset that releases at a different time changes
  what software observes, not only how the core is built.
- `FR-42` is the round-5 row: splitting a word-crossing access into two word-aligned transactions. It is
  `deferred` because nothing in `rtl/` increments the address or recomputes strobes (`G-22`), and it is the row
  that makes `A-05`'s guarantee implementable rather than a promise the memory has to absorb. `FR-13` keeps
  the address formation and points here for what happens after it.
- `FR-06`..`FR-08` are `partial`: they hold for forward offsets only, because the jump/branch target adds an
  unsigned `imm[20:0]` (`G-20`). `G-19` records a write-back that a load-use freeze can suppress, which is why
  `FR-17` is `partial` too.
- `FR-07`, `FR-11` and `FR-12` state the intended behaviour since v0.3.1: `FR-07` continues at
  `(rs1 + imm) & ~1`, and `FR-11`/`FR-12` select the addressed lane before writing or extending. All three are
  `partial`, because the RTL does not conform yet (`G-07`, `G-08`, both release blockers).
- `FR-11` and `FR-12` are `partial`, not `implemented`: `Q-06` restated their clauses as intent, and the RTL
  never uses `data_addr[1:0]` to pick a lane — the store path drives the lowest lane and the load path reads
  `data.s_bytes[0]`/`s_half[0]` (`G-08`, a release blocker). A requirement whose clause the RTL contradicts is
  not `implemented`; the earlier v0.3.1 draft of this note said the opposite and is superseded here.
- `FR-24`, `FR-25` and `FR-27` were decided in round 2 and stay `deferred`: a decision is not an
  implementation, and no test observes them. `FR-24` and `FR-25` move to `implemented` only when the decoder
  traps, `FR-27` only when the fetch issues a line request.

### 4.1 Decoded instruction subset: as built, and phase-1 conformance

The first table is what `rtl/instruction_decode.sv` actually decodes today. It is **not** the target ISA of §7.1
and it is not what `README.md` claims. The second table is the obligation that `FR-24` and `FR-25` put on the
same decoder: it names the encodings that must **not** execute, and each row is what a phase-1 conformance
suite has to observe.

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

Phase-1 conformance: the encodings below are outside the implemented subset, so `FR-24` requires each of them
to trap. The middle column is what happens today, and is the reason the row exists.

| Encoding family | As built today | Phase-1 obligation | Governed by |
|---|---|---|---|
| an opcode with no decode arm | no register write, no memory access, and no trap | illegal-instruction trap | `FR-24` |
| `0110011` with `funct7` other than `0000000` and `0100000`, including the whole `M` group (`funct7` `0000001`) | executes as the base ALU operation of the same `funct3` | `M` executes once it lands in phase 1 (`D-07`); until then, illegal-instruction trap — never an alias onto the base ALU | `FR-24`, `D-07` |
| `0010011` with a non-zero `funct7`, other than `0100000` on `funct3` `101` | the extra function bits are ignored, so the shift or immediate executes | illegal-instruction trap | `FR-24` |
| `1100111` (`JALR`) with `funct3` other than `000` | accepted on the I-type immediate path | illegal-instruction trap | `FR-24` |
| `1100011` with `funct3` `010` or `011` | falls to the not-taken default | illegal-instruction trap | `FR-24` |
| `0000011` with `funct3` `011`, `110` or `111` | falls to the full-word load | illegal-instruction trap | `FR-24` |
| `0100011` with `funct3` `011`..`111` | the low two bits still drive the width output | illegal-instruction trap | `FR-24` |
| `0001111` with `funct3` other than `000` (`fence`) and `001` (`fence.i`) | no operation | illegal-instruction trap | `FR-24` |
| `1110011` `ECALL` and `EBREAK` | no operation | a trap that is not a no-operation, with a cause that distinguishes it from the other traps | `FR-25` |
| `1110011` CSR encodings | no operation | once `Zicsr` lands in phase 1, the CSRs the requirements name are implemented and every other CSR access traps | `FR-23`, `FR-29`, `FR-37` |
| a compressed encoding (low two bits other than `11`) | not decoded at all: the 32-bit word is decoded on its `opcode` field | illegal-instruction trap until `C` lands in phase 1 | `FR-24`, `D-07` |

Absent entirely from the decoder: RV32M (`funct7 = 0000001` shares opcode `0110011` and therefore
**aliases onto the base ALU operations**), RV32A, RV32C, RV32F/D, `Zicsr`, `Zifencei`, and every supervisor or
hypervisor encoding (`G-06`). `M` and `C` are nevertheless part of the target ISA in phase 1 (`D-07`), which
is why the gap, not the decoder, is the open item; `Q-05` (2026-10-28) fixed the obligation — every family in
the conformance table traps until its own requirement implements it, and nothing is silently a no-operation.

## 5. Non-functional requirements

No timing, area, power, or coverage number exists anywhere in the repository. Rows that need one carry
`TBD` and a gap; the rows whose target is countable (a pass/fail bar) state it and name the gap that blocks
it. The dates are the date by which the owner must supply a number, not a target value. v0.2 moved every
`TBD` date to 2026-12-31, the deadline agreed in the 2026-10-28 round; no number was invented.

Round 3 (`Q-08`, `Q-09`, `Q-10`) settled the four `TBD` rows as **measure first, then fix the number**: for
`NFR-01`..`NFR-04` the measurement method is normative and the number is not — a report with a measurement in
it is the deliverable, and a frequency, a CPI, an area or a power figure becomes a requirement only after that
report exists. `NFR-05` and `NFR-06` are the opposite case: their bar is a decision, `Q-11` confirmed it, and
the gaps that block it are release blockers.

| ID | Requirement (shall) | Target | Condition | Method | Traces to | Status |
|---|---|---|---|---|---|---|
| NFR-01 | The core shall report the clock frequency its first synthesis achieves, and the part it was achieved on, before any frequency target is recorded. | TBD(designer, 2026-12-31) — no frequency and no target part are recorded, and none may be until the first report exists (`A-08`, `Q-08`) | worst-case slow corner, for each named configuration of §5.2 | post-implementation static timing report: achieved Fmax, worst negative slack over all paths, and the part; the measured number then becomes the `NFR-01` target | `G-05` | deferred |
| NFR-02 | The core shall report the cycles it takes to run one named benchmark kernel, before any throughput target is recorded. | TBD(designer, 2026-12-31) — no CPI or kernel target is recorded until the measurement exists (`Q-09`) | kernel and memory latency model fixed, instruction cache enabled | cycles retired over cycles spent, counted in simulation on the named kernel; the measured value then fixes the target | `G-05` | deferred |
| NFR-03 | The core shall report the resources its first synthesis consumes, with and without the instruction cache, before any area target is recorded. | TBD(designer, 2026-12-31) — no area budget is recorded until the report exists (`Q-10`) | default synthesis settings, target part | post-synthesis resource or gate-count report, at `ICACHE_BYTES` = 0 and 2048 | `G-05` | deferred |
| NFR-04 | The core shall report the power its implementation consumes under a named activity vector, with and without the instruction cache, before any power budget is recorded. | TBD(designer, 2026-12-31) — no power budget is recorded until the report exists (`Q-10`) | activity from a named simulation vector | post-implementation vector-based power analysis, at `ICACHE_BYTES` = 0 and 2048 | `G-05` | deferred |
| NFR-05 | The core shall pass every applicable `rv32ui-p-*` test of the bundled RISC-V test suite. | 0 failures over the applicable subset — the signoff bar, confirmed 2026-10-28 (`A-09`, `Q-11`) | Vivado XSim, images generated by the sanity-test flow; the applicable subset is fixed by §7.1 phase 1 | compile each test image, simulate it, record pass or fail per test; `G-10` blocks the flow today | `G-04`, `G-10` | deferred |
| NFR-06 | Functional coverage shall close on the instruction set and memory behaviour it claims. | every `FR` row `verified`, one functional-coverage bin per decoded instruction of §4.1 and one per memory width — the signoff bar, confirmed 2026-10-28 (`A-09`, `Q-11`) | covergroup populated and sampled by the regression | coverage report from `xcrg` or IMC, with uncovered bins enumerated | `G-03`, `G-04`, `G-11` | deferred |
| NFR-07 | The core shall synthesise with no inferred latches and no combinational loops. | 0 latches, 0 loops | default synthesis settings, target part, every named configuration | synthesis and lint report | `G-05` | deferred |

## 5.1 Constraints

| ID | Constraint | Origin | Impact |
|---|---|---|---|
| C-01 | One clock domain; the reset input is active-low `rst_n`; the reset style is hybrid — asynchronous assertion, de-assertion synchronised inside the core through `RESET_SYNC_STAGES` flops (`FR-41`, `D-09`). | `D-09`; today `rtl/riscv_small.sv:41-43`, `rtl/instruction_fetch.sv:84-87` have no synchroniser (`G-21`) | the integrator drives `rst_n` directly and does not add a second synchroniser; de-assertion timing is the core's responsibility (`FR-41`) |
| C-02 | A top-level clock-enable input exists, but in the current RTL it reaches only the trap-state registers; the pipeline is not gated by it. | `rtl/riscv_small.sv:223`, `rtl/control.sv:262` | pausing `clk_en` does not pause the core (`G-12`) |
| C-03 | Instruction and data memories are external ports; no cache and no memory are instantiated inside the core today. | `rtl/riscv_small.sv:45-57` | memory latency and behaviour are the integrator's contract (`A-01`, `A-10`); the target adds an instruction cache inside the core (`D-04`, `C-08`) |
| C-04 | Simulation and elaboration are Vivado XSim 2024.1 or newer, driven by CMake and `make`. | `README.md`, `CMakeLists.txt` | no other simulator is targeted or checked |
| C-05 | The default DUT top is `riscv_small` and the default verification top is `riscv_small_tb`. | `srclist/riscv_small.srclist`, `CMakeLists.txt` | port names and widths are fixed by these files |
| C-06 | `NUM_HARTS` shall be a synthesis parameter of the main configuration package with legal values 1, 2 and 4 and default 1; the hart identifier shall be an input, not a parameter. | `D-03` | one RTL serves one, two or four harts (`FR-33`); the SoC must wire each instance's identity; elaboration fails on any other value |
| C-07 | `ENABLE_A` shall gate the `A` extension, default 0 in phase 1, and elaboration shall fail when `NUM_HARTS > 1` and `ENABLE_A = 0`. | `D-03`, `D-06` | an SMP build cannot be produced without atomics; `misa` follows the parameter (`FR-37`). `ENABLE_A` = 0 is the default for every phase-1 configuration, `MCU_RTOS` included, because the MVP RTOS masks interrupts for its critical sections and needs no atomics (`Q-20`, 2026-10-28); `A` stays phase 2 and `MCU_SMP` is the only named configuration that sets it to 1, a default that flips only if Zephyr becomes the target |
| C-08 | `ICACHE_BYTES` shall select the instruction cache size from 0, 1024, 2048 and 4096 bytes, default 2048; the value 0 shall remove the cache; elaboration shall fail when `ICACHE_BYTES > 0` and `Zifencei` is not enabled. | `D-04` | a cache that software cannot invalidate is not buildable (`FR-31`); `ICACHE_BYTES = 0` is the flash-resident build |
| C-09 | `ICACHE_LINE` shall be 32 bytes (8 words) in phase 1 and shall not be independently tunable. | `D-04`, `A-11` confirmed 2026-10-28 (`Q-14`) | the fill burst length follows from the line size (`FR-27`); a different line size is a new variant, not a knob |
| C-10 | `M` and `C` shall always be enabled and shall not be parameters. | `D-07` | every toolchain target emits them; `misa` reports them on unconditionally (`FR-37`) |
| C-11 | A compiled binary shall be valid only for the configuration it was built for; nothing is binary-portable across `NUM_HARTS`, `ENABLE_A` or `ICACHE_BYTES`. | `D-05` accepted and `A-12` confirmed 2026-10-28 (`Q-16`) | releases are named per variant; a test run must state the configuration it exercised |
| C-12 | Register `x0` shall read as all zeros and every write to it shall be discarded, because volume I §1.1.1 says "Register `x0` is hardwired with all bits equal to 0"; a load with `rd = x0` shall still raise the exceptions its access would raise and still cause its side effects, per volume I §1.1.6. | normative rule, RISC-V ISA v20260120 vol. I §1.1.1 and §1.1.6; replaces retired assumption `A-02` (`Q-22`) | this is not a project choice and not tunable at synthesis; `FR-14` is its test |

## 5.2 Configuration

The parameters below are the whole configuration surface of the product. Every legal combination is formed
from these five; the three named configurations after the table are the ones this specification uses
elsewhere. A configuration is chosen at synthesis and is not discoverable at run time except through `misa`
(`FR-37`).

| Parameter | Legal values | Default | Effect on behaviour | Constraint |
|---|---|---|---|---|
| `NUM_HARTS` | 1, 2, 4 | 1 | number of harts the design instantiates; each hart sees the same core and a distinct identifier | `C-06`, `FR-33` |
| `ENABLE_A` | 0, 1 | 0 | the `A` extension (Zaamo and Zalrsc) is present and advertised only when 1 | `C-07`, `FR-35`, `FR-37` |
| `ICACHE_BYTES` | 0, 1024, 2048, 4096 | 2048 | instruction cache capacity; 0 removes the cache, so no fetch can hit | `C-08`, `FR-27`, `FR-31` |
| `ICACHE_LINE` | 32 | 32 | cache-line size in bytes, hence the fill burst length; fixed in phase 1 and not independently tunable | `C-09`, `FR-27` |
| `RESET_SYNC_STAGES` | integer ≥ 2 | 2 | number of clock-enable flops the reset de-assertion passes through before the core sees a release, so it sets the release latency (`FR-41`) | `C-01`, `FR-41` |

| Named configuration | `NUM_HARTS` | `ENABLE_A` | `ICACHE_BYTES` | Product it serves |
|---|---|---|---|---|
| `MCU_MIN` | 1 | 0 | 0 | smallest area, code executed in place from fast memory, no cache |
| `MCU_RTOS` | 1 | 0 | 2048 | the MVP: a preemptive RTOS on one hart (`D-01`, `D-04`), with `ENABLE_A` = 0 because the RTOS masks interrupts instead of using atomics (`Q-20`) |
| `MCU_SMP` | 4 | 1 | 2048 | the SMP milestone (`D-02`); `NUM_HARTS` = 2 is the same configuration with fewer harts |

Elaboration shall reject an illegal configuration rather than silently substitute a default:

| Check | Fails elaboration when | Source |
|---|---|---|
| hart count | `NUM_HARTS` is not 1, 2 or 4 | `C-06` |
| atomics with multiple harts | `NUM_HARTS > 1` and `ENABLE_A = 0` | `C-07` |
| cache without invalidation | `ICACHE_BYTES > 0` and `Zifencei` is not enabled | `C-08` |
| line size | `ICACHE_LINE` is not 32 | `C-09` |
| reset synchroniser depth | `RESET_SYNC_STAGES` is less than 2, which would not be a synchroniser | `FR-41` |

None of these checks exists in the RTL today: there is no configuration package, no cache, and no `A`
(`G-13`, `G-15`, `G-16`). The table is the target of the parameters, and §7.1 says which phase each one lands in.

A question that used to sit outside the table, and no longer does, is the cache-less build: `ICACHE_BYTES` = 0
keeps the same line-based instruction interface, so removing the cache changes capacity and hit behaviour but
not the integrator's memory model (`Q-13`, `A-10`, `FR-27`).

## 6. Interfaces (summary)

One row per external interface, with the contract this specification promises; the interface catalogue is in
`doc/uarch.md` section 4.1 and the full port table in section 4.4. The `Status` column separates the contract as built from the contract the product
intends, because a reader of a specification should not have to guess which one is being described.

| Interface | Direction | Summary (target) | Contract | Status |
|---|---|---|---|---|
| Instruction memory | master | line address, burst request and valid, beat count, beat data, beat valid, last-beat | a whole cache line is fetched per request, as one request carrying the line address, the beat count and a valid qualifier, and the burst ends on last-beat (`FR-27`); no transaction identifier and no separate read-data channel; a cache-less build uses the same line interface; an outstanding fetch is never lost and its address stays stable (`FR-28`) | target: line fill; as built it is one word per cycle with a per-word ready (`FR-20`, `G-15`) |
| Data memory | master | `data_addr[31:0]`, `data_wr[31:0]`, `data_wr_strb[3:0]`, `data_rd_wr_ctrl[1:0]`, `data_rd_en`, `data_wr_en`, `data_rd[31:0]`, `data_ready` | `data_addr` is a byte address and the memory takes its word address from `data_addr[31:2]`; the core places the store data in the addressed lane of `data_wr` and asserts `data_wr_strb[3:0]` for exactly the bytes it drives, so the memory never shifts, justifies or masks data (`FR-11`, `Q-28`); on a load the memory returns the aligned word and the core selects the byte or halfword lane and extends it (`FR-12`); an access that crosses a word boundary is split into two word-aligned transactions by the core, and is therefore not atomic (`FR-42`, `Q-29`, `A-05`); a load or a store completes on the grant at the clock edge and there is no write-response channel (`FR-21`, `FR-38`); the contract must survive a later D-cache or TCDM | today: seven of the eight signals, no `data_wr_strb`, one access per instruction; the grant, the strobes, the lane selection and the split are targets (`G-08`, `G-18`, `G-22`) |
| Hart identity | input | hart identifier value | `mhartid` reads the input (`FR-32`); no other result depends on it | absent (`G-16`) |
| Interrupt requests | input | machine timer and machine external interrupt requests | each is taken as a trap with its own cause (`FR-39`, `FR-40`); phase 2 adds a machine software request (`FR-36`) | absent; the level-sensitive `exception` input is the only request today (`rtl/riscv_small.sv:44`) |
| Trap vector | — | none — the vector is software state | `mtvec` supplies the entry address, direct or vectored (`FR-29`, `FR-30`) | no port by decision (`D-08`); today the address is a constant inside the core (`G-01`) |
| Control | input | `clk`, `clk_en`, `rst_n`, `exception` | one clock domain; `rst_n` is active-low and asserts asynchronously, de-assertion is synchronised inside the core through `RESET_SYNC_STAGES` (`C-01`, `FR-41`, `D-09`) | assertion as built; the synchroniser is absent (`G-21`, `C-02`, `G-12`) |

**The data-lane contract, stated once.** `data_addr` is a byte address, and `data_addr[1:0]` selects the lane
inside the word; the memory takes the word address from `data_addr[31:2]`. The **core**, not the memory, does
the lane work. On a store the core places the value in the addressed lane of `data_wr` and asserts
`data_wr_strb[3:0]` for exactly the bytes it drives, so the memory applies the strobes as given and never
shifts, justifies or masks a store. On a load the memory returns the aligned word and the core selects the
byte or halfword out of it and extends it (`FR-11`, `FR-12`). An access that crosses a word boundary is not
sent to the memory as one access: the core issues two word-aligned transactions and reassembles the value,
which is how `A-05`'s EEI guarantee is discharged (`FR-42`, `Q-29`). Byte strobes are what the maintained open
cores converge on — PicoRV32's `mem_wstrb[3:0]`, Ibex's `data_be_o[3:0]` with a word-aligned address, and
CV32E40P's OBI byte enables — so this port follows them rather than masking from the address and the width
signal (`Q-28`).

The DUT exposes fifteen external signals today — four to the instruction memory, seven to the data memory and
four control — and the target data port adds `data_wr_strb[3:0]`, which makes sixteen.

The handshake of the instruction port is fixed by `FR-27` and `FR-28` and was confirmed on 2026-10-28: the
simple form — one request per line, a beat count, a valid, and a last-beat flag on the final beat — with no
identifiers and no separate read-data channel (`Q-13`, `A-10`). The memory delivers exactly the requested beat
count, and a short burst is a protocol error, not a shorter line (`Q-21`). The beat-level timing (how many
cycles each beat may take, and when `valid` is first sampled) is not yet specified; it is a microarchitecture
question for `doc/uarch.md`, not a requirement here.

## 7. Compliance and ISA scope

Two columns, because the v0.1 rows were written when only one answer existed. "As built" is what the RTL
does; "target" is what §7.1 commits to and by when.

| Item | As built | Target | Evidence |
|---|---|---|---|
| RV32I arithmetic, logic, shift, upper-immediate, jump, branch, load, store | partial — exactly the subset in §4.1 | complete in phase 1 | `rtl/instruction_decode.sv:247-336`, `G-06` |
| RV32I `FENCE` | no — executes as a no-operation | ordering in phase 1 (`FR-26`) | `G-06`, `A-13` |
| RV32I `ECALL` / `EBREAK` | no — executes as a no-operation | trap in phase 1 (`FR-25`), decided 2026-10-28 (`Q-05`) | `G-06`, `G-13` |
| RV32I illegal-instruction exception | no — unimplemented encodings execute as no-operations | trap in phase 1 (`FR-24`), decided 2026-10-28 (`Q-05`); the encodings that must trap are listed in §4.1 | `G-06`, `G-13` |
| RV32I misaligned-access exception | no — addresses are passed to the memory unchecked | **EEI guarantee**: full misaligned support, so no exception is raised and the core splits the access into two word-aligned transactions (`FR-42`, volume I §1.1.6, `A-05`) | `A-05` |
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
The normative reference for every row is the latest **ratified** specification (`D-08`) — for this revision,
RISC-V ISA v20260120 volume I and volume II; RVM23 and CLIC are drafts and are advisory only. Nothing is
advertised in `misa` before it is implemented (`FR-37`). Rows whose content the standard fixes cite the
volume and section; rows the standard leaves open say so and record a project decision (`D-09` is the first).

| Extension | Why | Phase | Status today |
|---|---|---|---|
| `I` (RV32I base) | the instruction set the toolchain targets | 1 | partial: the subset of §4.1, with `G-06` (no illegal-instruction trap), `G-07` (`JALR`) and `G-08` (sub-word lanes); `Q-06` (2026-10-28) fixed both deviations, so `G-07` and `G-08` are release blockers |
| `M` | fixed on (`D-07`); multiply and divide without a helper library | 1 | absent: the encodings alias onto the base ALU (`rtl/instruction_decode.sv:323-329`, `G-06`) |
| `C` | fixed on (`D-07`); code size for a small MCU | 1 | absent: not decoded (`G-06`) |
| `Zicsr` | required for `mtvec`, the trap CSRs, `mhartid` and `misa` | 1 | absent: `CSR*` is a no-operation (`rtl/instruction_decode.sv:333-335`, `G-13`) |
| `Zifencei` | `fence.i` makes the cache coherent with stores (`D-04`); with the cache it is also the only standard mechanism by which a store becomes visible to a later fetch on the same hart | 1 | absent: `fence.i` is a no-operation (`G-06`, `G-15`). `Q-27` (open) asks whether phase 2 keeps `Zifencei` as the fetch-side mechanism or replaces it with some other coherence guarantee; the phase-1 obligation of `FR-31` does not depend on the answer |
| `Zicntr` | a tick source that does not consume a timer peripheral | 1 | absent (`G-13`) |
| Machine trap architecture: `mtvec`, `mepc`, `mcause`, `mstatus`, `mtval`, `mscratch`, `mret` | trap entry and return, the precondition for any RTOS | 1 | partial: an entry mechanism with a constant vector and a cause tied to zero, and no CSR visibility (`G-01`, `G-02`, `G-13`) |
| Machine timer interrupt (`MTIP`) | the preemption tick of `D-01` | 1 | absent (`G-14`) |
| Machine external interrupt (`MEIP`) | device service without polling | 1 | absent (`G-14`) |
| `A`: Zaamo + Zalrsc | atomics for harts that can race (`D-06`); the MVP RTOS masks interrupts in its critical sections instead and needs none (`Q-20`, `C-07`) | 2 | absent (`G-16`) |
| Machine software interrupt (`MSIP`, IPI) | cross-hart wake-up and scheduling in SMP | 2 | absent (`G-14`, `G-16`) |
| `mhartid` with `NUM_HARTS > 1` | hart identification (`D-03`) | 2 | absent (`G-16`) |
| `Zihpm`, `S`/`U` mode, Sv32 MMU, `F`, `D`, `V`, debug, trace | outside the product scope (§1) | — | absent; no requirement is made |

## 8. Traceability summary

- Forward index: the `Traces to` column of §4 and §5 (requirement to block and to test).
- Reverse index: [verification.md](verification.md).
- Verified today: `FR-09`, `FR-10` to `T-01`.
- Orphans (`implemented` or `partial`, no observing test): `FR-01` to `FR-08`, `FR-11` to `FR-22` and
  `FR-41`, all to `G-04` except `FR-41`, which nothing observes and which `G-21` records as half-implemented.
  The single root cause for the rest is that the reference model and scoreboard understand only `LW` and `SW`.
- Unimplemented as-built requirements: `FR-23`, `FR-24`, `FR-25`, `FR-26` (`G-01`, `G-02`, `G-06`, `G-13`);
  and every `NFR-01` to `NFR-07` (`G-03`, `G-04`, `G-05`, `G-10`). Of these, `FR-24`, `FR-25` and `FR-26` are
  decided but not implemented (`Q-05`, `Q-15`, 2026-10-28): the decisions are recorded in §4.1 and §4, the
  statuses stay `deferred`.
- Target requirements with no implementation: `FR-27`, `FR-28`, `FR-31`, `FR-34` (`G-15`); `FR-29`,
  `FR-30`, `FR-32`, `FR-37` (`G-13`); `FR-39`, `FR-40` (`G-14`); `FR-33`, `FR-35`, `FR-36` (`G-16`);
  `FR-38` (`G-18`); `FR-42` (`G-22`).
- Release blockers: `G-03`, `G-04`, `G-07`, `G-08`, `G-10`, `G-11` (`Q-06`, `Q-11`). Everything else in §9 is
  an owner's commitment with a 2026-12-31 target (`Q-12`), not a blocking condition.
- `T-02` is registered but adds no new stimulus, so nothing cites it (`G-11`).
- Every target row from `FR-27` to `FR-40` names its phase in the acceptance text, so a reader can tell a
  phase-1 gap from a phase-2 commitment without leaving this document; the as-built `deferred` rows
  (`FR-23` to `FR-26`) inherit their phase from §7.1.

## 9. Assumptions, gaps, and open questions

### Assumptions

`A-01` to `A-07` were inferred in v0.1 from the RTL or the testbench. `A-08` to `A-16` were the proposed
defaults of the 2026-10-28 rounds, each naming what changes if it is wrong. Status is `open` while the point is
unconfirmed, `confirmed` once the designer has settled it, and `superseded` when a later answer replaced it — a
superseded row is kept, never renumbered, and must not be cited.

After round 4 only two rows are still `open`: `A-17` (which trap causes must be distinguishable, `Q-04`) and
`A-18` (how fetch-side ordering is guaranteed once the cache lands, `Q-27`). Every other row is `confirmed`, or
`superseded` in the case of `A-02` (retired into `C-12`, because `x0` is an ISA rule and not an assumption) and
`A-03` (retired into `FR-27`/`FR-28`). Note what changed in round 4: three of these rows were not confirmed as
written but rewritten against the normative text, and `A-06` was rewritten against a project decision. A
confirmed row is therefore a settled obligation, not a rubber stamp on the v0.1 wording.

| ID | Statement | Owner | Method | Due | If false | Status |
|---|---|---|---|---|---|---|
| A-01 | The data memory asserts the grant in the cycle its read data is valid, and the core may stall indefinitely while the grant is withheld. | integrator | protocol review against `rtl/control.sv:246-251` | 2026-12-31 | `FR-21` is wrong and every load gains or loses a wait state (`G-09`) | confirmed 2026-10-28 for loads (answer 6); the store half moved to `FR-38` |
| A-02 | **Retired 2026-10-28, do not cite.** `x0` is not an assumption: volume I §1.1.1 makes it a rule, now recorded as constraint `C-12` (`Q-22`). | designer | retired by the normative citation; the rule lives in `C-12` | — | nothing is lost: `FR-14` keeps its acceptance and `C-12` adds the `rd = x0` side-effect obligation | superseded (retired into `C-12`) |
| A-03 | **Superseded 2026-10-28, do not cite.** The instruction memory presents data and ready in the same cycle as the address, so a fetch has zero latency. | integrator | replaced by the line-fill contract | 2026-12-31 | nothing is lost by retiring it: the replacement is `FR-27` (a line per fill) and `FR-28` (a real stall), and `G-09` became a prerequisite rather than a doubt | superseded |
| A-04 | After reset, the state the hardware defines is only what privileged volume II §2.1.4 lists: machine mode, `MIE` = 0, `MPRV` = 0, `MBE` = 0, `misa` maximal, no valid load reservation, `pc` at the implementation-defined reset vector, `mcause` holding the reset cause, and PMP entries with `A` = 0 and `L` = 0. Everything else is UNSPECIFIED — the same section says "All other hart state is UNSPECIFIED" — so no general-purpose register has a defined value at reset and no register-file reset value is a contract. Software shall initialise every register it reads before reading it; zeroing the file is permitted but nothing may rely on it. | designer | normative citation, RISC-V ISA v20260120 vol. II §2.1.4; answered 2026-10-28 (`Q-23`) | 2026-12-31 | a test that reads an uninitialised register is a testbench bug, not a core defect; a design that does rely on a zeroed file has an unstated requirement | confirmed 2026-10-28 |
| A-05 | This execution environment (EEI) **guarantees** that misaligned loads and stores are fully supported, and raises no address-misaligned exception. Volume I §1.1.6 requires that naturally aligned accesses never raise one and makes misaligned behaviour EEI-dependent, adding that an EEI "may guarantee that misaligned loads and stores are fully supported"; this row is that guarantee. How it is discharged: an access that crosses a word boundary is split by the core into two word-aligned transactions, up to two beats, with the value reassembled on a load and the strobes recomputed on a store (`FR-42`, `Q-29`); such an access is **not atomic**, which the ISA states for misaligned accesses. Consequence for the integrator: the data memory only ever sees word-aligned addresses and byte strobes, and lane selection stays in the core (§6, `FR-11`, `FR-12`, `FR-42`). | integrator | normative citation, RISC-V ISA v20260120 vol. I §1.1.6; answered 2026-10-28 (`Q-24`), discharged by `Q-29` | 2026-12-31 | withdrawing the guarantee would require a misaligned-access trap and a cause, `FR-13` and `FR-42` would change, and the memory model would need a misaligned port | confirmed 2026-10-28 |
| A-06 | The reset is **hybrid**, and that is a project decision because the ISA says nothing about reset style: `rst_n` low asserts asynchronously, de-assertion is synchronised inside the core through `RESET_SYNC_STAGES` flops (default 2), and a global macro selects the style so an FPGA build can use a synchronous reset. The reason is the project's own RTL guidance: an asynchronous reset arriving from an external pin needs a synchroniser for de-assertion, and the two styles are already partitioned by a compile-time macro (`.opencode/skills/systemverilog-rtl-verification/references/reset-and-fsm.md`, "Global reset selection" and "Reset synchronizer"). Requirement `FR-41`; the as-built gap is `G-21`. | designer | project decision `D-09`, answered 2026-10-28 (`Q-25`, revised from the v0.1 assumption) | 2026-12-31 | the as-built async-assert/async-release reset stands, and a de-assertion that lands close to a clock edge can corrupt the first cycle of every stage | confirmed 2026-10-28 (revised) |
| A-07 | A single hart has one outstanding instruction fetch and one outstanding data access, and no ordering between the two ports is promised. This is a microarchitecture assumption and not an ISA rule: the standard constrains *ordering* (RVWMO, volume I chapter 17; `FENCE`, §1.1.7; `FENCE.I`, Zifencei chapter 4) and never the number of transactions in flight. What it is worth: a blocking, single-outstanding port trivially satisfies the single-hart ordering rules, and the normative obligation that remains is `FENCE` for data (`FR-26`) and `FENCE.I` for fetch versus data (`FR-31`). | designer | answered 2026-10-28 (`Q-26`); RISC-V ISA v20260120 vol. I ch. 17 and §1.1.7, Zifencei ch. 4 | 2026-12-31 | a pipelined memory interface would need its own ordering argument, and `A-15`'s no-coherence reading would have to be revisited | confirmed 2026-10-28 |
| A-08 | No clock-frequency target and no target part are recorded; the default is "unmeasured", not a frequency. What is fixed is the method: the first synthesis reports achieved Fmax and the part it was achieved on, and only then may a frequency become a requirement (`NFR-01`). | designer | answered 2026-10-28 (`Q-08`); the measurement is `NFR-01`'s method | 2026-12-31 | `NFR-01` keeps `TBD` and `G-05` stays open; no requirement changes | confirmed 2026-10-28 |
| A-09 | The signoff bar is: every `FR` row `verified`, one functional-coverage bin per decoded instruction and per memory width, and the applicable `rv32ui-p-*` images green. Ownership is fixed: the designer owns the spec and ISA gaps, the verification lead owns the DV gaps (`G-03`, `G-04`, `G-10`, `G-11`), and every target is 2026-12-31. `G-03`, `G-04`, `G-10` and `G-11` are release blockers, and every other gap is a dated commitment. | designer, verification lead | answered 2026-10-28 (`Q-11`, `Q-12`) | 2026-12-31 | `NFR-05` and `NFR-06` have no target and no gap has an owner; nothing can be called signoff | confirmed 2026-10-28 |
| A-10 | The instruction-fill burst is a simple request, length, valid and last-beat handshake in every configuration, not an AXI-style channel with identifiers and separate read-data beats, and a cache-less build keeps the same line interface. | designer | answered 2026-10-28 (`Q-13`) | 2026-12-31 | `FR-27` is re-written against the chosen protocol, the interface summary in §6 changes shape, and the integrator needs two memory models | confirmed |
| A-11 | The instruction cache line is 32 bytes, eight words, in phase 1. | designer | answered 2026-10-28 (`Q-14`) | 2026-12-31 | the fill length in `FR-27` and the parameter row for `ICACHE_LINE` in §5.2 change together | confirmed |
| A-12 | A compiled binary is valid only for the configuration it was built for; `NUM_HARTS`, `ENABLE_A` and `ICACHE_BYTES` are not binary-portable. | designer | answered 2026-10-28 (`Q-16`), which also accepted `D-05` | 2026-12-31 | a single binary must run on every variant, so `ENABLE_A` and `NUM_HARTS` need run-time discovery and `misa` becomes mandatory in phase 1 | confirmed |
| A-13 | `fence` carries full ordering semantics: the core shall order its memory accesses as the ratified ISA requires, and a no-operation implementation is not admissible. The answer of 2026-10-28 chose ordering over the conditional no-op that an earlier draft allowed, so no written justification can discharge `FR-26`; it is a phase-1 requirement, and the row stays `deferred` only because the RTL performs no ordering. | designer | answered 2026-10-28 (`Q-15`) | 2026-12-31 | a written argument could have discharged `FR-26`; that route was withdrawn on 2026-10-28, so ordering machinery is the only way the row can leave `deferred` | confirmed 2026-10-28 |
| A-14 | The interrupt controller is the ratified CLINT (timer) plus PLIC (external), and CLIC is not used, consistently with `D-08`. | designer | answered 2026-10-28 (`Q-17`) | 2026-12-31 | the core keeps its `MTIP`/`MEIP` obligation but the SoC-level integration and the vectored question in `FR-30` are re-opened | confirmed |
| A-15 | There is no data cache in any phase, so shared memory needs no coherence protocol, and inter-hart ordering is limited to what fences and atomics provide. | designer | answered 2026-10-28 (`Q-17`), confirming `D-04` at SoC level | 2026-12-31 | a coherence or TCDM protocol becomes a requirement and `FR-35` changes | confirmed |
| A-16 | Every hart leaves reset at the same fetch address and the core does not designate a boot hart; hart selection is done by software or by the SoC. | designer | answered 2026-10-28 (`Q-18`) | 2026-12-31 | the core needs a boot-hart mechanism and `FR-33` gains a clause | confirmed |
| A-17 | `mepc` and `mcause` are the registers software reads after a trap (`FR-23`), and each cause the requirements name is distinguishable, but the complete set of causes that must be distinguished is not fixed; it is what `Q-04` is still asking. Until it is answered, no requirement names a cause the rows above do not already name. | designer | open question `Q-04` (partly answered 2026-10-28) | 2026-12-31 | `FR-23`'s acceptance cannot name the full cause set, so a trap handler that dispatches on `mcause` is written against a partial contract | open |
| A-18 | The fetch side of ordering can be discharged by `Zifencei` in phase 2 rather than by a coherence protocol: once the instruction cache lands, `FENCE.I` is the only standard mechanism by which a store becomes visible to a later fetch on the same hart. `Q-27` asks whether phase 2 keeps `Zifencei` in the ISA surface or guarantees fetch coherence some other way. | designer | open question `Q-27` (raised 2026-10-28 by the `Q-26` answer) | 2026-12-31 | the phase-2 ISA surface changes and `FR-31`'s successor needs a coherence requirement the specification does not have | open |

### Gaps

The canonical gap table, with owners and targets, is in `doc/verification.md`. Rows introduced or reframed in
this revision: `G-01` and `G-02` now name `mtvec` and `mcause` as their targets; `G-09` changed from "a doubt
about the fetch handshake" to "the prerequisite for the instruction cache", because with a 2 kB cache a miss
is the normal case and the core must be able to hold its program counter. New rows: `G-13` (no CSR file), `G-14`
(no interrupt subsystem), `G-15` (no cache and no line fetch), `G-16` (no multi-hart support), `G-17` (no
decision log), `G-18` (stores ignore the data grant).

Round 2 (2026-10-28) reframed two more. `G-07` (`JALR` leaves bit 0 of the target set) and `G-08` (a sub-word
access always uses the lowest lane) are **release blockers**: `Q-06` fixed both deviations, so phase 1 cannot
sign off while either is open, even though neither has an RTL change yet (`FR-07`, `FR-11`, `FR-12`).
`G-06` also narrowed — from "unimplemented encodings are unspecified" to "the §4.1 conformance list is not
implemented", which is what `Q-05` fixed.

Rounds 3 and 4 (2026-10-28) closed the gap list. `Q-11` made `G-03`, `G-04`, `G-10` and `G-11` **release
blockers** alongside `G-07` and `G-08`; `Q-12` fixed an owner and a 2026-12-31 target for every other row, so
the `Owner` and `Target` columns of `doc/verification.md` are commitments and not proposals — stated once here
and not repeated per row. `Q-15` narrowed `G-06` again, to the data side only: the `FENCE` obligation is now a
phase-1 requirement (`FR-26`) and the fetch side belongs to `FR-31` and `Q-27`. `Q-25` introduced `G-21`, the
first gap this document has opened against a requirement it wrote itself, and round 5 added `G-22` the same
way: the data port of §6 promises strobes and a split that `rtl/` does not have, so the interface summary and
the RTL now disagree in a place `G-08` only hinted at.

| Gap | Statement | Impact on this document |
|---|---|---|
| `G-04` | Only `LW`/`SW` are model-checked. | 20 as-built rows cannot become `verified`; a **release blocker** since `Q-11` |
| `G-06` | Unimplemented encodings execute as no-operations. | `FR-24` to `FR-26` stay `deferred`; the §4.1 conformance list is the obligation that closes it (`Q-05`); since `Q-15` the `FENCE` part is a phase-1 requirement and only the decode gap remains; §7 marks RV32I partial; `M` and `C` cannot be claimed in phase 1 while the aliasing lasts |
| `G-07` | `JALR` does not clear bit 0 of the target address. | a release blocker since `Q-06` (2026-10-28); `FR-07`'s acceptance decides it |
| `G-08` | Sub-word accesses always use the lowest lane. | a release blocker since `Q-06` (2026-10-28); `FR-11` and `FR-12` state the intended behaviour since v0.3.1 and their acceptance decides the lane |
| `G-09` | No fetch stall exists; the program counter advances while the grant is withheld. | prerequisite for `G-15`: a cache cannot stall a core that cannot stall; `FR-28` is the requirement that closes it |
| `G-13` | No CSR file and no CSR instruction. | `FR-23`, `FR-29`, `FR-30`, `FR-32`, `FR-37` stay `deferred` |
| `G-14` | No machine-mode interrupt subsystem: no timer, no external controller, no software interrupt. | `FR-39`, `FR-40`, `FR-36`, and the vectored mode of `FR-30`, stay `deferred` |
| `G-15` | No instruction cache and no line-based fetch; `ICACHE_BYTES` and `ICACHE_LINE` do not exist. | `FR-27`, `FR-28`, `FR-31`, `FR-34` stay `deferred`; §5.2 is a target, not a description |
| `G-16` | No multi-hart support: no hart-identity input, no `NUM_HARTS`, no `A` extension. | `FR-32`, `FR-33`, `FR-35`, `FR-36` stay `deferred`; `MCU_SMP` cannot be built |
| `G-17` | No decision log: `doc/decisions.md` does not exist, so `D-01` to `D-09` live in §0.1. | decisions are not indexed beside the requirements they justify |
| `G-18` | Stores do not wait for the data grant: the stall condition needs a load destination. | `FR-38` stays `deferred`; the store contract is the testbench's, not the core's |
| `G-19` | A load-use freeze also disables the register-file write. | a WB commit can be lost; `FR-17` is `partial` because of it, and no registered test observes it |
| `G-20` | The jump/branch target adds an unsigned 21-bit immediate slice. | backward control transfers are wrong; `FR-06`, `FR-07` and `FR-08` are `partial` for that reason, and hold for forward offsets only |
| `G-21` | No reset synchroniser and no reset-style macro: every sequential block hardcodes `always_ff @(posedge clk or negedge rst_n)` (`rtl/instruction_fetch.sv:69`, `rtl/instruction_fetch.sv:84`, `rtl/control.sv:257`, and four more modules), so assertion and release are both asynchronous. | `FR-41` is `partial`: half the requirement is as-built and half is absent; the fix is the synchroniser and the style macro of `D-09` |
| `G-22` | The data port has no byte strobes and no second-beat logic: `data_wr_strb` does not exist in the port list (`rtl/riscv_small.sv:52-57`), `data_addr = alu_ma` drives one access per instruction (`rtl/riscv_small.sv:119`), `data_wr` is `rs2` unchanged (`rtl/riscv_small.sv:193`), and there is no address increment or strobe recomputation anywhere, so a store cannot be lane-placed and a misaligned access cannot be split. | `FR-11` is `partial` (lane and strobes absent) and `FR-42` stays `deferred`; the port change of `Q-28` and the split of `Q-29` are both unbuilt |

### Open questions

The interview ledger is [spec-questions.md](spec-questions.md). Twenty-seven questions are answered and one is
partly answered (`Q-04`); one remains open (`Q-27`). The table below is the whole of it — if a question is not
here, it is answered and its artifact is named in §0.2 to §0.6.

| Topic | Open question | Owner | Status |
|---|---|---|---|
| trap causes | `Q-04` — what software shall be able to read after a trap; the `mepc`/`mcause` names are fixed, the set of causes that must be distinguished is not | designer | open — partly answered 2026-10-28; carried by `A-17` |
| fetch-side ordering | `Q-27` — once the instruction cache lands, does the phase-2 ISA surface keep `Zifencei` as the mechanism that makes a store visible to a later fetch, or is fetch coherence guaranteed another way | designer | open — raised 2026-10-28 by the `Q-26` answer; carried by `A-18` |

Answered in round 3 on 2026-10-28: `Q-08` (measure, then set the frequency — `NFR-01`, `A-08`), `Q-09`
(measure a named kernel — `NFR-02`), `Q-10` (report resources and power — `NFR-03`, `NFR-04`), `Q-11` (the
`A-09` signoff bar — `NFR-05`, `NFR-06`, release blockers), `Q-12` (gap ownership — `A-09`, §2), `Q-15`
(`fence` is full ordering — `FR-26`, `A-13`) and `Q-21` (a short burst is a protocol error — `FR-27`, §6).

Answered in round 4 on 2026-10-28, against the normative text: `Q-22` (`x0` — volume I §1.1.1, now `C-12`),
`Q-23` (reset state — volume II §2.1.4, now `A-04`), `Q-24` (misaligned EEI guarantee — volume I §1.1.6, now
`A-05` and the §6 lane contract), `Q-25` (reset style, a project decision — `D-09`, `FR-41`, `G-21`) and `Q-26`
(ordering, not transaction count — `A-07`).

Answered in round 5 on 2026-10-28, against maintained open cores: `Q-28` (byte strobes on the data port, with
the core placing the value — §6, `FR-11`, `G-22`) and `Q-29` (splitting a word-crossing access into two
word-aligned transactions — `FR-42`, `A-05`, `G-22`).

Answered in round 2 on 2026-10-28 and no longer open here: `Q-05` (unimplemented encodings trap — `FR-24`,
`FR-25`, §4.1), `Q-06` (both ISA deviations fixed — `FR-07`, `FR-11`, `FR-12`, `G-07`, `G-08`), `Q-13` (burst
shape — `FR-27`, §6), `Q-14` (32-byte line — `C-09`, §5.2), `Q-16` (one binary per configuration — `D-05`,
`C-11`), `Q-17` (CLINT plus PLIC — `A-14`, `A-15`), `Q-18` (same reset address for every hart — `A-16`) and
`Q-20` (`ENABLE_A` = 0 for `MCU_RTOS` — `C-07`, §5.2, §7.1). Round 1 and the closed items are `Q-01`, `Q-02`,
`Q-03`, `Q-07` and `Q-19`.

## 10. References

- ISA: *The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA*, **v20260120** (RV32I, `Zicsr`,
  `Zifencei`, `Zicntr`, `M`, `C`, `A`) — the normative edition for this revision (`D-08`); §1.1.1 (`x0`),
  §1.1.6 (misaligned accesses and `rd = x0`), §1.1.7 (`FENCE`) and chapter 17 (RVWMO) are cited above.
  Drafts are advisory only.
- Privileged: *The RISC-V Instruction Set Manual, Volume II: Privileged Architecture*, **v20260120**:
  `mtvec`, `mepc`, `mcause`, `mstatus`, `mie`, `mip`, `mtval`, `mscratch`, `mret`, `mhartid`, `misa`, and §2.1.4
  for the state defined at reset.
- Microarchitecture: [uarch.md](uarch.md) — blocks `BLK-IF`, `BLK-ID`, `BLK-EX`, `BLK-MA`, `BLK-CTL`, `BLK-REG`, `BLK-ALU`, `BLK-JMP`.
- Reset guidance: `.opencode/skills/systemverilog-rtl-verification/references/reset-and-fsm.md` — "Global reset
  selection" and "Reset synchronizer", the source of `D-09`.
- Verification: [verification.md](verification.md) — tests `T-01`, `T-02`, gaps `G-01` to `G-21`.
- Interview ledger: [spec-questions.md](spec-questions.md).
- Conflict resolution: when this document and the RTL disagree, open a gap; do not silently edit either.
