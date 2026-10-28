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

## Command

None yet (`G-05`).

## Result

`not measurable` - no synthesis flow targets this core, and the instruction cache that half the requirement asks
about does not exist (`G-15`).

## History

| Date | RTL digest | Part | LUT / FF / BRAM / DSP | Cache | Method |
|---|---|---|---|---|---|
| 2026-10-28 | `sha256:34db4d37...` | - | `not measurable` | - | `G-05`, `G-15` |
