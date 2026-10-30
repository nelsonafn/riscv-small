# NFR-05 - bundled RISC-V test suite

| Field | Value |
|---|---|
| Requirement | The core shall pass every applicable image of the bundled RISC-V test suite: `rv32ui-p-*`, `rv32um-p-*`, `rv32uc-p-*` and `rv32mi-p-*`, plus `rv32ua-p-*` where `ENABLE_A` = 1. |
| Gap | `G-10` |
| Owner | verification lead |
| Status | not measurable (harness ready) |

## Method

`scripts/verify/sanity.cmake` owns the whole pipeline: at configure time it builds each image out-of-tree with the
RISC-V toolchain, converts it to a Verilog hex (`build/sanity_tests/hex/<image>.hex`) and extracts the `tohost`
address from the ELF with `riscv64-unknown-elf-nm` (never from a literal, because the linker script can change;
`build/sanity_tests/tohost/<image>`); at run time it simulates with `+HEX=<hex> +TOHOST=<addr>` through CTest and
judges the verdict line. The testbench must print `SANITY: PASS` or `SANITY: FAIL <testnum>`; if that line never
appears the run is `not_measurable`, never `pass`.

## Command

```bash
make sanity                               # every rv32ui-p-* image (42 today)
make sanity SANITY_ARGS="rv32ui-p-add"
make sanity SANITY_ARGS="--compile-only"  # build the images only
make compile_sanity_images                # same build step, from CMake
```

## Result

`not measurable` - the image list and the hex conversion work (`build/sanity_tests/hex/rv32ui-p-addi.hex` is
produced), but `tb/tests/riscv_small_sanity_test.sv` does not exist, so nothing consumes `+HEX` (`G-10`). The script
records this in `build/sanity/summary.json` with `"status": "not_measurable"`.

## History

| Date | RTL digest | Images | Pass | Fail | Method |
|---|---|---|---|---|---|
| 2026-10-28 | `sha256:34db4d37...` | 42 available, 0 run | - | - | `G-10` |
