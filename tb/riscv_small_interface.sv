`ifndef RISCV_SMALL_INTERFACE
`define RISCV_SMALL_INTERFACE

interface riscv_small_interface(input logic clk, rst_n);
  import riscv_definitions_pkg::*;

  logic clk_en; //[in] Clock Enable
  logic [3:0] exception; //[in] External trap cause (WP-14: 4 bits; WP-14b: the driver drives it)

  // WP-14 (§2.5, D13): the two platform straps of the CSR file. They are on the
  // interface -- and not in a module variable of the testbench top -- so they
  // have exactly ONE value in the run: the DRIVER drives them from the test's
  // configuration (the platform's stimulus) and the MONITOR observes the same
  // wire and publishes the value with every retire and trap event. That is what
  // lets the reference model predict `mhartid` (FR-32) and `time` (FR-49)
  // without a second source of truth (C-16).
  //
  // The initialisers are the value a passive agent sees: no driver, no
  // stimulus, both zero, and the model still predicts from the observation.
  logic [63:0] mtime;   //[in] Machine timer, the view time/timeh reads (FR-49)
  logic [3:0]  hart_id; //[in] Hart identifier, read as mhartid (FR-32)

  initial begin
    mtime   = '0;
    hart_id = '0;
    // FR-22/Q-35: no external trap request is standing. The DRIVER overwrites
    // this with the value the sequence scheduled (and returns it to zero), so
    // the passive agent -- which has no driver -- sees the same defined zero.
    exception = '0;
  end

  // Instruction Memory controls
  logic inst_ready;
  instruction_u inst_data;
  dataBus_t inst_addr;
  logic inst_rd_en;
  
  // Data Memory controls
  logic data_ready;
  dataBus_u data_rd;
  logic data_rd_en;
  logic data_wr_en;
  dataBus_u data_wr;
  logic [3:0] data_wr_strb;
  dataBus_u data_addr;
  logic [1:0] data_rd_wr_ctrl;

  ////////////////////////////////////////////////////////////////////////////
  // clocking block and modport declaration for driver 
  ////////////////////////////////////////////////////////////////////////////
  //clocking drv_cb@(posedge clk) ;
  //  default input #1step output #1step;
  modport drv_mp (
    input clk, 
    input rst_n,
    output clk_en,
    output exception,
    output mtime,
    output hart_id,
    output inst_ready, 
    output inst_data,
    input  inst_addr,
    input  inst_rd_en,
    
    output data_ready,
    output data_rd,
    input  data_rd_en,
    input  data_wr_en,
    input  data_wr,
    input  data_wr_strb,
    input  data_addr,
    input  data_rd_wr_ctrl
  );
  //endclocking
  
  //modport drv_mp (clocking drv_cb, input clk, rst_n);

  ////////////////////////////////////////////////////////////////////////////
  // clocking block and modport declaration for monitor 
  ////////////////////////////////////////////////////////////////////////////
  //clocking mon_cb@(negedge clk) ;
  //  default input #1step output #1step;
  modport mon_mp (
    input clk, 
    input rst_n,
    input clk_en,
    input exception,
    input mtime,
    input hart_id,
    input inst_ready, 
    input inst_data,
    input inst_addr,
    input inst_rd_en,
    
    input data_ready,
    input data_rd,
    input data_rd_en,
    input data_wr_en,
    input data_wr,
    input data_wr_strb,
    input data_addr,
    input data_rd_wr_ctrl
  );

  //endclocking
  
  //modport mon_mp (clocking mon_cb, input clk, rst_n);

  ////////////////////////////////////////////////////////////////////////////
  // modport declaration for duv 
  ////////////////////////////////////////////////////////////////////////////
  modport duv_mp (
    input clk,    //[in] Clock
    input rst_n,  //[in] Asynchronous reset active low
    input clk_en, //[in] Clock Enable
    input exception, //[in] exception
    input mtime,  //[in] Machine timer (FR-49)
    input hart_id,//[in] Hart identifier (FR-32)
    // Instruction Memory controls
    input inst_ready, //[in] Indicates that data instruction ready
    input inst_data, //[in] Data from instruction memory
    output inst_addr,//[out] Address of next instruction
    output inst_rd_en, //[out] Instruction memory read enable 
    // Data Memory controls
    input data_ready, //[in] Indicates that data is ready
    input data_rd, //[in] Data from data_memory
    output data_rd_en, //[out] Data memory read enable to be used with data_rd_wr_ctrl 
	  output data_wr_en, //[out] Data memory write enable to be used with data_rd_wr_ctrl
    output data_wr, //[out] Data to data_memory
    output data_wr_strb, //[out] Byte write strobe of data_wr, one bit per lane
    output data_addr,//[out] Address of next data
    output data_rd_wr_ctrl //[out] 2'b00 = 8bits, 2'b01 = 16bits, 2'b10 = 32bits,
  );

endinterface

`endif

////////////////////////////////////////////////////////////////////////////////
// Commit observation probe (WP-8 P3, G-28)
////////////////////////////////////////////////////////////////////////////////
// This is not a DUT pin interface: nothing drives it and the DUT is unchanged.
// It is the port list of `bind riscv_small riscv_small_retire_if u_retire (...)`
// in tb/riscv_small_tb.sv, so the testbench reads the write-back slot without a
// new port on the synthesizable top (wp-8 §3, decision 1).
//
// The commit rule lives HERE, in the probe, not in the RTL (decision 2):
// the write-back slot retires at the edge where the MA/WB register advances
// with a valid instruction leaving it. Sampling this at the clock edge reads
// the pre-edge value -- the instruction the register file writes at that same
// edge -- so a slot held by a data wait is counted once, when it leaves, never
// once per cycle it is held.
//
// It lives in this file because a new file would have to be listed in
// srclist/riscv_small_interface.srclist, which is the RTL author's tree; this
// library is already compiled before the agent package that declares the
// virtual interface handle.
`ifndef RISCV_SMALL_RETIRE_IF
`define RISCV_SMALL_RETIRE_IF

interface riscv_small_retire_if import riscv_definitions_pkg::*; (
  input logic         clk,          // sampling clock, no behaviour
  input logic         valid_wb,     // the WB slot holds a real instruction
  input dataBus_u     pc_wb,        // its PC
  input instruction_u inst_wb,      // its instruction word
  input logic         rd0_wr_en_wb, // it writes its destination register
  input regAddr_t     rd0_addr_wb,  // its destination register
  input dataBus_u     rd0_data_wb,  // the value it writes
  input logic         ma_wb_clk_en  // the MA/WB register advances this cycle
);
  logic     retire_valid; // the commit event: one per retired instruction
  dataBus_t retire_pc;    // the retired instruction's PC
  dataBus_t retire_inst;  // the retired instruction word
  regAddr_t retire_rd;    // its destination register
  dataBus_t retire_wdata; // the value it writes (valid with rd0_wr_en_wb)
  // rd0_wr_en_wb is exposed for the WP-9 commit-trace comparison (a retire that
  // writes nothing is still a commit); the ISS decodes the instruction itself.

  assign retire_valid = valid_wb && ma_wb_clk_en;
  assign retire_pc    = pc_wb.u_data;
  assign retire_inst  = inst_wb.memory_w;
  assign retire_rd    = rd0_addr_wb;
  assign retire_wdata = rd0_data_wb.u_data;

endinterface

`endif

////////////////////////////////////////////////////////////////////////////////
// Trap observation probe (WP-14 §4.2, E6)
////////////////////////////////////////////////////////////////////////////////
// A trap is the one architectural event the retire probe cannot see: the
// instruction that traps is flushed before write-back and NEVER retires, so a
// reference model fed only by retire is blind to exactly the event the trap
// path implements. Inferring it from a pc discontinuity does not work either --
// a jump produces the same discontinuity.
//
// So the entry is observed where the core decides it, and it is observed as an
// event, not as a verdict: trap_valid is already one cycle per trap taken, and
// the four signals are published verbatim. This probe derives nothing and
// filters nothing.
//
// trap_inst is published next to trap_cause on purpose: it is what lets the
// reference model DERIVE the expected cause from the instruction (illegal
// encoding -> 2, EBREAK -> 3, ECALL -> 11) and compare it against trap_cause.
// Publishing only the cause would leave the model repeating the DUT's value
// instead of predicting it (wp-14 §4.2), which is not evidence.
//
// Like the retire probe above, this is not a DUT pin interface: nothing drives
// it and no behaviour hangs off it -- the four signals it binds are the step-0
// stub of wp-14 §2.7, constants until the trap path lands. It is the port list
// of `bind riscv_small riscv_small_trap_if u_trap (...)` in
// tb/riscv_small_tb.sv, and it lives in this file for the same reason the
// retire probe does -- a new file would have to be listed in
// srclist/riscv_small_interface.srclist, which is the RTL author's tree, and
// this library is already compiled before the agent package that declares the
// virtual interface handle.
//
// The port types are the ones the DUT declares in the step-0 stub (§2.7):
// logic, dataBus_t, dataBus_t and logic [3:0], so the bind is a plain wire and
// not a conversion. dataBus_t is `logic [31:0]`, so the same probe also accepts
// a `logic [31:0]` or `instruction_u` declaration when the real trap path lands
// (measured: both connect, xvlog 2024.1).
`ifndef RISCV_SMALL_TRAP_IF
`define RISCV_SMALL_TRAP_IF

interface riscv_small_trap_if import riscv_definitions_pkg::*; (
  input logic          clk,        // sampling clock, no behaviour
  input logic          trap_valid, // the event: one cycle per trap the core takes
  input dataBus_t      trap_pc,    // PC of the instruction that trapped (mepc)
  input dataBus_t      trap_inst,  // that instruction, so the model can predict the cause
  input logic [3:0]    trap_cause  // the cause the core took (mcause[3:0])
);
  // The event is the ports themselves: a consumer reads trap_vif.trap_valid,
  // .trap_pc, .trap_inst and .trap_cause, exactly as the monitor reads
  // vif.clk on the pin interface. There is no rule to derive here.
endinterface

`endif
