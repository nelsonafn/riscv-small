# NFR-03 - synthesis resources

| Field | Value |
|---|---|
| Requirement | The core shall report the resources its first synthesis consumes, with and without the instruction cache, before any area target is recorded. |
| Gap | `G-05`, `G-15` |
| Owner | designer |
| Status | not measurable |

## Method

One synthesis run with the default settings on the target part, reporting LUT, register, block-RAM and DSP counts,
once with the instruction cache present and once with it removed. The "with and without" pair needs `ICACHE_BYTES`,
which the RTL does not have yet (`G-15`), so even a successful synthesis today would only produce one of the two
numbers.

The flow is no longer the obstacle: `scripts/fpga/` is parameterised (`FPGA_TOP`, `FPGA_PROJECT_NAME`, `FPGA_PART`,
`CMakeLists.txt:58-60`) and expands its source list from `srclist/<top>.srclist`, so it synthesises `riscv_small`
out of context on `xczu3eg-sbva484-1-i` with Vivado 2024.1. What runs today is `make lint_fpga`, a lint and
netlist-count pass: it reports cells, latches, flip-flops and combinational loops, and it produces **no utilisation
report**, so the LUT, register, block-RAM and DSP counts this row asks for do not exist yet.

## Command

`make lint_fpga` is the run that exists today, and it is **lint only** - the counts it produces answer `NFR-07`, not
this row. The resources are owed by the synthesis targets:

```bash
make synth_fpga     # synthesis; the utilisation report has to be read from synth_1
make impl_fpga      # implementation; depends on synth_fpga
```

`run_synth.tcl` prints a `SYNTH_SUMMARY` line carrying the WNS and not the resources, so the LUT, register, block-RAM
and DSP numbers this row wants are a `report_utilization` on the `synth_1` run. Neither target has produced evidence
yet.

## Result

`not measurable` - `G-05`, `G-15`: no resources are reported. The flow now exists and synthesises `riscv_small`
itself, on `xczu3eg-sbva484-1-i` with Vivado 2024.1 out-of-context, but it stops at lint and netlist counts and
produces no utilisation report, so there is no LUT, register, block-RAM or DSP number; what that run measured is
latches and loops (`NFR-07`), which is not area. `A-08` records no target part, and the instruction cache that half
the requirement asks about does not exist (`G-15`). The flow targeting this core does not make this number measured -
it makes the number owed.

## History

| Date | RTL digest | Part | LUT / FF / BRAM / DSP | Cache | Method |
|---|---|---|---|---|---|
| 2026-10-28 | `sha256:34db4d37...` | - | `not measurable` | - | `G-05`, `G-15` |
