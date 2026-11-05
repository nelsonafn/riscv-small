# NFR-05 - bundled RISC-V test suite

| Field | Value |
|---|---|
| Requirement | The core shall pass every applicable image of the bundled RISC-V test suite: `rv32ui-p-*`, `rv32um-p-*`, `rv32uc-p-*` and `rv32mi-p-*`, plus `rv32ua-p-*` where `ENABLE_A` = 1. |
| Gap | `G-10`/`G-25`/`G-26`/`G-27`/`G-20` closed; the remaining failures are `G-07`, `G-08`, `G-15`, `G-19` and `G-22` (`FR-42`) |
| Owner | verification lead |
| Status | **measured** - 34 pass / 8 fail of 42; not `verified` until 0 failures |

## Method

`scripts/verify/sanity.cmake` owns the whole pipeline. At configure time it compiles each
`src/riscv-tests/isa/rv32ui/<stem>.S` with the project environment
`scripts/verify/sanity/riscv_test.h` + `link.ld` (no `autoconf`, no suite Makefile, `-march=rv32i`,
`rv32i_zifencei` only for `fence_i`), converts the ELF to a Verilog hex
(`build/sanity_tests/hex/<image>.hex`), extracts `tohost` from the ELF with `riscv64-unknown-elf-nm`
(`build/sanity_tests/tohost/<image>`) and writes a disassembly (`build/sanity_tests/dump/<image>.dump`).
At run time it simulates with `+HEX=<hex> +TOHOST=<addr>` through CTest and judges the verdict line.

The test reads `+HEX`; `riscv_small_sanity_seq` builds the program item (`program_addr[]`/
`program_data[]`); `riscv_small_driver` is the memory BFM; the monitor publishes fetch and data;
`riscv_small_sanity_checker` owns the verdict and the test owns the objection/timeout. The model is
word-granular on purpose: `SB`/`SH` write the whole word here until `FR-11`/`G-22` add byte strobes,
so a sub-word **failure** is measured as a DUT failure, never silently emulated (and `ld_st` can be a
false **pass** for the same reason; it is not counted as `FR-11` evidence).

The store that reaches `tohost` ends the run:

* `tohost == 1` -> `SANITY: PASS image=<name>`;
* `tohost == (n << 1) | 1` -> `SANITY: FAIL testnum=n value=0x...` plus a UVM error;
* no store within `+MAX_CYCLES` -> `SANITY: TIMEOUT pc=0x... image=<name>` plus a UVM error.

A missing `SANITY:` line is `not_measurable`, never pass, and so is a verdict line that names another image:
the CTest command pins `^SANITY: PASS image=<image>$` and the summary parser rejects a log whose `image=`
differs from the row (`build/sanity/<image>.log` must not carry another image's verdict). `tohost` is never a
literal.

## Command

```bash
make sanity                                   # every rv32ui-p-* image (42 today)
make sanity SANITY_ARGS="rv32ui-p-addi"
make sanity SANITY_ARGS="rv32ui-p-addi --trace"
make sanity SANITY_ARGS="--compile-only"      # build the images only
make compile_sanity_images                    # same build step, from CMake
```

`make sanity` exits 0 when it produced a verdict and 1 when an image failed. The signoff gate runs the
same measurement through `sanity-evidence` (`--allow-fail`).

## Result - 2026-11-04

| Field | Value |
|---|---|
| RTL digest | `sha256:d12dc1a201e403a1bc55469e9802f28734b28889c10ec1837389e4fb698027b2` |
| TB digest | `sha256:f542affd7ab0c07e1bcf9eba182644cb4458f5319a8be7dcca978a5aff6cab3a` |
| Images | 42 (`rv32ui-p-*`) |
| Pass | 34 |
| Fail | 8 |
| Artefacts | `build/sanity/summary.json`, `build/sanity/<image>.log` |

| Image | Status | Verdict | Triage group |
|---|---|---|---|
| `rv32ui-p-add` | pass | - | pass |
| `rv32ui-p-addi` | pass | - | pass (T-11) |
| `rv32ui-p-and` | pass | - | pass (T-10) |
| `rv32ui-p-andi` | pass | - | pass |
| `rv32ui-p-auipc` | pass | - | pass |
| `rv32ui-p-beq` | pass | - | pass (T-12) |
| `rv32ui-p-bge` | pass | - | pass |
| `rv32ui-p-bgeu` | pass | - | pass |
| `rv32ui-p-blt` | pass | - | pass |
| `rv32ui-p-bltu` | pass | - | pass |
| `rv32ui-p-bne` | pass | - | pass |
| `rv32ui-p-fence_i` | fail | timeout pc=0x00000034 | G-15 |
| `rv32ui-p-jal` | pass | - | pass |
| `rv32ui-p-jalr` | fail | timeout pc=0x00000004 | G-07 |
| `rv32ui-p-lb` | fail | timeout pc=0x00000204 | G-19 |
| `rv32ui-p-lbu` | fail | timeout pc=0x00000204 | G-19 |
| `rv32ui-p-ld_st` | pass | - | G-08 (false pass) |
| `rv32ui-p-lh` | pass | - | pass |
| `rv32ui-p-lhu` | pass | - | pass |
| `rv32ui-p-lui` | pass | - | pass |
| `rv32ui-p-lw` | pass | - | pass |
| `rv32ui-p-ma_data` | fail | testnum=1 | FR-42 / G-22 |
| `rv32ui-p-or` | pass | - | pass |
| `rv32ui-p-ori` | pass | - | pass |
| `rv32ui-p-sb` | fail | testnum=4 | G-08 |
| `rv32ui-p-sh` | fail | testnum=3 | G-08 |
| `rv32ui-p-simple` | pass | - | pass |
| `rv32ui-p-sll` | pass | - | pass |
| `rv32ui-p-slli` | pass | - | pass |
| `rv32ui-p-slt` | pass | - | pass |
| `rv32ui-p-slti` | pass | - | pass |
| `rv32ui-p-sltiu` | pass | - | pass |
| `rv32ui-p-sltu` | pass | - | pass |
| `rv32ui-p-sra` | pass | - | pass |
| `rv32ui-p-srai` | pass | - | pass |
| `rv32ui-p-srl` | pass | - | pass |
| `rv32ui-p-srli` | pass | - | pass |
| `rv32ui-p-st_ld` | fail | testnum=2 | G-08 |
| `rv32ui-p-sub` | pass | - | pass |
| `rv32ui-p-sw` | pass | - | pass |
| `rv32ui-p-xor` | pass | - | pass |
| `rv32ui-p-xori` | pass | - | pass |

## Triage

| Group | Root cause | Evidence | Owner / next WP |
|---|---|---|---|
| `G-27` / `G-26` / `G-20` | **closed by WP-4c**: the decoder PC was one instruction ahead (branch target +4), the branch/jump forward mux/`alu_ex` were unconnected, and the branch target used `imm[20:0]`. | `T-10`/`T-11`/`T-12` and the mutants `branch-redirect`/`forward-rs1`/`negative-branch`; 34 images pass | fixed |
| `G-07` | `JALR` does not clear target bit 0. | `rv32ui-p-jalr` timeout `pc=0x4` | designer / E4 |
| `G-08` | Sub-word store lane / word-granular BFM. | `rv32ui-p-sb` testnum=4, `sh` 3, `st_ld` 2; `ld_st` is a word-granular **false pass** | designer / E5 |
| `G-15` | No I-cache / `fence.i`. | `rv32ui-p-fence_i` timeout `pc=0x34` | designer / E8 |
| `G-19` | Load-use/data-stall fetch gap. | `rv32ui-p-lb`/`lbu` timeout `pc=0x204`; `T-06`'s lane selection still passes | designer / E4 |
| `FR-42` / `G-22` | No misaligned split. | `rv32ui-p-ma_data` testnum=1 | designer / E8 |

The 8 remaining images are not waivers: the release gate stays `blocked` until `G-07`, `G-08`, `G-15`,
`G-19` and `FR-42` are implemented.

## Debug

1. `SANITY: FAIL testnum=n` -> the `TEST_CASE(n, ...)` in the `.S`; `SANITY: TIMEOUT pc=... image=<name>` -> the last fetch.
2. `build/sanity_tests/dump/<image>.dump` maps `pc`/`test_<n>:` back to the assembly.
3. `--trace` adds the last fetches and data operations; the checker prints the last 16 events on fail/timeout.
4. A store whose address is not `tohost` is a DUT bug, not a harness bug.
5. `G-27` corrupted the fail path's `testnum`; after WP-4c the reported `testnum` is the true case.

## History

| Date | RTL digest | Images | Pass | Fail | Method |
|---|---|---|---|---|---|
| 2026-10-28 | `sha256:34db4d37...` | 42 available, 0 run | - | - | `G-10`: no `+HEX` consumer |
| 2026-10-30 | `sha256:67951680...` | 42 | 1 | 41 | WP-4: project env, direct compile, TB memory model, `tohost` |
| 2026-10-31 | `sha256:67951680...` | 42 | 1 | 41 | WP-4b: sequence program item, driver BFM, checker on the monitor (TB `29bd72fc...`) |
| 2026-11-04 | `sha256:d12dc1a201e403a1bc55469e9802f28734b28889c10ec1837389e4fb698027b2` | 42 | 34 | 8 | WP-4c: `G-27`/`G-26`/`G-20`; `T-10`/`T-11`/`T-12` green; verdict image-pinned (TB `f542affd...`) |
