# riscv-small — Specification Question Ledger

| Field | Value |
|---|---|
| Status | open — 5 closed, 1 partial, 14 open |
| Version | v0.2 |
| Owner | TBD(designer, 2026-12-31) |
| Baseline | commit `bb789bb` (v0.1, as-built); v0.2 adds the 2026-10-28 round |
| Mode | **elicitation** for round 1; **reconstruction** for the questions v0.1 raised from the RTL |

v0.1 was reverse-engineered from the RTL, so every row asked the designer to confirm or overturn a decision
the RTL had already made implicitly. The first elicitation round ran on 2026-10-28 and closed four of those
questions, overturned one proposed default, and raised seven new ones about the product the answers describe.
Questions are ordered by risk: the first ones change what a test would have to observe, the last ones change
paperwork.

How to answer: a one-word "yes" accepts the **proposed default** and converts it into a confirmed decision,
constraint, or requirement; anything else replaces it. One answer per question; a question that needs a second
question gets one, in the next round. An answered row keeps its ID and its text, and its status records the
date and the artifact it produced. A question with a proposed default still open is carried by an `A-xx` in
`doc/spec.md` §9, so the specification is never silent while the answer is pending.

## Ledger

| ID | Question | Proposed default | If accepted | Risk | Owner | Asked | Status |
|---|---|---|---|---|---|---|---|
| Q-01 | Does the instruction memory always present data and ready in the same cycle as the address it is given? | Superseded by the round-1 answer: fetch fills per line, so the per-word zero-latency contract no longer applies. | `A-03` retired; `FR-27` (line fill) and `FR-28` (a real stall) replace it; `G-09` became a prerequisite for the cache | high | integrator | 2026-10-27 | answered 2026-10-28 (answer 3) |
| Q-02 | Is a store complete when the core asserts the write strobe, with no write acknowledgement from the data memory? | No — a transfer completes on the data memory's grant at the clock edge, for a store as well as a load, and there is no write-response channel. | `FR-21` keeps the load half as built; `FR-38` carries the store half as target; `A-01` confirmed for loads; `G-18` opened | high | integrator | 2026-10-27 | answered 2026-10-28 (answer 6) |
| Q-03 | What should determine the address the core continues at after a trap? | The `mtvec` CSR, per the ratified privileged specification; no vector input port. | `FR-29` (direct) and `FR-30` (vectored) record it; `G-01` gets a target; the port question is closed in `D-08` | high | designer | 2026-10-27 | answered 2026-10-28 (answer 7) |
| Q-04 | What shall software be able to read after a trap? | The interrupted address and the cause in `mepc` and `mcause` (names fixed by `D-08`); the exact set of causes that must be distinguished is still open. | `FR-23` keeps its text with `mepc`/`mcause` named; `G-02` and `G-13` remain the blockers | high | designer | 2026-10-27 | open — partly answered 2026-10-28 |
| Q-05 | Shall an instruction outside the decoded subset raise a trap instead of executing as a no-operation? | Yes — unimplemented encodings, including `ECALL`, `EBREAK`, CSR and multiply encodings, raise an illegal-instruction trap. | `FR-24`, `FR-25` and `G-06` move forward; the §4.1 table becomes a conformance list; phase 1 of §7.1 needs it for `M` and `C` | high | designer | 2026-10-27 | open |
| Q-06 | Shall the two known ISA deviations be fixed before signoff: `JALR` not clearing bit 0 of the target, and sub-word accesses always using the lowest lane? | Yes — both are fixed, so the core follows the ISA rather than the current RTL. | `G-07` and `G-08` close; `FR-07`, `FR-11`, `FR-12` keep their text and gain acceptance criteria | medium | designer | 2026-10-27 | open |
| Q-07 | Is any trap source other than the level-sensitive `exception` input in scope for this revision? | Overturned by round 1: preemption requires a timer and, for SMP, an inter-processor interrupt, so interrupts are in scope. Phase 1 takes the timer and external requests; phase 2 takes the software request. | `FR-39` and `FR-40` added for phase 1; `FR-36` added for phase 2; `G-14` opened; §1 non-goals narrowed to the choice of controller | high | designer | 2026-10-27 | answered 2026-10-28 (answer 1) |
| Q-08 | What clock frequency must the core close timing at, on which part? | No number is recorded yet; `NFR-01` stays `TBD` and `G-05` stays open until a value and a target part are named. Carried by `A-08`. | `NFR-01` stays `deferred`; the default is "unmeasured", not a frequency | medium | designer | 2026-10-27 | open |
| Q-09 | What throughput must the core reach, measured on which workload? | No CPI or benchmark target is recorded yet; the first step is to report measured cycles for one named kernel, then set a target. | `NFR-02` stays `TBD`; the method is fixed even though the number is not | medium | designer | 2026-10-27 | open |
| Q-10 | What are the area and power budgets for the core? | No budget is recorded yet; report post-synthesis resources and vector-based power first, with and without the cache, then set a budget. | `NFR-03` and `NFR-04` stay `TBD`; `G-05` remains the dependency | medium | designer | 2026-10-27 | open |
| Q-11 | What is the signoff bar: which tests and which coverage must pass before the core is called done? | Every `FR` row `verified`, one functional-coverage bin per decoded instruction and per memory width, and the applicable `rv32ui-p-*` images green. Carried by `A-09`. | `NFR-05` and `NFR-06` get a target; `G-03`, `G-04`, `G-10`, `G-11` become release blockers | medium | verification lead | 2026-10-27 | open |
| Q-12 | Who owns each open gap, and by when? | The designer owns the spec and ISA gaps (`G-01`, `G-02`, `G-05`, `G-06`, `G-07`, `G-08`, `G-09`, `G-12`, `G-13`, `G-14`, `G-15`, `G-16`, `G-17`, `G-18`); the verification lead owns the DV gaps (`G-03`, `G-04`, `G-10`, `G-11`); all targets 2026-12-31. Carried by `A-09`. | every gap row in `doc/verification.md` becomes a commitment instead of a proposal, which is the precondition for `reviewed` | low | designer | 2026-10-27 | open |
| Q-13 | What shape does the instruction-fill burst have: a simple request, length, valid and last-beat handshake, or an AXI-style channel with identifiers and separate read data? And does a cache-less build keep the same line interface? | The simple handshake — one request per line, a length field, and a last-beat flag on the final beat — and the line interface stays for every `ICACHE_BYTES` value. Carried by `A-10`. | `FR-27` and the interface summary in §6 keep their shape; a protocol with identifiers, a shared bus, or a word-mode variant of the cache-less build rewrites `FR-27` and the `ICACHE_BYTES` row | high | designer | 2026-10-28 | open |
| Q-14 | What is the instruction cache line size? | 32 bytes, eight words, fixed in phase 1. Carried by `A-11`. | `C-09`, the `ICACHE_LINE` parameter row, and the fill length in `FR-27` agree; a different line size is a new variant | medium | designer | 2026-10-28 | open |
| Q-15 | Does `fence` need real ordering hardware, or may it be a no-operation justified by a blocking, single-outstanding memory interface? | Full ordering semantics. A no-operation is acceptable only if the interface is single-outstanding and blocking **and** the justification is written into `FR-26`; until it is, `FR-26` stays `deferred`. Carried by `A-13`. | `FR-26`'s acceptance is fixed and `G-06`'s scope for `FENCE` is narrowed; a no-op without the written justification leaves the row `deferred` | medium | designer | 2026-10-28 | open |
| Q-16 | Is a binary per configuration accepted, so that `NUM_HARTS`, `ENABLE_A` and `ICACHE_BYTES` need not be binary-portable? | Yes — one binary per variant, `D-05` accepted. Carried by `A-12`. | `C-11` stands; if refused, `misa` becomes mandatory in phase 1 and every variant must discover its configuration at run time | high | designer | 2026-10-28 | open |
| Q-17 | Which interrupt controller delivers the timer and external requests: the ratified CLINT plus PLIC, or the draft CLIC? | CLINT plus PLIC, consistent with `D-08`; CLIC is not used. Carried by `A-14`; `A-15` records that no data cache means no coherence protocol. | the SoC integration and the vectored-mode scope in `FR-30` are fixed; CLIC would re-open both and contradict `D-08` | medium | designer, integrator | 2026-10-28 | open |
| Q-18 | How do the secondary harts start: does every hart leave reset at the same address, or does hardware designate a boot hart? | Every hart leaves reset at the same fetch address; the core designates no boot hart and software or the SoC selects it. Carried by `A-16`. | `FR-33` stands as written; a hardware boot-hart mechanism adds a clause to `FR-33` and an input to the interface summary | medium | integrator | 2026-10-28 | open |
| Q-19 | What was item 5 of the 2026-10-28 round, and what was the answer? | Item 5 was the `fmax`/part question and item 8 was the signoff bar; neither was answered, and both are already tracked as `Q-08`, `Q-11` and `Q-12`. No separate decision exists. | nothing new to record: the round had eight items, answers covered 1-4, 6 and 7, and the two missing ones are the existing rows above | low | designer | 2026-10-28 | answered 2026-10-28 — bookkeeping only |
| Q-20 | Does the MVP RTOS require atomics, forcing `ENABLE_A=1` in `MCU_RTOS`, or is FreeRTOS-style single-core (interrupt masking) the target? | `ENABLE_A=0` for `MCU_RTOS`: the MVP RTOS masks interrupts for critical sections and does not need `A`; `A` stays in phase 2. If the target is Zephyr, whose atomic paths use `lr/sc`, the default flips to `ENABLE_A=1` and `MCU_RTOS` absorbs the `A` area. | if `=1`, `FR-35` moves to phase 1 for the `MCU_RTOS` configuration and `C-07` needs a phase column; if `=0`, `MCU_SMP` remains the only configuration that carries `A` | high | designer | 2026-10-28 | open |

## Resolutions of round 1, in prose

These paragraphs exist so the reasoning survives next to the questions; the identifiers below are not
re-defined here, only cited.

**Answer 1 (RTOS mode).** The designer made the software model a build choice and the hardware obligation a
preemption source. That overturned `Q-07`'s proposed default of "no interrupts" and produced two phase-1
requirements, the timer and the external interrupt, plus the phase-2 inter-processor interrupt.

**Answer 2 (instruction cache).** A 2 kB direct-mapped cache became the default build, with no data cache in
any phase. It produced the `ICACHE_BYTES` and `ICACHE_LINE` constraints and, indirectly, the retirement of
`A-03`: a cache whose fill is missed cannot coexist with a core that cannot hold its program counter.

**Answer 3 (line fill).** Fetch became line-oriented. `FR-20` is kept as the description of today's RTL and
`FR-27`/`FR-28` became the contract the product promises; `Q-01` closed against the new contract.

**Answer 4 (hart count).** `NUM_HARTS` became a parameter of the main configuration package with default 1,
and the hart identifier an input. That is what makes `FR-32` and `FR-33` testable without recompiling
identity into the netlist.

**Answer 5.** Item 5 was the `fmax` and target-part question, and item 8 was the signoff bar. Neither was
answered in the round; they remain `Q-08`, `Q-11` and `Q-12`. Nothing new is recorded for item 5, so `Q-19`
closes as bookkeeping.

**Answer 6 (data grant).** The store acquired the same grant handshake as the load, and the write-response
channel was ruled out. `Q-02` closed, `A-01` was confirmed for loads only, `FR-38` was added for stores, and
`G-18` records that the RTL does not yet wait.

**Answer 7 (trap vector).** The vector became software state (`mtvec`), which made `Zicsr` and the machine
trap CSRs mandatory in phase 1 and closed `Q-03`.

## Doubts I could not resolve

These are not questions to the designer; they are findings a designer should look at, because the RTL may be
doing something nobody meant.

1. **Fetch pairing.** The program counter advances on every cycle in which the IF/ID registers are not held,
   and only those registers are flushed while the fetch grant is withheld (`rtl/control.sv:241-243`,
   `rtl/instruction_fetch.sv:69-103`). Read literally, a fetch that is not granted is lost and the next fetch
   is accepted with the following address. Nothing in `tb/` observes the instruction/address pairing for a
   PC-relative instruction, so `AUIPC`, `JAL` and every branch are unchecked in exactly the place where this
   would show. Round 1 settled the contract (a line fill, and a stall that keeps the address) but not the
   defect: `FR-28` is the requirement, `G-09` is the finding, and the RTL still has the behaviour.
2. **Dead trap state.** The interrupted address and cause are registered but no path reads them back
   (`rtl/control.sv:257-268`) and no CSR instruction is decoded. Round 1 decided where the trap goes, so this
   is unfinished work rather than leftover scaffolding: `FR-23` is the requirement and `G-13` the blocker.
   One detail remains open inside `Q-04`: which causes must be distinguishable.
3. **Store grant.** The stall at `rtl/control.sv:246` needs a load destination, so a store pulses its strobe
   for one cycle whatever the memory does. Under the new grant contract the core must hold the store until it
   is granted; the difference is silent with the current testbench, which grants every access immediately
   (`G-18`).
4. **`x0` write discard versus register reset.** Writes to `x0` are dropped (`rtl/reg_file.sv:100-103`) while
   the whole file resets to `X` (`rtl/reg_file.sv:97`). Both are consistent, but the reset value is a choice,
   not a constraint; `A-04` records it and no question tests it.
5. **Width encoding has four values, three are used.** The width output is the low two bits of the
   instruction's `funct3` field (`rtl/riscv_small.sv:118`), so `011` and the encodings the decoder does not
   support can still reach the port. Whether the port should saturate or those encodings should trap is part
   of `Q-05`.
6. **`T-02` has no corner stimulus.** It is a factory override onto `T-01`'s sequence
   (`tb/tests/sequence_lib/riscv_small_corner_seq.sv:31`). It cannot be cited as evidence for anything until
   it generates boundary values (`G-11`).
7. **The clock enable does not enable the clock.** `clk_en` is documented as global, but it reaches only the
   trap-state register update (`rtl/riscv_small.sv:223`, `rtl/control.sv:262`). Legitimate for a core that
   never needs pausing; misleading for an integrator who expects to stop it (`G-12`).
8. **Provenance of round item 5.** The handover lists answers 1, 2, 3, 4, 6 and 7. Item 5 is absent from both
   the answer list and the list of remaining questions, so it is either lost or was never asked. `Q-19` asks.
9. **A load-use freeze also disables the register-file write.** The register file's clock enable is
   `id_ex_clk_en` (`rtl/instruction_decode.sv:195`, `rtl/riscv_small.sv:142`, `rtl/reg_file.sv:99`), and the
   load-use insertions clear it while leaving `ma_wb_clk_en` high (`rtl/control.sv:122`, `:158`, `:195`, `:219`).
   An instruction in WB during that cycle is not written and is then dropped from MA/WB. Not observed by `T-01`
   because the sequence spaces instructions. Recorded as `G-19`; found while writing `doc/uarch.md` §11.1.
10. **The branch/jump target adds an unsigned 21-bit immediate slice.** `jump_addr = base_addr + imm[20:0]`
    (`rtl/jump_decision.sv:111`) drops the sign extension, so a backward `JAL`, `JALR` or `B<cond>` lands at
    `base + (imm mod 2^21)`. Forward offsets within +2^20 work, which is why no test sees it. Recorded as
    `G-20`; found while writing `doc/uarch.md` §11.1.

## Stop rule

The round is closed when every question either has a recorded answer or is explicitly deferred with an owner
and a date. Until then `doc/spec.md` stays `draft` and no requirement may be upgraded from `implemented` to
`verified` on the strength of this ledger.
