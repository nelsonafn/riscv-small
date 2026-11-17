`ifndef RISCV_SMALL_INTERFACE
`define RISCV_SMALL_INTERFACE

interface riscv_small_interface(input logic clk, rst_n);
  import riscv_definitions_pkg::*;

  logic clk_en; //[in] Clock Enable
  logic exception; //[in] exception

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
