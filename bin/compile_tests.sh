#!/bin/bash
echo "Compiling test "isa/rv32ui-p-addi"..."
echo "Make sure you have cloned riscv-tests and have riscv-toolchain installed!"
echo "\${RISCV_TESTS}=${RISCV_TESTS}"

CURRENT_DIR=`dirname $0`

riscv64-unknown-elf-objcopy -O verilog -j .text -j .text.startup -j .text.init -j .data \
--gap-fill 00000000 --reverse-bytes=4 ${RISCV_TESTS}/isa/rv32ui-p-addi \
-v --verilog-data-width 4  ${CURRENT_DIR}/../build/rv32ui-p-addi.hex