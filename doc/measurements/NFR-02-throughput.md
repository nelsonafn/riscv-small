# NFR-02 - cycles for one named benchmark kernel

| Field | Value |
|---|---|
| Requirement | The core shall report the cycles it takes to run one named benchmark kernel, before any throughput target is recorded. |
| Gap | `G-05`, `G-10` |
| Owner | verification lead |
| Status | not measurable |

## Method

Run one named kernel on the core with a fixed memory-latency model, count the cycles between the first fetch and the
retiring store of the result, and report the kernel, the latency model and the configuration. No CPI target is
recorded before the measurement exists (`Q-09`).

## Command

The harness that would produce it is `cmake -P scripts/verify/sanity.cmake` (it already builds and converts a real image and
reads `tohost` from the ELF). A cycle count requires the testbench to sample the clock next to the `tohost` write,
which needs the `+HEX`/`+TOHOST` mode the testbench does not have (`G-10`):

```bash
cmake -P scripts/verify/sanity.cmake rv32ui-p-add
```

## Result

`not measurable` - no testbench mode consumes a hex image (`G-10`), so no kernel runs end to end.

## History

| Date | RTL digest | Kernel | Latency model | Cycles | Method |
|---|---|---|---|---|---|
| 2026-10-28 | `sha256:34db4d37...` | - | - | `not measurable` | `G-10` |
