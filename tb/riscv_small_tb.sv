`ifndef RISCV_SMALL_TB_TOP
`define RISCV_SMALL_TB_TOP
`include "uvm_macros.svh"

import uvm_pkg::*;

module riscv_small_tb;
   
  import riscv_definitions_pkg::*;
  import riscv_small_test_list_pkg::*;

  parameter cycle = 10;
  bit clk;
  bit reset;
  
  initial begin
    clk = 0;
    forever #(cycle/2) clk = ~clk;
  end

  initial begin
    reset = 1;
    #(cycle*5) reset = 0;
  end
  
  riscv_small_interface intf(clk, reset);
  
  // Add clock enables manually required by DUT
  logic clk_en = 1;
  logic exception = 0;

  riscv_small dut_inst(
    .clk(clk),
    .clk_en(clk_en),
    .rst_n(~reset),
    .exception(exception),

    // Instruction Memory controls
    .inst_ready(intf.inst_ready),
    .inst_data(intf.inst_data),
    .inst_addr(intf.inst_addr),
    .inst_rd_en(intf.inst_rd_en),

    // Data Memory controls
    .data_ready(intf.data_ready),
    .data_rd(intf.data_rd),
    .data_rd_en_ma(intf.data_rd_en_ma),
    .data_wr_en_ma(intf.data_wr_en_ma),
    .data_wr(intf.data_wr),
    .data_addr(intf.data_addr),
    .data_rd_wr_ctrl(intf.data_rd_wr_ctrl)
  );
  
  initial begin
    run_test();
  end
  
  initial begin
    uvm_config_db#(virtual riscv_small_interface)::set(uvm_root::get(), "*", "intf", intf);
  end

endmodule

`endif