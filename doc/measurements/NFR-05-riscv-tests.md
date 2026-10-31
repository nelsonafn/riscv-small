# NFR-05 - bundled RISC-V test suite

| Field | Value |
|---|---|
| Requirement | The core shall pass every applicable image of the bundled RISC-V test suite: `rv32ui-p-*`, `rv32um-p-*`, `rv32uc-p-*` and `rv32mi-p-*`, plus `rv32ua-p-*` where `ENABLE_A` = 1. |
| Gap | `G-10` **closed** 2026-10-30; the remaining failures are `G-26`, `G-27`, `G-07`, `G-20`, `G-08`, `G-15` and `G-22` (`FR-42`) |
| Owner | verification lead |
| Status | **measured** - 1 pass / 41 fail of 42; not `verified` until 0 failures |

## Method

`scripts/verify/sanity.cmake` owns the whole pipeline. At configure time it compiles each
`src/riscv-tests/isa/rv32ui/<stem>.S` with the project environment
`scripts/verify/sanity/riscv_test.h` + `link.ld` (no `autoconf`, no suite Makefile, `-march=rv32i`,
`rv32i_zifencei` only for `fence_i`), converts the ELF to a Verilog hex
(`build/sanity_tests/hex/<image>.hex`), extracts `tohost` from the ELF with `riscv64-unknown-elf-nm`
(`build/sanity_tests/tohost/<image>`) and writes a disassembly (`build/sanity_tests/dump/<image>.dump`).
At run time it simulates with `+HEX=<hex> +TOHOST=<addr>` through CTest and judges the verdict line.

The project environment replaces only the suite's pass/fail ceremony. `env/p` signals through
`ECALL` -> `trap_vector` -> a store to `tohost`, and `riscv_small` decodes `SYSTEM` as a no-operation
(`G-13`); the harness therefore links `RVTEST_PASS`/`RVTEST_FAIL` directly to the `tohost` store.
The test bodies are the published ones, unmodified.

The test reads `+HEX`; `riscv_small_sanity_seq` builds the program item (`program_addr[]`/
`program_data[]`) from the non-zero words; `riscv_small_driver` is the memory BFM that loads the item
into its 64K-word array and answers the instruction and data ports. The monitor publishes fetch and
data; `riscv_small_sanity_checker` owns the verdict and the test owns the objection/timeout. The model
is word-granular on purpose: `SB`/`SH` write the whole word here until `FR-11`/`G-22` add byte strobes
to the DUT, so a sub-word store failure is measured as a DUT failure, never silently emulated. The
store that reaches `tohost` ends the run:

* `tohost == 1` -> `SANITY: PASS image=<name>`;
* `tohost == (n << 1) | 1` -> `SANITY: FAIL testnum=n value=0x...` plus a UVM error;
* no store within `+MAX_CYCLES` (default 200000) -> `SANITY: TIMEOUT pc=0x...` plus a UVM error.

A missing `SANITY:` line is `not_measurable`, never pass. `tohost` is never a literal.

## Command

```bash
make sanity                                   # every rv32ui-p-* image (42 today)
make sanity SANITY_ARGS="rv32ui-p-addi"
make sanity SANITY_ARGS="rv32ui-p-addi --trace"
make sanity SANITY_ARGS="--compile-only"      # build the images only
make compile_sanity_images                    # same build step, from CMake
```

`make sanity` exits 0 when it produced a verdict and 1 when an image failed. The signoff gate runs the
same measurement through `sanity-evidence` (`--allow-fail`), so a failing image becomes `blocked` in
check 6 instead of aborting the dependency chain.

## Result - 2026-10-30

| Field | Value |
|---|---|
| RTL digest | `sha256:6795168046841cba0bcf4443a2d9e4474e23b054d06e1286762965f1d261a953` |
| TB digest | `sha256:29bd72fc78614adfc20b513ab6b9a89077158826955501d6dc397501782ef6da` |
| Images | 42 (`rv32ui-p-*`) |
| Pass | 1 |
| Fail | 41 |
| Artefacts | `build/sanity/summary.json`, `build/sanity/<image>.log` |

| Image | Status | Verdict | Triage group |
|---|---|---|---|
| `rv32ui-p-add` | fail | testnum=4 | G-26 |
| `rv32ui-p-addi` | fail | testnum=3 | G-26 |
| `rv32ui-p-and` | fail | testnum=1 | G-26 + G-27 |
| `rv32ui-p-andi` | fail | testnum=1 | G-26 + G-27 |
| `rv32ui-p-auipc` | fail | testnum=1 | G-26 + G-27 |
| `rv32ui-p-beq` | fail | testnum=2 | G-26 |
| `rv32ui-p-bge` | fail | testnum=2 | G-26 |
| `rv32ui-p-bgeu` | fail | testnum=2 | G-26 |
| `rv32ui-p-blt` | fail | testnum=1 | G-26 + G-27 |
| `rv32ui-p-bltu` | fail | testnum=1 | G-26 + G-27 |
| `rv32ui-p-bne` | fail | testnum=1 | G-26 + G-27 |
| `rv32ui-p-fence_i` | fail | timeout pc=0x00000050 | G-15 |
| `rv32ui-p-jal` | fail | testnum=1 | G-26 + G-27 |
| `rv32ui-p-jalr` | fail | timeout pc=0x00000020 | G-07 |
| `rv32ui-p-lb` | fail | testnum=1 | G-26 + G-27 |
| `rv32ui-p-lbu` | fail | testnum=1 | G-26 + G-27 |
| `rv32ui-p-ld_st` | fail | timeout pc=0x0047aec4 | G-20 |
| `rv32ui-p-lh` | fail | testnum=1 | G-26 + G-27 |
| `rv32ui-p-lhu` | fail | testnum=1 | G-26 + G-27 |
| `rv32ui-p-lui` | fail | testnum=1 | G-26 + G-27 |
| `rv32ui-p-lw` | fail | testnum=1 | G-26 + G-27 |
| `rv32ui-p-ma_data` | fail | testnum=2 | FR-42 / G-22 |
| `rv32ui-p-or` | fail | testnum=1 | G-26 + G-27 |
| `rv32ui-p-ori` | fail | testnum=1 | G-26 + G-27 |
| `rv32ui-p-sb` | fail | testnum=1 | G-08 + G-27 |
| `rv32ui-p-sh` | fail | testnum=1 | G-08 + G-27 |
| `rv32ui-p-simple` | pass | - | pass |
| `rv32ui-p-sll` | fail | testnum=6 | G-26 |
| `rv32ui-p-slli` | fail | testnum=6 | G-26 |
| `rv32ui-p-slt` | fail | testnum=8 | G-26 |
| `rv32ui-p-slti` | fail | testnum=8 | G-26 |
| `rv32ui-p-sltiu` | fail | testnum=8 | G-26 |
| `rv32ui-p-sltu` | fail | testnum=8 | G-26 |
| `rv32ui-p-sra` | fail | testnum=3 | G-26 |
| `rv32ui-p-srai` | fail | testnum=3 | G-26 |
| `rv32ui-p-srl` | fail | testnum=4 | G-26 |
| `rv32ui-p-srli` | fail | testnum=4 | G-26 |
| `rv32ui-p-st_ld` | fail | timeout pc=0x0047a774 | G-20 |
| `rv32ui-p-sub` | fail | testnum=4 | G-26 |
| `rv32ui-p-sw` | fail | testnum=1 | G-26 + G-27 |
| `rv32ui-p-xor` | fail | testnum=1 | G-26 + G-27 |
| `rv32ui-p-xori` | fail | testnum=1 | G-26 + G-27 |

## Triage

| Group | Root cause | Evidence | Owner / next WP |
|---|---|---|---|
| `G-25` | **closed by WP-4**: the MA forward overwrote `alu_src2` with the store data, so `sw gp,tohost` went to `rs1 + rs2`. Fixed in `rtl/control.sv:220-228`; `simple` now stores to `0xc0`. | `rv32ui-p-simple` PASS; `T-08` green | fixed |
| `G-26` | Operand production/forwarding: a value produced by the immediately preceding instruction is not forwarded to the next ALU operation. The suite's `li` expands to `lui` + `addi`, so almost every test's operand setup is affected. | `rv32ui-p-addi` case 3: `li x13,1; addi x14,x13,1` gives 1, not 2 (`value=0x7` -> `testnum=3`); `rv32ui-p-add` case 4 (`value=0x9`); `sll`/`slt`/`sra`/`srl`/`sub` fail at the first forwarded case | verification lead / E1b (forwarding), feeds `FR-16`, `FR-18`, `FR-19` |
| `G-27` | After a taken branch the first instruction at the target is not fetched/executed. The fail path's `slli gp,gp,1` is skipped, so `RVTEST_FAIL` writes `TESTNUM | 1` instead of `(TESTNUM << 1) | 1`; the reported `testnum=1` is therefore the corrupted value, not the true case. | `rv32ui-p-and`: fail branch at `0xa0` targets `0x538`, the history jumps to `0x53c`; `ori gp,gp,1` writes `0x3` from the stale `gp=2`; `x3` writes are `0,0,2,3`, no `4`/`5` | designer / E4 (branch/jump flush) |
| `G-07` | `JALR` does not clear target bit 0. | `rv32ui-p-jalr` timeout at `pc=0x20` | designer / E4 |
| `G-20` | Branch/jump targets add `imm[20:0]` zero-extended, so negative offsets land far away. | `rv32ui-p-ld_st` timeout at `pc=0x0047aec4`, `rv32ui-p-st_ld` at `pc=0x0047a774` | designer / E4 |
| `G-08` | Sub-word stores drive one lane; no byte strobes. | `rv32ui-p-sb`, `rv32ui-p-sh`; the word-granular model isolates the DUT | designer / E5 |
| `FR-42` / `G-22` | No misaligned split. | `rv32ui-p-ma_data` case 2 | designer / E8 |
| `G-15` | No instruction cache / `fence.i` semantics. | `rv32ui-p-fence_i` timeout at `pc=0x50` | designer / E8 |

`ma_data` and `fence_i` are **measured failures**, not exclusions: no `A-xx` waiver is recorded, and the
release gate stays `blocked` until `FR-42` and `G-15` are implemented.

## Debug

1. `SANITY: FAIL testnum=n` -> the `TEST_CASE(n, ...)`/`TEST_*_OP(n, ...)` in the `.S`; `SANITY: TIMEOUT pc=...` -> the
   last fetched PC.
2. `build/sanity_tests/dump/<image>.dump` maps `pc` and `test_<n>:` back to the assembly.
3. `--trace` adds the last fetches and data operations; the checker prints the last 16 events on fail/timeout.
4. If the reported `testnum` is 1 but the first case is 2, suspect `G-27`: the fail path's `slli` was skipped. The
   `RTL REG_WRITE: x3` lines in the log show the committed `gp` values; the value before the doubling is the true case.
5. A store whose address is not `tohost` is a DUT bug (as `G-25` was), not a harness bug; compare with the trace.

## History

| Date | RTL digest | Images | Pass | Fail | Method |
|---|---|---|---|---|---|
| 2026-10-28 | `sha256:34db4d37...` | 42 available, 0 run | - | - | `G-10`: no `+HEX` consumer |
| 2026-10-30 | `sha256:6795168046841cba0bcf4443a2d9e4474e23b054d06e1286762965f1d261a953` | 42 | 1 | 41 | WP-4: project env, direct compile, TB memory model, `tohost` |
| 2026-10-31 | `sha256:6795168046841cba0bcf4443a2d9e4474e23b054d06e1286762965f1d261a953` | 42 | 1 | 41 | WP-4b: sequence program item, driver BFM, checker on the monitor; same verdicts (TB `sha256:29bd72fc...`) |
