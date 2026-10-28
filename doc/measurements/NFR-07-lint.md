# NFR-07 - no inferred latches, no combinational loops

| Field | Value |
|---|---|
| Requirement | The core shall synthesise with no inferred latches and no combinational loops. |
| Gap | `G-05` |
| Owner | designer |
| Status | not measurable |

## Method

Synthesis of every named configuration with the default settings on the target part, plus a lint pass, counting
inferred latches and combinational loops. `rtl/` uses `always_comb` throughout, which helps the simulator warn but is
not a substitute for the synthesis report.

## Command

None yet (`G-05`). The intended entry point is `make lint_fpga`, whose flow still targets a different SoC.

## Result

`not measurable` - there is no lint or synthesis report for `riscv_small` (`G-05`).

## History

| Date | RTL digest | Part | Latches | Loops | Method |
|---|---|---|---|---|---|
| 2026-10-28 | `sha256:34db4d37...` | - | `not measurable` | `not measurable` | `G-05` |
