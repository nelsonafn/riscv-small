# NFR-02 - cycles for one named benchmark kernel

| Field | Value |
|---|---|
| Requirement | The core shall report the cycles it takes to run one named benchmark kernel, before any throughput target is recorded. |
| Gap | `G-05` (`G-10` closed 2026-10-30) |
| Owner | verification lead |
| Status | not measurable |

## Method

Run one named kernel on the core with a fixed memory-latency model, count the cycles between the first fetch and the
retiring store of the result, and report the kernel, the latency model and the configuration. No CPI target is
recorded before the measurement exists (`Q-09`).

## Command

The harness that produces the verdict is `cmake -P scripts/verify/sanity.cmake` (it builds and converts a real image
and reads `tohost` from the ELF). The memory model runs the kernel end to end since WP-4, but the verdict does not
publish a cycle count at the `tohost` store and no part/frequency is fixed (`A-08`, `G-05`), so a cycles-per-kernel
number cannot be compared:

```bash
cmake -P scripts/verify/sanity.cmake rv32ui-p-add
```

## Result

`not measurable` - the image runs end to end (`+HEX`/`+TOHOST` exists since WP-4), but the testbench records no
cycle count at the `tohost` store and no part/frequency is fixed (`G-05`).

## History

| Date | RTL digest | Kernel | Latency model | Cycles | Method |
|---|---|---|---|---|---|
| 2026-10-28 | `sha256:34db4d37...` | - | - | `not measurable` | `G-10` |
| 2026-10-30 | `sha256:67951680...` | - | - | `not measurable` | `+HEX` runs the kernel; no cycle count/part (`G-05`) |
