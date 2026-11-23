# Measurements

One file per non-functional requirement of `doc/spec.md` §5. A measurement is recorded here, next to the method
that produced it, because a number without its method, date and part is not evidence.

| Requirement | File | Today |
|---|---|---|
| `NFR-01` | [NFR-01-fmax.md](NFR-01-fmax.md) | not measurable |
| `NFR-02` | [NFR-02-throughput.md](NFR-02-throughput.md) | not measurable |
| `NFR-03` | [NFR-03-area.md](NFR-03-area.md) | not measurable |
| `NFR-04` | [NFR-04-power.md](NFR-04-power.md) | not measurable |
| `NFR-05` | [NFR-05-riscv-tests.md](NFR-05-riscv-tests.md) | measured, **43/43** (42 bundled + 1 project-local `jalr_unaligned`), 0 failures (2026-11-19, `rv32ui-p-ma_data` included); the requirement stays `partial` on its four suite legs |
| `NFR-06` | [NFR-06-coverage.md](NFR-06-coverage.md) | bins closed, **66/66** report bins over **9** coverpoints and 40/40 `A-09` bar bins (100 %, `uncovered` empty, 2026-11-21); the requirement stays `partial` on the `FR` half (24 of the 47 phase-1 rows `verified`) |
| `NFR-07` | [NFR-07-lint.md](NFR-07-lint.md) | measured: 0 latches, 0 loops (2026-11-18) |

## Contract

Every file states, in this order:

1. the requirement text it answers, quoted from `doc/spec.md`;
2. the **method** — the tool, the settings and the part;
3. the **command** that reproduces it, copy-pasteable;
4. the **date** and the **`rtl_digest`** of the code measured;
5. the **result**, or the literal phrase `not measurable` and the gap that blocks it.

Rules:

- `not measurable` is a legitimate entry; a plausible number is not.
- A target appears only after a measurement exists (`Q-08`..`Q-10`).
- The signoff gate (`make signoff-check`, check 8) requires a file per `NFR-01`..`NFR-04` with a method and a date;
  check 9 does the same for `NFR-07`.
- Do not edit a recorded result after the `rtl_digest` changed: add a new row with its own date.
