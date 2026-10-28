# NFR-04 - implementation power

| Field | Value |
|---|---|
| Requirement | The core shall report the power its implementation consumes under a named activity vector, with and without the instruction cache, before any power budget is recorded. |
| Gap | `G-05`, `G-15` |
| Owner | designer |
| Status | not measurable |

## Method

Post-implementation power analysis with a switching-activity file captured from a named test (a SAIF from the
regression), on the target part, once with the instruction cache and once without. Both halves are blocked: no
implementation flow (`G-05`) and no cache (`G-15`).

## Command

None yet (`G-05`).

## Result

`not measurable`.

## History

| Date | RTL digest | Part | Activity vector | Power | Method |
|---|---|---|---|---|---|
| 2026-10-28 | `sha256:34db4d37...` | - | - | `not measurable` | `G-05`, `G-15` |
