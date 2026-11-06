# NFR-05 - bundled RISC-V test suite

| Field | Value |
|---|---|
| Requirement | The core shall pass every applicable image of the bundled RISC-V test suite: `rv32ui-p-*`, `rv32um-p-*`, `rv32uc-p-*` and `rv32mi-p-*`, plus `rv32ua-p-*` where `ENABLE_A` = 1. |
| Gap | `G-10`/`G-25`/`G-26`/`G-27`/`G-20`/`G-08`/`G-19`/`G-29`/`G-07`/`G-30`/`G-31` closed; the one remaining failure is `G-22` (`FR-42`), and `G-15` is no longer an `NFR-05` failure |
| Owner | verification lead |
| Status | **measured** - 41 pass / 1 fail of the **42 bundled images**; the harness runs 43 because WP-7 added one project-local image (`rv32ui-p-jalr_unaligned`), which passes. Not `verified` until 0 failures |

## Method

`scripts/verify/sanity.cmake` owns the whole pipeline. At configure time it compiles each bundled
`src/riscv-tests/isa/rv32ui/<stem>.S` **and each project-local `scripts/verify/sanity/local/*.S`** with the same
project environment
`scripts/verify/sanity/riscv_test.h` + `link.ld` (no `autoconf`, no suite Makefile, `-march=rv32i`,
`rv32i_zifencei` only for `fence_i`), converts the ELF to a Verilog hex
(`build/sanity_tests/hex/<image>.hex`), extracts `tohost` from the ELF with `riscv64-unknown-elf-nm`
(`build/sanity_tests/tohost/<image>`) and writes a disassembly (`build/sanity_tests/dump/<image>.dump`).
At run time it simulates with `+HEX=<hex> +TOHOST=<addr>` through CTest and judges the verdict line.

A local image is a project test, not part of the bundled suite: it is compiled and judged by the same pipeline,
counted in `build/sanity/summary.json`, and reported separately below so the requirement's denominator stays the
bundled set. WP-7 added the first one, `rv32ui-p-jalr_unaligned` (an odd `JALR` target, derived from the bundled
`jalr.S`), because no bundled image exercises the bit-0 mask of `FR-07`.

The test reads `+HEX`; `riscv_small_sanity_seq` builds the program item (`program_addr[]`/
`program_data[]`); `riscv_small_driver` is the memory BFM; the monitor publishes fetch and data;
`riscv_small_sanity_checker` owns the verdict and the test owns the objection/timeout. The model is
byte-strobed since WP-6: the BFM applies `data_wr_strb`, so a sub-word store now writes only the bytes the
core says it drives. Before WP-6 the model was word-granular, which could hide a lane defect. `rv32ui-p-ld_st`'s
old **pass** turned out to have a second, deeper cause: `G-29` gave the branch at `0xa4` a stale PC, so it
resolved to `0xee4` instead of `0xee8` — the `<pass>` path — and a failing test wrote `tohost=1`. That pass is
retired with `G-29`. The image then failed honestly under `G-30` until WP-7 closed it, and it passes again now.

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
make sanity                                   # every image (43 today: 42 bundled + 1 local)
make sanity SANITY_ARGS="rv32ui-p-addi"
make sanity SANITY_ARGS="rv32ui-p-addi --trace"
make sanity SANITY_ARGS="--compile-only"      # build the images only
make compile_sanity_images                    # same build step, from CMake
```

`make sanity` exits 0 when it produced a verdict and 1 when an image failed. The signoff gate runs the
same measurement through `sanity-evidence` (`--allow-fail`).

## Result - 2026-11-06 (WP-7)

| Field | Value |
|---|---|
| RTL digest | `sha256:3541dfb8465edb0be8e976bf5fe0802285165b9e67855a718acda96ec287cd80` |
| TB digest | `sha256:ae4e6c793ec7e345313273dde076d7ac20c7833c242716d9d51b1ecb428b5764` |
| Images | 43 = 42 bundled + 1 project-local (`rv32ui-p-jalr_unaligned`) |
| Pass | 42 (41 bundled + the local image) |
| Fail | 1 (`rv32ui-p-ma_data`) |
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
| `rv32ui-p-fence_i` | pass | - | pass — its old timeout was the unforwarded `JALR` `rs1` (`G-31`), not `G-15` |
| `rv32ui-p-jal` | pass | - | pass |
| `rv32ui-p-jalr` | pass | - | pass (T-17) |
| `rv32ui-p-lb` | pass | - | pass |
| `rv32ui-p-lbu` | pass | - | pass |
| `rv32ui-p-ld_st` | pass | - | pass (T-16) |
| `rv32ui-p-lh` | pass | - | pass |
| `rv32ui-p-lhu` | pass | - | pass |
| `rv32ui-p-lui` | pass | - | pass |
| `rv32ui-p-lw` | pass | - | pass |
| `rv32ui-p-ma_data` | fail | testnum=1 | FR-42 / G-22 |
| `rv32ui-p-or` | pass | - | pass |
| `rv32ui-p-ori` | pass | - | pass |
| `rv32ui-p-sb` | pass | - | pass (T-13) |
| `rv32ui-p-sh` | pass | - | pass (T-14) |
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
| `rv32ui-p-st_ld` | pass | - | pass (T-15) |
| `rv32ui-p-sub` | pass | - | pass |
| `rv32ui-p-sw` | pass | - | pass |
| `rv32ui-p-xor` | pass | - | pass |
| `rv32ui-p-xori` | pass | - | pass |
| `rv32ui-p-jalr_unaligned` | pass | - | pass (T-37) — **project-local**, `scripts/verify/sanity/local/`, not a bundled image |

## Triage

| Group | Root cause | Evidence | Owner / next WP |
|---|---|---|---|
| `G-27` / `G-26` / `G-20` | **closed by WP-4c**: the decoder PC was one instruction ahead (branch target +4), the branch/jump forward mux/`alu_ex` were unconnected, and the branch target used `imm[20:0]`. | `T-10`/`T-11`/`T-12` and the mutants `branch-redirect`/`forward-rs1`/`negative-branch`; 34 images pass | fixed |
| `G-07` | `JALR` did not clear target bit 0. | **closed 2026-11-05**: `jalr` passes; `jalr_unaligned` (local, odd target) passes and fails `testnum=3` when the mask is removed | designer / WP-7 |
| `G-08` | Sub-word store lane / word-granular BFM. | **closed 2026-11-05**: `sb`, `sh` and `st_ld` pass | designer / E5 |
| `G-19` | A load-use freeze dropped a write-back (shared register-file clock enable). | **closed 2026-11-05**: `lb` and `lbu` pass | designer / E4 |
| `G-29` | IF/ID captured `pc_id` and `inst_id` from different addresses across a stall. | **closed 2026-11-05**: it was manufacturing `ld_st`'s pass; that image now fails honestly under `G-30` | verification lead / WP-6 |
| `G-30` | A branch decided against an unresolved load flushes a valid fetch. | **closed 2026-11-05**: `ld_st` passes; mutant `branch-taken-stale` reproduces `testnum=2` | verification lead / WP-7 |
| `G-31` | `JALR`'s `rs1` was never forwarded. | **closed 2026-11-05**: found by the `jalr` red; mutant `jalr-no-forward` | verification lead / WP-7 |
| `G-15` | No I-cache / line fetch — a **target** gap, not a test failure. | **re-attributed 2026-11-05**: `fence_i` passes on a cacheless core, because `fence.i` is correctly a no-operation; its old timeout was the unforwarded `JALR` `rs1` (`G-31`) | designer / `F-10` |
| `FR-42` / `G-22` | No misaligned split. | `rv32ui-p-ma_data` testnum=1 | designer / E8 |

The one remaining failure is not a waiver: `NFR-05` stays red until `FR-42`/`G-22` implements the misaligned
split. The `Q-11` release blockers are now `G-04` and `G-11`; the release is blocked by `A-09` and this
measurement regardless.

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
| 2026-11-05 | `sha256:f48ab029b3c0cf986106d639b295f62fe0285b6eb2b34d78cf510e4259b9586d` | 42 | 38 | 4 | WP-6: `G-08`/`G-19`/`G-29` closed, `G-30` opened; `T-13`/`T-14`/`T-15` green (TB `ae4e6c79...`) |
| 2026-11-06 | `sha256:3541dfb8465edb0be8e976bf5fe0802285165b9e67855a718acda96ec287cd80` | 43 (42 + 1 local) | 42 | 1 | WP-7: `G-07`/`G-30`/`G-31` closed, `G-15` re-attributed; `T-16`..`T-43` green; `jalr_unaligned` added (TB `ae4e6c79...`) |
