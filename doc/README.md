# riscv-small Documentation

| Document | Status | Scope |
|---|---|---|
| [spec.md](spec.md) | draft | features, functional and non-functional requirements, acceptance |
| [uarch.md](uarch.md) | draft | microarchitecture, 1:1 with the RTL |
| [verification.md](verification.md) | draft | traceability, test evidence, gaps, signoff gate |
| [measurements/](measurements/README.md) | draft | one file per non-functional requirement: method, date, result or `not measurable` |

## Reading order

1. `spec.md` — what the core promises.
2. `uarch.md` — how it is built.
3. `verification.md` — what is proven and what is not, and the signoff gate that decides it.

The signoff gate is executable: `make signoff-check` writes `build/signoff/report.md` and exits `0` only when every **phase-1**
requirement is verified (`A-09`, re-scoped to a phase bar on 2026-11-19); see `verification.md` §Signoff gate.

## Conventions

- IDs: `F-01`, `FR-01`, `NFR-01`, `C-01`, `A-01`, `Q-01`, `G-01`, `D-01`; blocks `BLK-*`; tests `T-01`.
- Figures: `F1`, `H0/H1/H2`, `S1`, `T1..Tn`.
- Every requirement has an acceptance criterion and a status.
- Mermaid is inline; WaveDrom lives in `figs/wave/`. See [figs/README.md](figs/README.md).
- Checks: `make docs-check`, `make docs-figs-check`.

## Renderer probe

Run once on GitHub and record the version here. Tier-2 Mermaid families are allowed only if this reports >= 11.

```mermaid
info
```

## Figure index

| ID | Claim | Tool | Source | Embedded in |
|---|---|---|---|---|
| H0 | The core owns no memory; every boundary is one interface, and the platform straps `mtime` and `hart_id` are two of them | inline Mermaid | `uarch.md` §1 | `uarch.md` |
| H1 | Four pipeline stage modules, the split block that owns the data port, one control block and the CSR file, joined by one interface per stage boundary; write-back is not a module | inline Mermaid | `uarch.md` §6 | `uarch.md` |
| H2 | Debug, the timer and the interrupt controller are platform blocks; the core reaches each through one named interface | inline Mermaid | `uarch.md` §1 | `uarch.md` |
| S1 | Debug mode is entered from running by run control, a breakpoint, a trigger or a step, and left only by resume or DRET | inline Mermaid (state diagram) | `uarch.md` §7.13 | `uarch.md` |
| T1 | A load-use insertion is one cycle of `ex_ma_flush` with IF/ID and ID/EX held, and the WB write still commits through `clk_en_wb` | WaveDrom | `figs/wave/t1-load-use-stall.json5` | `uarch.md` §7.6 |
| T2 | A taken branch clears IF/ID twice and redirects the PC in ID, at a cost of two fetch slots | WaveDrom | `figs/wave/t2-branch-flush.json5` | `uarch.md` §7.6 |
| T3 | A withheld fetch grant deletes the fetch and the PC runs on; nothing is held | WaveDrom | `figs/wave/t3-fetch-stall.json5` | `uarch.md` §7.1 |
| T4 | A trap flushes IF/ID and ID/EX and a one-cycle echo flushes IF/ID again, so one trap costs two fetch slots | WaveDrom | `figs/wave/t4-trap-entry.json5` | `uarch.md` §7.6 |
| T5 | The CSR is read in EX and written on the same edge, so the next `CSR*` reads the new value with no bubble | WaveDrom | `figs/wave/t5-zicsr-timing.json5` | `uarch.md` §7.11 |
