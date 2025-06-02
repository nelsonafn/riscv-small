#!/bin/bash
###############################################################################
# File: compile_tests.sh
# Description: Script to compile RISC-V ISA tests into Verilog hex format for simulation.
#              Converts the rv32ui-p-addi test from riscv-tests to a .hex file
#              suitable for loading into instruction memory.
#
# Usage:
#   Ensure RISCV_TESTS environment variable is set to the riscv-tests directory.
#   Ensure riscv64-unknown-elf-objcopy is in your PATH (from riscv-gnu-toolchain).
#
# Author: Nelson Alves Ferreira Neto
# License: BSD 2-Clause
###############################################################################

# Color variables for pretty output
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
magenta='\033[0;35m'
cyan='\033[0;36m'
clear='\033[0m' # Reset color

# Announce which test is being compiled
echo "Compiling test \"isa/rv32ui-p-addi\"..."

# Check if RISCV_TESTS environment variable is set
if [[ ! ${RISCV_TESTS} ]]; then
    echo -e "${red}ERROR: Variable \${RISCV_TESTS} is undefined!"
    echo "       Make sure you have cloned riscv-tests and have riscv-toolchain installed!"
    echo "       Do not forget to export the tests path!"
    echo "       Clone repo: git@github.com:riscv-software-src/riscv-tests.git" 
    echo -e "$       export RISCV_TESTS=/path/to/riscv-tests/${clear}\n"
    exit 1
else
    echo "\${RISCV_TESTS}=${RISCV_TESTS}"
fi

# Check if riscv64-unknown-elf-objcopy is available in PATH
if [[ ! $(type -P riscv64-unknown-elf-objcopy) ]]; then
    echo -e "${red}ERROR: riscv64-unknown-elf-objcopy not found!"
    echo "       Please compile and install: git@github.com:riscv-collab/riscv-gnu-toolchain.git"
    echo "       Add the toolchain to your PATH (can be added to ~/.bashrc):" 
    echo "       export RISCV=/opt/riscv/toolchain"
    echo -e "       export PATH=\${PATH:+\${PATH}:}\${RISCV}/bin${clear}\n"
    exit 1
fi

# Get the directory where this script is located
CURRENT_DIR=$(dirname "$0")

# Convert the RISC-V ELF test to Verilog hex format for simulation
riscv64-unknown-elf-objcopy -O verilog -j .text -j .text.startup -j .text.init -j .data \
    --gap-fill 00000000 --set-start=0 --reverse-bytes=4 \
    "${RISCV_TESTS}/isa/rv32ui-p-addi" \
    -v --verilog-data-width 4 \
    "${CURRENT_DIR}/../build/rv32ui-p-addi.hex"

# Check if objcopy succeeded
if [[ $? != 0 ]]; then
    echo -e "${red}ERROR: Error detected while compiling test!${clear}"
    exit 1
fi

# Replace the first line of the hex file with the address marker required by the simulator
sed -i.bak "1 s/.*/@00000000/" "${CURRENT_DIR}/../build/rv32ui-p-addi.hex"
