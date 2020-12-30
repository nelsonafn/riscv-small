#!/bin/bash
echo "Use --R to run all and --g to gui"

xvlog  -L uvm -sv /opt/Xilinx/Vivado/2020.1/data/system_verilog/uvm_1.2/uvm_macros.svh \
../rtl/riscv_definitions.svh ../rtl/instruction_fetch.sv  
xelab  instruction_fetch --timescale 1ns/1ps -L uvm -s top_sim -debug typical
xsim   top_sim -testplusarg UVM_TESTNAME=myTest $@