#!/bin/bash
# Color variables
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
magenta='\033[0;35m'
cyan='\033[0;36m'
# Clear the color after that
clear='\033[0m'

echo "Compiling test "isa/rv32ui-p-addi"..."

if [[ ! ${RISCV_TESTS} ]]; then
    echo -e "${red}ERROR: Variable \${RISCV_TESTS} is undefined!"
    echo "       Make sure you have cloned riscv-tests and have riscv-toolchain installed!"
    echo "       Do not forget export tests path!"
    echo "       Clone repo git@github.com:riscv-software-src/riscv-tests.git" 
    echo -e "$       export RISCV_TESTS=/path/to/riscv-tests/${clear}\n"
    exit 1
else
    echo "\${RISCV_TESTS}=${RISCV_TESTS}"
fi

if [[ ! $(type -P riscv64-unknown-elf-objcopy) ]]; then
    echo -e "${red}ERROR: Do not forget compile and install git@github.com:riscv-collab/riscv-gnu-toolchain.git"
    echo "       Add source (It can be added into your ~/.bashrc)" 
    echo "       export RISCV=/opt/riscv/toolchain"
    echo -e "       export PATH=\${PATH:+\${PATH}:}\${RISCV}/bin${clear}\n"
    exit 1
fi


CURRENT_DIR=`dirname $0`

riscv64-unknown-elf-objcopy -O verilog -j .text -j .text.startup -j .text.init -j .data \
--gap-fill 00000000 --reverse-bytes=4 ${RISCV_TESTS}/isa/rv32ui-p-addi \
-v --verilog-data-width 4  ${CURRENT_DIR}/../build/rv32ui-p-addi.hex