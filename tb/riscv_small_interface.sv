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
    output data_addr,//[out] Address of next data
    output data_rd_wr_ctrl //[out] 2'b00 = 8bits, 2'b01 = 16bits, 2'b10 = 32bits,
  );

endinterface

`endif
