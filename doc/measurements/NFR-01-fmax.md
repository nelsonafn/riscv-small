# NFR-01 - achieved clock frequency

| Field | Value |
|---|---|
| Requirement | The core shall report the clock frequency its first synthesis achieves, and the part it was achieved on, before any frequency target is recorded. |
| Gap | `G-05` |
| Owner | designer |
| Status | not measurable |

## Method

The first synthesis of `riscv_small` on the target part, reading the achieved frequency from the timing summary.
No frequency is invented before that report exists (`A-08`, `Q-08`), and no part is assumed.

The flow that was missing now exists and does target this core. `scripts/fpga/` is parameterised - `FPGA_TOP`,
`FPGA_PROJECT_NAME` and `FPGA_PART` are cache variables (`CMakeLists.txt:58-60`) - and its source list is expanded
from `srclist/<top>.srclist`, so `make lint_fpga` synthesises `riscv_small` out of context on
`xczu3eg-sbva484-1-i` with Vivado 2024.1, the run `NFR-07` reads (`LINT_SUMMARY: top=riscv_small
part=xczu3eg-sbva484-1-i cells=4069 latches=0 flops=1405 combinational_loops=0`, `build/vivado.log:354`).

That run does not produce this number, and is not read as if it did: it is a lint and netlist-count pass with **no
timing report**, and it is **out-of-context**, so it reports no achieved period. The frequency stays unmeasured
because no implementation run has produced a static timing report, and because `doc/spec.md` records **no target
part** (`A-08`) - the part above is the one the flow was pointed at, not a target this document has fixed.

## Command

The entry point is the flow's own targets:

```bash
make lint_fpga      # lint + netlist counts only; no timing, so no frequency
make synth_fpga     # synthesis, prints SYNTH_SUMMARY with a post-synthesis WNS
make impl_fpga      # implementation; depends on synth_fpga
```

`make lint_fpga` is the run that exists today and it is **lint only** - it answers `NFR-07`, not this row. The
frequency is owed by `make synth_fpga` and `make impl_fpga`: the implementation run is what carries the static timing
report this requirement reads, and no such run has produced evidence yet (`run_impl.tcl` reports status, not a
period; the achieved period then comes from `report_timing_summary` on that run).

## Result

`not measurable` - `G-05`: no frequency is reported. The flow now exists and synthesises `riscv_small` itself, on
`xczu3eg-sbva484-1-i` with Vivado 2024.1 out-of-context, but it stops at lint and netlist counts, so no timing report
and no achieved period exist; `A-08` records no target part either. The flow targeting this core does not make this
number measured - it makes the number owed.

## History

| Date | RTL digest | Part | Fmax | Method |
|---|---|---|---|---|
| 2026-10-28 | `sha256:34db4d37...` | - | `not measurable` | `G-05` |
