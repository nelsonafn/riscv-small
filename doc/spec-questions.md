# riscv-small — Specification Question Ledger

| Field | Value |
|---|---|
| Status | closed — 42 answered, 0 open (round 7 and its checkpoint, 2026-10-28); the specification stays `draft` only because `NFR-01`..`NFR-04` are `TBD` by design |
| Version | v0.7 |
| Owner | designer (spec and ISA questions), verification lead (DV questions) — `Q-12` |
| Baseline | commit `bb789bb` (v0.1, as-built); v0.2..v0.7 record rounds 1-5, the round-6 conformance review and the round-7 scope decision, all of 2026-10-28 |
| Mode | **elicitation** for round 1; **reconstruction** for the questions v0.1 raised from the RTL |

v0.1 was reverse-engineered from the RTL, so every row asked the designer to confirm or overturn a decision
the RTL had already made implicitly. The first elicitation round ran on 2026-10-28 and closed four of those
questions, overturned one proposed default, and raised seven new ones about the product the answers describe.

Round 2 ran on 2026-10-28 on the eight highest-risk decisions still open. The designer accepted every proposed
default, so the rows below lose their `open` status without changing text, and the `A-10`..`A-16` assumptions that
carried them in `doc/spec.md` §9 move from `open` to `confirmed`. Seven questions remained: the three non-functional
targets (`Q-08`..`Q-10`), the throughput and signoff bar (`Q-11`), the ownership commitments (`Q-12`), the `fence`
semantics (`Q-15`), and the burst termination rule (`Q-21`, raised by the `Q-13` answer as the authors reconciled
`FR-27`).

Round 3 ran on 2026-10-28 and closed all seven, again by accepting every default. Three of them are the
non-functional targets: the designer chose **measure first, then fix the number** for frequency, throughput, area
and power, so `NFR-01`..`NFR-04` keep `TBD` but gain a measurement method, which is a requirement in its own right.
`Q-11` and `Q-12` confirm the signoff bar and every gap owner. `Q-15` fixes `fence` as full ordering, and `Q-21`
makes a short burst a protocol error, deleting the provisional 4-beat tolerance.

A closing round, `Q-22`..`Q-26`, exists only because the phase-2 gate requires every `A-xx` to be closed: five
assumptions date from the v0.1 reconstruction and were never put to the designer.

Round 4 was answered against the normative text rather than from memory: the designer asked what the standard says
and instructed that the specification follow it. RISC-V ISA v20260120 volume I §1.1.1 fixes `x0` at zero; privileged
volume II §2.1.4 makes **all other hart state UNSPECIFIED after reset**, so zeroing is permitted but cannot be a
contract; volume I §1.1.6 makes misaligned behaviour EEI-dependent and allows an EEI to guarantee full support,
which is the only reading under which this core may skip a misaligned trap; the ISA says nothing about reset style,
so `Q-25` records the project decision (async assertion, synchronised de-assertion) instead of a citation; and the
ISA constrains *ordering*, never the number of in-flight transactions, so `Q-26` is a microarchitecture statement
whose only normative obligation is `FENCE`/`FENCE.I`. That last point opened `Q-27`.

Round 5 was forced by the Phase 6 audit, which found the data port describing byte strobes it does not
have. `Q-28` settled who carries the byte-valid information and `Q-29` settled what happens to an access that
straddles two aligned words. Both were answered by asking what the maintained open cores do, not what a single
vendor decided: PicoRV32 (`mem_wstrb[3:0]`), Ibex (`data_be_o[3:0]`) and CV32E40P (OBI byte enables) all carry
byte strobes, so this port was the outlier; PicoRV32 raises a bus error on a misaligned access, while Ibex and
CV32E40P split it into two word-aligned transactions. The project took the strobe-plus-split route, which keeps
`A-05` and turns `G-08` into a concrete RTL fix.

Round 6 was not an interview: it was a conformance review of the whole requirement set against ISA v20260120, vol. I
and vol. II. It closed `Q-04` (the cause codes are fixed by vol. II Table 6/7, so there is nothing to choose) and
`Q-27` (`FENCE.I` is "the only standard mechanism", and `C-08` already puts `Zifencei` in phase 1, so the phase-2
premise was wrong). It also found three contradictions no earlier round had caught: `M` and `C` advertised in
`misa` with no requirement to execute them, `FR-24` trapping the mandatory `MRET` and `WFI`, and `A-05` promising
misaligned support the A extension forbids for LR/SC and AMO. It opened `Q-30`..`Q-35` for the choices the
standard leaves to the implementation.

Round 7 was not an interview either: the designer approved the defaults of `Q-30`..`Q-41` in one act, so the rows
record the decision rather than explore it. `Q-30` freezes `misa` as read-only and `Q-33` fixes the reset vector as
a parameter; `Q-35` chooses a cause bus beside the request plus separate timer, external and software inputs, which
is what lets `FR-48` name a cause at all. The same round put a boundary around the product: `S`/`U`-mode, the MMU,
`F`/`D` and `V` leave the scope, and `A-19` records the condition under which `S`/`U` would have to return — task
isolation, which needs protection and not paging. `Q-36`..`Q-41` then fixed the debug contract: external Debug
Module behind JTAG, the full hart-side debug interface, two `mcontrol6` triggers by default, a `dbg_auth` gate and `resethaltreq`, with a
watchdog NMI deferred to phase 2. The decision with the longest reach is `Q-37`: the core implements the hart side
of a standard interface and the DM implements the commands, so the RTL gains no proprietary debug protocol.
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
| Q-04 | What shall software be able to read after a trap? | The interrupted address and the cause in `mepc` and `mcause` (names fixed by `D-08`); the exact set of causes that must be distinguished is still open. | `FR-23` keeps its text with `mepc`/`mcause` named; `G-02` and `G-13` remain the blockers | high | designer | 2026-10-27 | answered 2026-10-28 (round 6 - the standard fixes the cause codes: vol. II Table 6/7; the residual port question split out as `Q-35`) |
| Q-05 | Shall an instruction outside the decoded subset raise a trap instead of executing as a no-operation? | Yes — unimplemented encodings, including `ECALL`, `EBREAK`, CSR and multiply encodings, raise an illegal-instruction trap. | `FR-24`, `FR-25` and `G-06` move forward; the §4.1 table becomes a conformance list; phase 1 of §7.1 needs it for `M` and `C` | high | designer | 2026-10-27 | answered 2026-10-28 (round 2 — default accepted) |
| Q-06 | Shall the two known ISA deviations be fixed before signoff: `JALR` not clearing bit 0 of the target, and sub-word accesses always using the lowest lane? | Yes — both are fixed, so the core follows the ISA rather than the current RTL. | `G-07` and `G-08` close; `FR-07`, `FR-11`, `FR-12` keep their text and gain acceptance criteria | medium | designer | 2026-10-27 | answered 2026-10-28 (round 2 — default accepted) |
| Q-07 | Is any trap source other than the level-sensitive `exception` input in scope for this revision? | Overturned by round 1: preemption requires a timer and, for SMP, an inter-processor interrupt, so interrupts are in scope. Phase 1 takes the timer and external requests; phase 2 takes the software request. | `FR-39` and `FR-40` added for phase 1; `FR-36` added for phase 2; `G-14` opened; §1 non-goals narrowed to the choice of controller | high | designer | 2026-10-27 | answered 2026-10-28 (answer 1) |
| Q-08 | What clock frequency must the core close timing at, on which part? | No number is recorded yet; `NFR-01` stays `TBD` and `G-05` stays open until a value and a target part are named. Carried by `A-08`. | `NFR-01` stays `deferred`; the default is "unmeasured", not a frequency | medium | designer | 2026-10-27 | answered 2026-10-28 (round 3 — default accepted) |
| Q-09 | What throughput must the core reach, measured on which workload? | No CPI or benchmark target is recorded yet; the first step is to report measured cycles for one named kernel, then set a target. | `NFR-02` stays `TBD`; the method is fixed even though the number is not | medium | designer | 2026-10-27 | answered 2026-10-28 (round 3 — default accepted) |
| Q-10 | What are the area and power budgets for the core? | No budget is recorded yet; report post-synthesis resources and vector-based power first, with and without the cache, then set a budget. | `NFR-03` and `NFR-04` stay `TBD`; `G-05` remains the dependency | medium | designer | 2026-10-27 | answered 2026-10-28 (round 3 — default accepted) |
| Q-11 | What is the signoff bar: which tests and which coverage must pass before the core is called done? | Every `FR` row `verified`, one functional-coverage bin per decoded instruction and per memory width, and the applicable `rv32ui-p-*` images green. Carried by `A-09`. | `NFR-05` and `NFR-06` get a target; `G-03`, `G-04`, `G-10`, `G-11` become release blockers | medium | verification lead | 2026-10-27 | answered 2026-10-28 (round 3 — default accepted) |
| Q-12 | Who owns each open gap, and by when? | The designer owns the spec and ISA gaps (`G-01`, `G-02`, `G-05`, `G-06`, `G-07`, `G-08`, `G-09`, `G-12`, `G-13`, `G-14`, `G-15`, `G-16`, `G-17`, `G-18`); the verification lead owns the DV gaps (`G-03`, `G-04`, `G-10`, `G-11`); all targets 2026-12-31. Carried by `A-09`. | every gap row in `doc/verification.md` becomes a commitment instead of a proposal, which is the precondition for `reviewed` | low | designer | 2026-10-27 | answered 2026-10-28 (round 3 — default accepted) |
| Q-13 | What shape does the instruction-fill burst have: a simple request, length, valid and last-beat handshake, or an AXI-style channel with identifiers and separate read data? And does a cache-less build keep the same line interface? | The simple handshake — one request per line, a length field, and a last-beat flag on the final beat — and the line interface stays for every `ICACHE_BYTES` value. Carried by `A-10`. | `FR-27` and the interface summary in §6 keep their shape; a protocol with identifiers, a shared bus, or a word-mode variant of the cache-less build rewrites `FR-27` and the `ICACHE_BYTES` row | high | designer | 2026-10-28 | answered 2026-10-28 (round 2 — default accepted) |
| Q-14 | What is the instruction cache line size? | 32 bytes, eight words, fixed in phase 1. Carried by `A-11`. | `C-09`, the `ICACHE_LINE` parameter row, and the fill length in `FR-27` agree; a different line size is a new variant | medium | designer | 2026-10-28 | answered 2026-10-28 (round 2 — default accepted) |
| Q-15 | Does `fence` need real ordering hardware, or may it be a no-operation justified by a blocking, single-outstanding memory interface? | Full ordering semantics. A no-operation is acceptable only if the interface is single-outstanding and blocking **and** the justification is written into `FR-26`; until it is, `FR-26` stays `deferred`. Carried by `A-13`. | `FR-26`'s acceptance is fixed and `G-06`'s scope for `FENCE` is narrowed; a no-op without the written justification leaves the row `deferred` | medium | designer | 2026-10-28 | answered 2026-10-28 (round 3 — full ordering accepted; the conditional no-op in the proposed default was **not** part of the accepted option, and `A-13` records its withdrawal) |
| Q-16 | Is a binary per configuration accepted, so that `NUM_HARTS`, `ENABLE_A` and `ICACHE_BYTES` need not be binary-portable? | Yes — one binary per variant, `D-05` accepted. Carried by `A-12`. | `C-11` stands; if refused, `misa` becomes mandatory in phase 1 and every variant must discover its configuration at run time | high | designer | 2026-10-28 | answered 2026-10-28 (round 2 — default accepted) |
| Q-17 | Which interrupt controller delivers the timer and external requests: the ratified CLINT plus PLIC, or the draft CLIC? | CLINT plus PLIC, consistent with `D-08`; CLIC is not used. Carried by `A-14`; `A-15` records that no data cache means no coherence protocol. | the SoC integration and the vectored-mode scope in `FR-30` are fixed; CLIC would re-open both and contradict `D-08` | medium | designer, integrator | 2026-10-28 | answered 2026-10-28 (round 2 — default accepted) |
| Q-18 | How do the secondary harts start: does every hart leave reset at the same address, or does hardware designate a boot hart? | Every hart leaves reset at the same fetch address; the core designates no boot hart and software or the SoC selects it. Carried by `A-16`. | `FR-33` stands as written; a hardware boot-hart mechanism adds a clause to `FR-33` and an input to the interface summary | medium | integrator | 2026-10-28 | answered 2026-10-28 (round 2 — default accepted) |
| Q-19 | What was item 5 of the 2026-10-28 round, and what was the answer? | Item 5 was the `fmax`/part question and item 8 was the signoff bar; neither was answered, and both are already tracked as `Q-08`, `Q-11` and `Q-12`. No separate decision exists. | nothing new to record: the round had eight items, answers covered 1-4, 6 and 7, and the two missing ones are the existing rows above | low | designer | 2026-10-28 | answered 2026-10-28 — bookkeeping only |
| Q-20 | Does the MVP RTOS require atomics, forcing `ENABLE_A=1` in `MCU_RTOS`, or is FreeRTOS-style single-core (interrupt masking) the target? | `ENABLE_A=0` for `MCU_RTOS`: the MVP RTOS masks interrupts for critical sections and does not need `A`; `A` stays in phase 2. If the target is Zephyr, whose atomic paths use `lr/sc`, the default flips to `ENABLE_A=1` and `MCU_RTOS` absorbs the `A` area. | if `=1`, `FR-35` moves to phase 1 for the `MCU_RTOS` configuration and `C-07` needs a phase column; if `=0`, `MCU_SMP` remains the only configuration that carries `A` | high | designer | 2026-10-28 | answered 2026-10-28 (round 2 — default accepted) |
| Q-21 | May the instruction memory end a line burst early with a last-beat before the requested beat count, or must it deliver exactly the beats it was asked for? The round-2 answer (`Q-13`) confirms both a length field and a last-beat flag, so the two can disagree. | Exactly the requested count: `last` marks the final requested beat, and a short burst is a protocol error that must not leave a partly valid line in the cache. | `FR-27`'s acceptance drops the 4-beat tolerance and requires the monitor to flag a short burst; a tolerant reading makes the line a variable-length object and needs a validity bitmap. | medium | integrator | 2026-10-28 | answered 2026-10-28 (round 3 — default accepted) |
| Q-22 | Is `x0` hardwired to zero with writes to it discarded, as a deliberate architectural choice? | Yes. Carried by `A-02`. | `A-02` becomes `confirmed`; a write-ignore implementation stays admissible, a writable `x0` invalidates every `FR` that names `x0` | low | designer | 2026-10-28 | answered 2026-10-28 (round 4 — confirmed, ISA v20260120 vol I §1.1.1: `x0` is hardwired to zero) |
| Q-23 | Are the general-purpose registers unspecified after reset, so software initialises every register it reads? | Yes. Carried by `A-04`. | `A-04` becomes `confirmed`; a testbench that reads an uninitialised register is a test bug, not a core bug | low | designer | 2026-10-28 | answered 2026-10-28 (round 4 — confirmed, priv vol II §2.1.4: all other hart state is UNSPECIFIED after reset) |
| Q-24 | Is address alignment the memory's responsibility, so misaligned loads and stores pass through unchanged? | Yes. Carried by `A-05`. | `A-05` becomes `confirmed`; the core raises no misaligned-access exception and `FR-13` keeps its pass-through acceptance | low | designer | 2026-10-28 | answered 2026-10-28 (round 4 — confirmed as an EEI guarantee, ISA vol I §1.1.6: misaligned behaviour is EEI-dependent, the EEI may guarantee full support) |
| Q-25 | Is the reset de-asserted synchronously by the integrator, so the core needs no reset synchroniser? | Yes. Carried by `A-06`. | **Superseded by the recorded answer —** an earlier draft had the integrator own the reset synchroniser; the answer moved it into the core (`FR-41`, `C-01`) | low | designer | 2026-10-28 | answered 2026-10-28 (round 4 — revised: hybrid reset, async assertion and synchronised de-assertion, per the RTL skill; the ISA is silent) |
| Q-26 | Does a single hart have one outstanding instruction fetch and one outstanding data access, with no ordering promised between the two ports? | Yes. Carried by `A-07`. | `A-07` becomes `confirmed`; the blocking, single-outstanding model is what makes the `fence` justification in `Q-15` decidable, so the two answers must agree | low | designer | 2026-10-28 | answered 2026-10-28 (round 4 — confirmed as microarchitecture; the ISA constrains ordering only: RVWMO ch.17, `FENCE` §1.1.7, `FENCE.I` Zifencei ch.4) |
| Q-27 | Once the instruction cache lands in phase 2, does the phase-2 ISA surface include `Zifencei` (`FENCE.I`), or is instruction-fetch coherence guaranteed some other way? `FENCE.I` is the only standard mechanism by which a store becomes visible to a later fetch on the same hart. | Implement `Zifencei` in phase 2: `FENCE.I` flushes the fetch pipeline and the instruction cache, and the opcode stops decoding as a no-op. | `FR-26` gains the fetch-side obligation, the phase-2 ISA surface becomes RV32I + M + A + Zicsr + Zifencei, and `G-06`'s `FENCE` scope splits into data-side and fetch-side; relying on "no cache" instead makes the answer conditional on a configuration. | high | designer | 2026-10-28 | answered 2026-10-28 (round 6 - Zifencei: FENCE.I is "the only standard mechanism"; with `ICACHE_BYTES > 0` it is required, and `C-08` already puts it in phase 1) |
| Q-28 | The data port has no byte strobes, so a byte or halfword store cannot say which bytes of `data_wr` are valid. Who carries that information? | Explicit `data_wr_strb[3:0]`: the core places the value in the addressed lane and asserts the strobes for the bytes it drives; the memory never shifts or justifies. | the port list grows to 16, `G-08` becomes a strobe-and-lane fix rather than a memory-model argument, and the interface summary in §6 stops describing a contract the DUT cannot implement | high | designer | 2026-10-28 | answered 2026-10-28 (round 5 — route 2, after checking the open cores: PicoRV32 `mem_wstrb[3:0]`, Ibex `data_be_o[3:0]`, CV32E40P OBI byte enables; all three use byte strobes, this port was the outlier) |
| Q-29 | Can an access that straddles two aligned words (halfword at an odd address, word at a non-word address) complete on a single word-wide port? `A-05` promises full support. | The core splits it into two word-aligned transactions, as Ibex and CV32E40P do; the address advances and the strobes are recomputed for the second beat, and the pipeline is held through both. | `A-05` survives unchanged, `FR-11`/`FR-12` gain the splitting acceptance, a new `FR-42` carries the split, and the alternative (trapping) would contradict the answer to `Q-24` | high | designer | 2026-10-28 | answered 2026-10-28 (round 5 — route 2; PicoRV32 traps instead, Ibex and CV32E40P split) |
| Q-30 | Is `misa` writable (WARL) or read-only? A writable `C` bit makes `IALIGN` change at run time, because clearing the bit reverts the extension to its defined or reserved behaviours (vol. II 2.1.1.1). | Read-only: `misa` reports the configuration and every write is ignored. The standard allows this: it is a WARL read-write register whose fields may be read-only. | `FR-37` gains the read-only clause and its acceptance tests that a write is ignored and does not trap; a writable variant would need a rule for `IALIGN` changing under a running pipeline | medium | designer | 2026-10-28| answered 2026-10-28 (round 7 — read-only accepted; `FR-37` gains the clause and `IALIGN` is therefore fixed by the built configuration) |
| Q-31 | Does `WFI` stall the hart or execute as a no-operation? Vol. II 2.1.3.3 permits either: a legal implementation is to simply implement WFI as a NOP. | No-operation: `WFI` retires immediately, and an interrupt taken afterwards sets `mepc` to the following instruction. | `FR-46` fixes the no-operation variant; the stall variant would add a halt state and a wake-up rule | low | designer | 2026-10-28| answered 2026-10-28 (round 7 — no-operation accepted; `FR-46` fixes immediate retirement and drops the wake-up rule) |
| Q-32 | Is `mtval` implemented with exception information, or read-only zero? Vol. II 2.1.1.16 allows read-only zero when the platform specifies that no exception sets it. | Read-only zero: the illegal-instruction handler decodes the instruction at `mepc` if it needs the encoding, which 2.1.1.16 names as the alternative. | The acceptance of `FR-24` drops the `mtval` check; an informative `mtval` adds a write port to the CSR file | low | designer | 2026-10-28| answered 2026-10-28 (round 7 — read-only zero accepted; `FR-52` records it and `FR-24` keeps no `mtval` check) |
| Q-33 | What is the implementation-defined reset vector, and is it a synthesis parameter? Vol. II 2.1.4 requires the `pc` to be set to an implementation-defined reset vector. | A `RESET_VECTOR` parameter, default `0x8000_0000`, with the first fetch at that address. | `FR-41` gains the clause, 5.2 gains the parameter row, and the boot image links at the same address | medium | designer | 2026-10-28| answered 2026-10-28 (round 7 — `RESET_VECTOR` parameter, default `0x8000_0000`; `FR-41` and §5.2 record it) |
| Q-34 | Does the product claim a RISC-V profile? If it claims RVA20 or RVA22, `Zicclsm` (misaligned loads and stores in cacheable coherent main memory) becomes mandatory, as do the profile conformance tests. | No profile: the ISA surface is exactly 7.1, `A-05` is an EEI guarantee, and no profile test suite is a release gate. | `A-05` and `NFR-05` keep their present scope; claiming RVA22 adds `Zicclsm`, `Zifencei` and the profile suite to the signoff bar | medium | designer | 2026-10-28| answered 2026-10-28 (round 7 — no profile claimed; `A-19` records the machine-mode-only scope and `NFR-05` keeps the ISA suites only) |
| Q-35 | How does the trap request carry its cause into `mcause`? The single level-sensitive `exception` input cannot name which cause occurred, and vol. II Table 6/7 assigns a distinct code to each. | A cause bus alongside the request: `exception[3:0]` carries the reason, and interrupts arrive on separate `mtip`/`meip`/`msip` inputs. | Adds at least one port, changes `FR-22`, `FR-39`, `FR-40` and `FR-48`, and adds a port outside the data-path sixteen in 6 | high | designer | 2026-10-28| answered 2026-10-28 (round 7 — cause bus plus separate `mtip`/`meip`/`msip`; `FR-22`, `FR-39`, `FR-40`, `FR-48` and §6 carry the port set) |
| Q-36 | How does the debug transport reach the hart: an external Debug Module behind a DTM, or a debug unit that lives inside the core? The RISC-V Debug Specification puts the abstract commands in the DM and leaves only the hart side in the core. | External DM plus a JTAG DTM, per the RISC-V Debug Specification: the core exposes the hart side of the debug interface and never JTAG pins. | `FR-54` and `FR-55` define the hart-side handshake, `C-13` and `D-10` record the choice, and §6 gains the debug port group. | high | designer | 2026-10-28 | answered 2026-10-28 (round 7 — approved: external DM plus JTAG DTM; `C-13` and `D-10` record it and §6 gains the debug group. Corrected the same day: the DMI is the DTM-to-DM link of Debug Spec v1.0 appendix A and is not a core port, so the core exposes the hart side of the debug interface instead — see `Q-37`) |
| Q-37 | Is the hart-side debug port the full interface the Debug Module needs, or a reduced halt-and-resume port with the abstract commands decoded inside the core? Note that the DMI itself is the DTM-to-DM link and stays outside the core while the DM is external (`Q-36`). | Full hart-side interface, per Debug Spec v1.0 ch. 3 and ch. 4: `dmactive`, `haltreq`, `resumereq`, `resethaltreq`, `ndmreset`, `halted`, `running`, `havereset` and `resumeack`, plus the abstract-command and program-buffer channel, so the external DM owns the commands and the registers. | `FR-54` and `FR-55` fix the register-level contract; a reduced port would move abstract-command decoding into the core and rewrite both rows. | high | designer | 2026-10-28 | answered 2026-10-28 (round 7 — approved: full hart-side interface; corrected the same day, because the DMI is the DTM-to-DM link of Debug Spec v1.0 appendix A and is therefore outside a core with an external DM. `ndmreset` is not one of the hart-side signals: it resets the platform, and the hart observes it through `rst_n`) |
| Q-38 | How many triggers does the hart implement, and of which type? | `NUM_TRIGGERS` of 0, 2 or 4, default 2, implementing only `mcontrol6` with PC, load/store address and data match. | `FR-57` fixes the type and the parameter, `Sdtrig` joins the debug phase, and `G-24` records the absent unit. | medium | designer | 2026-10-28 | answered 2026-10-28 (round 7 — approved: `NUM_TRIGGERS` 0/2/4, default 2, `mcontrol6` only) |
| Q-39 | Is there a hardware gate that can disable debug, so that a deployed part cannot be halted by an attached probe? | Yes: a `dbg_auth` strap; when it is low the hart ignores halt requests, never enters debug mode, and reports `dbg_halted` = 0. | `FR-59` and `C-14` record the gate, and the debug port gains one input. | high | designer | 2026-10-28 | answered 2026-10-28 (round 7 — approved: the gate is present, defaulting to enabled) |
| Q-40 | Must the DM be able to halt the hart out of reset, before the first instruction retires? | Yes: `resethaltreq` is supported, so the hart can be halted at the reset vector. | `FR-54` gains the clause and the reset sequence in `FR-41` must not preclude it. | medium | designer | 2026-10-28 | answered 2026-10-28 (round 7 — approved: `resethaltreq` supported) |
| Q-41 | Is a non-maskable interrupt (`Smrnmi`) required, for a watchdog that must preempt a masked machine interrupt? | No in this revision: the machine interrupt set stays the three maskable causes, and a watchdog NMI becomes a phase-2 obligation in §7.1. | `FR-48` keeps causes 3, 7 and 11 only; `Smrnmi` becomes a phase-2 row and the trap architecture does not change now. | medium | designer | 2026-10-28 | answered 2026-10-28 (round 7 — approved: phase 2, not this revision) |
| Q-42 | Where does `time`/`timeh` get its value? Vol. I §6.1 requires a 64-bit real-time counter and vol. II §2.1.1.11 notes that `time` shadows the memory-mapped `mtime`, while the DUT has no timer input. | A dedicated `mtime` input: the platform drives the 64-bit counter and the core exposes `time`/`timeh` as read-only views of it. | `FR-49` gains the port clause, §6 counts `mtime` outside the data-path sixteen, and the core needs no CSR-initiated memory access | medium | designer | 2026-10-28 | answered 2026-10-28 (checkpoint — dedicated `mtime` input accepted; `time`/`timeh` are views of it) |

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
   The cause set `Q-04` left open is fixed by vol. II Table 6/7, and how the request carries the cause is
   settled by `Q-35` (a cause bus beside the request); what is still missing is the CSR file itself.
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
