`ifndef RISCV_SMALL_INTERFACE
`define RISCV_SMALL_INTERFACE

interface riscv_small_interface(input logic clk, reset);
  import riscv_definitions_pkg::*;

  // Instruction Memory controls
  logic inst_ready;
  instruction_u inst_data;
  dataBus_t inst_addr;
  logic inst_rd_en;
  
  // Data Memory controls
  logic data_ready;
  dataBus_u data_rd;
  logic data_rd_en_ma;
  logic data_wr_en_ma;
  dataBus_u data_wr;
  dataBus_u data_addr;
  logic [1:0] data_rd_wr_ctrl;

  ////////////////////////////////////////////////////////////////////////////
  // clocking block and modport declaration for driver 
  ////////////////////////////////////////////////////////////////////////////
  clocking dr_cb@(posedge clk) ;
    output inst_ready; 
    output inst_data;
    input  inst_addr;
    input  inst_rd_en;
    
    output data_ready;
    output data_rd;
    input  data_rd_en_ma;
    input  data_wr_en_ma;
    input  data_wr;
    input  data_addr;
    input  data_rd_wr_ctrl;
  endclocking
  
  modport drv (clocking dr_cb, input clk, reset);

  ////////////////////////////////////////////////////////////////////////////
  // clocking block and modport declaration for monitor 
  ////////////////////////////////////////////////////////////////////////////
  clocking rc_cb@(negedge clk) ;
    input inst_ready; 
    input inst_data;
    input inst_addr;
    input inst_rd_en;
    
    input data_ready;
    input data_rd;
    input data_rd_en_ma;
    input data_wr_en_ma;
    input data_wr;
    input data_addr;
    input data_rd_wr_ctrl;
  endclocking
  
  modport rcv (clocking rc_cb, input clk, reset);

endinterface

`endif
