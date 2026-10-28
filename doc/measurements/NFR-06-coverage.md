# NFR-06 - functional coverage

| Field | Value |
|---|---|
| Requirement | Functional coverage shall close on the instruction set and memory behaviour it claims. |
| Gap | `G-03`, `G-04`, `G-11` |
| Owner | verification lead |
| Status | partial - instrumented and merged, one bin open |

## Method

One bin per decoded instruction of `doc/spec.md` §4.1 and one per memory width, sampled in the monitor, merged over
the regression with `xcrg`. The signoff bar (`A-09`, `Q-11`) needs every `FR` row `verified` as well, so coverage
closure and the ISS capability (`G-04`) move together.

## Command

```bash
make coverage                 # elaborate + simulate + xcrg merge
make coverage COVERAGE_ARGS="--test T-01 --seed 42"
```

## Result

91.67 % over `T-01`, `T-02` and `T-06`, with one uncovered bin: `cg_mem.cp_width.word_w`. The width output carries
`funct3[0]` (`logic'(rd_wr_ctrl)`, `rtl/riscv_small.sv:118`), so a word access reads `2'b00` and the word bin can
never fill. That is an `FR-11` defect, not a coverage hole to waive. `cp_lane`, `cp_dir` and `cp_subword_lane` are
at 100 %, and code coverage is instrumented with `--cc_type sbct --cc_libs` and merged with `xcrg`.

## History

| Date | RTL digest | Coverpoints | Functional % | Code % | Method |
|---|---|---|---|---|---|
| 2026-10-28 | `sha256:0418049b...` | 4 | 91.67 % (`word_w` open, `FR-11`) | merged | `xcrg` over T-01/T-02/T-06 |
