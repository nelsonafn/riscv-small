#!/bin/bash
echo "Use --R to run all, --g to gui, and -view top_sim.wcfg to load waveforms"

CURRENT_DIR=`dirname $0`
list=`${CURRENT_DIR}/srclist2path.sh "../srclist/riscv_small_tb.srclist"`
echo ${list}

xvlog  -L uvm -sv /opt/Xilinx/Vivado/2020.1/data/system_verilog/uvm_1.2/uvm_macros.svh ${list}
xelab  riscv_small_tb --timescale 1ns/1ps -L uvm -s top_sim --debug typical --mt 16 --incr
xsim   top_sim -testplusarg UVM_TESTNAME=myTest $@

