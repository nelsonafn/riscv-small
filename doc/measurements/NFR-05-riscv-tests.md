# NFR-05 - bundled RISC-V test suite

| Field | Value |
|---|---|
| Requirement | The core shall pass every applicable image of the bundled RISC-V test suite: `rv32ui-p-*`, `rv32um-p-*`, `rv32uc-p-*` and `rv32mi-p-*`, plus `rv32ua-p-*` where `ENABLE_A` = 1. |
| Gap | `G-10`/`G-25`/`G-26`/`G-27`/`G-20`/`G-08`/`G-19`/`G-29`/`G-07`/`G-30`/`G-31`/`G-22` closed, so no `rv32ui` image fails and `G-15` is not an `NFR-05` failure; what the row still owes is the `rv32um`, `rv32uc` and `rv32mi` legs its `shall` names (`G-06`, `G-13`) |
| Owner | verification lead |
| Status | **measured** - 43 pass / 0 fail: all **42 bundled images** and the one project-local image (`rv32ui-p-jalr_unaligned`) pass. The `rv32ui` leg of `A-09` is met; the row does not become `verified` here, because `NFR-05` also names the `rv32um`, `rv32uc` and `rv32mi` legs and only `rv32ui` is measured |

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

## Result - 2026-11-19 (WP-13, re-measured after the word-crossing split)

| Field | Value |
|---|---|
| RTL digest | `sha256:f84ea86b666a26d72f04647d8e771e9dc23da144b135cb1aa23544103a2d63ee` |
| TB digest | `sha256:7860d1b04faa5e91a7d98937c26df709e381dffd2886fb9d0316c8dce63cdab5` |
| Images | 43 = 42 bundled + 1 project-local (`rv32ui-p-jalr_unaligned`) |
| Pass | 43 (42 bundled + the local image) |
| Fail | 0 |
| Artefacts | `build/sanity/summary.json`, `build/sanity/<image>.log` |

This is the first measurement with **no failure at all**, and it supersedes the 42 pass / 1 fail verdict of
2026-11-18 (WP-9 and WP-11, kept in History below). The image that failed was `rv32ui-p-ma_data`: it presents
misaligned word and halfword loads and stores, and until WP-13 a crossing access left the core as one unaligned
beat, so the image stopped at `testnum=1`. WP-13 made the crossing access two beats, each confined to one word
(`FR-42`, `G-22`, observed by `T-52` as `sanity:rv32ui-p-ma_data` and the `no-misaligned-split` mutant), and the
image now writes its pass epilogue to `tohost`. The image count stays 43 because the split added no image:
`rv32ui-p-ma_data` moved from fail to pass, like every other image the earlier rows enumerate.

The per-image table below is the WP-13 run. Only `rv32ui-p-ma_data` changes status against the WP-11 row in
History; every other row is the same verdict at a later digest.

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
| `rv32ui-p-ma_data` | pass | - | pass (T-52) — the word-crossing split, `FR-42` |
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
| `FR-42` / `G-22` | **closed 2026-11-19 by WP-13**: a crossing access left the core as one unaligned beat. It now leaves as two beats, each confined to one word — beat 1 at the access's byte address with its strobes inside that word, beat 2 at `(base & ~32'h3) + 4` with the remaining strobes (`rtl/misaligned_split.sv`). | `T-52` (`sanity:rv32ui-p-ma_data`) passes and fails on the `no-misaligned-split` mutant; the image writes its pass epilogue to `tohost` | closed |

No failure is left and none of them is a waiver: the `rv32ui` leg of `NFR-05` is green at the digests above, and
`rv32ui-p-ma_data` — the last image in the table to go green — passes since WP-13 (`FR-42`, `T-52`). The `Q-11`
release blockers are now `G-04` and `G-11`; the release is still blocked by `A-09` and by the legs of `NFR-05`
this measurement does not cover (`rv32um`, `rv32uc`, `rv32mi`, owned by `FR-43`, `FR-44` and
`FR-24`/`FR-46`/`FR-47`).

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
| 2026-11-07 | `sha256:120b211f...` | 43 (42 + 1 local) | 42 | 1 | WP-8: retire probe + monitor-fed model (`G-28` closed); same one failure `ma_data` (`FR-42`) (TB `86bcd471...`) |
| 2026-11-18 | `sha256:120b211f...` | 43 (42 + 1 local) | 42 | 1 | WP-9: same one failure `ma_data` (`FR-42`); the `spike:` rows `T-47`/`T-48`/`T-49` run their images through the commit-trace comparison instead of a plain sanity run, so the sanity count is unchanged (TB `c8ba82d7...`) |
| 2026-11-18 | `sha256:b914f2e1...` | 43 (42 + 1 local) | 42 | 1 | WP-11: re-established after `scripts/verify/sanity/link.ld` moved every image to `0x80000000`; same one failure `ma_data` (`FR-42`), and `T-50` is a directed test, not an image (TB `c4bad285...`) |
| 2026-11-18 | `sha256:b914f2e1...` | 43 (42 + 1 local) | 42 | 1 | Re-run after the driver fix in `tb/env/agents/riscv_small_agent/riscv_small_driver.sv` (an unmatched fetch is answered with `inst_ready` before the program is entered, and warns once instead of 196 times); verdict unchanged, same one failure `ma_data` (`FR-42`), and the RTL digest did not move — only the testbench's (TB `066dce85...`) |
| 2026-11-19 | `sha256:f84ea86b...` | 43 (42 + 1 local) | 43 | 0 | WP-13: the word-crossing access is issued as two beats by `rtl/misaligned_split.sv` (`FR-42`/`G-22`) and a store is held in MA until its grant (`FR-38`/`G-18`); `rv32ui-p-ma_data` passes on its own `tohost` check and fails on the `no-misaligned-split` mutant, so no `rv32ui` image fails (TB `7860d1b0...`) |
