# NFR-01 - achieved clock frequency

| Field | Value |
|---|---|
| Requirement | The core shall report the clock frequency its first synthesis achieves, and the part it was achieved on, before any frequency target is recorded. |
| Gap | `G-05` |
| Owner | designer |
| Status | not measurable |

## Method

The first synthesis of `riscv_small` on the target part, reading the achieved frequency from the timing summary.
No frequency is invented before that report exists (`A-08`, `Q-08`), and no part is assumed: the FPGA flow in
`scripts/fpga/` still targets a different SoC (`cvqkd_topsoc`) and adds every `rtl/*.sv` unconditionally, so it does
not synthesise this core yet.

## Command

None yet. A working command would look like:

```bash
vivado -mode batch -source scripts/fpga/run_synth.tcl
```

against a project that instantiates `riscv_small`, followed by `report_timing_summary` for the achieved period.

## Result

`not measurable` - `G-05`: no synthesis flow targets this core, so there is no part and no frequency to report.

## History

| Date | RTL digest | Part | Fmax | Method |
|---|---|---|---|---|
| 2026-10-28 | `sha256:34db4d37...` | - | `not measurable` | `G-05` |
