#!/bin/bash
# -----------------------------------------------------------------------------
# proj_config.sh
#
# This script is used to configure environment variables required for building
# and running the RISC-V small project. 
#
# IMPORTANT:
# Update the following environment variables according to your machine setup:
#   - TOOLCHAIN_PATH: Path to the RISC-V toolchain binaries.
#   - PROJECT_ROOT:   Root directory of the project.
#   - RISCV_TARGET:   Target architecture for the build (e.g., riscv32-unknown-elf).
#
# Make sure to source this script in your shell session:
#   source /path/to/proj_config.sh
# -----------------------------------------------------------------------------

# Set the path to the RISC-V tests directory
export RISCV_TESTS=~/Projetos/riscv-tests/

# Set the path to the RISC-V toolchain installation
export RISCV=/opt/riscv/

# Add the RISC-V toolchain binaries to the PATH environment variable
export PATH=${PATH:+${PATH}:}${RISCV}/bin

# Source the Xilinx Vivado environment setup script
source /opt/Xilinx/Vivado/2024.1/.settings64-Vivado.sh