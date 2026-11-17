`ifndef RISCV_SMALL_TB_TOP
`define RISCV_SMALL_TB_TOP
`include "uvm_macros.svh"

import uvm_pkg::*;

module riscv_small_tb;
   
  import riscv_definitions_pkg::*;
  import riscv_small_test_list_pkg::*;

  parameter cycle = 10;
  bit clk;
  bit rst_n;
  
  initial begin
    clk = 0;
    forever #(cycle/2) clk = ~clk;
  end

  initial begin
    rst_n = 0;
    #(cycle*5) rst_n = 1;
  end
  
  riscv_small_interface intf(clk, rst_n);
  
  // Add clock enables manually required by DUT
  logic clk_en = 1;
  logic exception = 0;

  // The monitor reads clk_en to gate both sides of the instruction handshake
  // (wp-8 §3.1.3 R10). The interface signal was never driven, so it stayed x
  // and that gate was not real; give it the same value the DUT sees.
  assign intf.clk_en = clk_en;

  // Commit observation (WP-8 P3, G-28): bind the probe inside the DUT so the
  // testbench sees the write-back slot without a new port on the synthesizable
  // top. The bound instance lives in the target's scope, hence duv.u_retire
  // below; the interface derives retire_valid itself (wp-8 §3, decision 2).
  bind riscv_small riscv_small_retire_if u_retire (
    .clk          (clk),
    .valid_wb     (valid_wb),
    .pc_wb        (pc_wb),
    .inst_wb      (inst_wb),
    .rd0_wr_en_wb (rd0_wr_en_wb),
    .rd0_addr_wb  (rd0_addr_wb),
    .rd0_data_wb  (rd0_data_wb),
    .ma_wb_clk_en (ma_wb_clk_en)
  );

  riscv_small duv(
    .clk(clk),
    .clk_en(clk_en),
    .rst_n(rst_n),
    .exception(exception),

    // Instruction Memory controls
    .inst_ready(intf.inst_ready),
    .inst_data(intf.inst_data),
    .inst_addr(intf.inst_addr),
    .inst_rd_en(intf.inst_rd_en),

    // Data Memory controls
    .data_ready(intf.data_ready),
    .data_rd(intf.data_rd),
    .data_rd_en_ma(intf.data_rd_en),
    .data_wr_en_ma(intf.data_wr_en),
    .data_wr(intf.data_wr),
    .data_wr_strb(intf.data_wr_strb),
    .data_addr(intf.data_addr),
    .data_rd_wr_ctrl(intf.data_rd_wr_ctrl)
  );
  
  initial begin
    run_test();
  end
  
  initial begin
    uvm_config_db#(virtual riscv_small_interface)::set(uvm_root::get(), "*", "intf", intf);
    // The bound probe is read through a virtual interface, exactly like intf.
    uvm_config_db#(virtual riscv_small_retire_if)::set(uvm_root::get(), "*", "retire_vif", duv.u_retire);
  end

endmodule

`endif