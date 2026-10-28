# riscv-small Documentation

| Document | Status | Scope |
|---|---|---|
| [spec.md](spec.md) | draft | features, functional and non-functional requirements, acceptance |
| [uarch.md](uarch.md) | draft | microarchitecture, 1:1 with the RTL |
| [verification.md](verification.md) | draft | traceability, test evidence, gaps |

## Reading order

1. `spec.md` — what the core promises.
2. `uarch.md` — how it is built.
3. `verification.md` — what is proven and what is not.

## Conventions

- IDs: `F-01`, `FR-01`, `NFR-01`, `C-01`, `A-01`, `Q-01`, `G-01`, `D-01`; blocks `BLK-*`; tests `T-01`.
- Figures: `F1`, `H0/H1/H2`, `T1..Tn`.
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
| H0 | The core owns no memory; every boundary is one interface | inline Mermaid | `uarch.md` §1 | `uarch.md` |
| H1 | Five modules and one control block; one interface per stage boundary | inline Mermaid | `uarch.md` §6 | `uarch.md` |
| T1 | A load-use insertion is one cycle of `ex_ma_flush` with IF/ID and ID/EX held, and it suppresses the write of the instruction in WB | WaveDrom | `figs/wave/t1-load-use-stall.json5` | `uarch.md` §7.5 |
| T2 | A taken branch clears IF/ID and redirects the PC in ID, at a cost of one fetch slot | WaveDrom | `figs/wave/t2-branch-flush.json5` | `uarch.md` §7.5 |
| T3 | A withheld fetch grant deletes the fetch and the PC runs on; nothing is held | WaveDrom | `figs/wave/t3-fetch-stall.json5` | `uarch.md` §7.1 |
