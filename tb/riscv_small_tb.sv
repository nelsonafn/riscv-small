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

  // WP-14 §2.5 / WP-14b (audit blocker 3, FR-22): the external trap cause is a
  // 4-bit DUT input, and it is NOT a local constant of this top. `exception`
  // lives on riscv_small_interface: the DRIVER asserts it for the cycle the
  // sequence scheduled, and the MONITOR observes the same wire and publishes it
  // with the trap event, so the reference model predicts the external cause from
  // the observation (D13) and a test can reach the pin without editing this
  // file. Before WP-14b this port was tied to a local `'0`: the external arm of
  // proc_trap_priority had no observation at all, and no test could give it one
  // (G-37).
  //
  // WP-14 §2.5: the CSR file's time base and this hart's id are DUT inputs too.
  // They are carried by riscv_small_interface (see the comment there): the
  // DRIVER drives them from the test's configuration and the MONITOR observes
  // the same wire, which is what D13 requires -- the model predicts `time` and
  // `mhartid` from what the monitor saw, never from configuration. A passive
  // agent has no driver, so the interface's initialiser holds both at zero.

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

  // Trap observation (WP-14 §4.2, E6): the trapping instruction is flushed
  // before write-back and never retires, so the retire probe above cannot see
  // it and a model fed only by retire would miss the trap entirely. The entry
  // is probed here instead, beside the commit probe and for the same reason:
  // no new port on the synthesizable top. The probe derives nothing -- the
  // event is trap_valid itself.
  bind riscv_small riscv_small_trap_if u_trap (
    .clk        (clk),
    .trap_valid (trap_valid),
    .trap_pc    (trap_pc),
    .trap_inst  (trap_inst),
    .trap_cause (trap_cause)
  );

  riscv_small duv(
    .clk(clk),
    .clk_en(clk_en),
    .rst_n(rst_n),
    .exception(intf.exception),
    .mtime(intf.mtime),
    .hart_id(intf.hart_id),

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
    // WP-14 §4.2: the trap probe, read the same way. The monitor publishes the
    // event it carries; nothing else in the environment touches it.
    uvm_config_db#(virtual riscv_small_trap_if)::set(uvm_root::get(), "*", "trap_vif", duv.u_trap);
    // FR-41 / G-33: publish the value the DUT actually elaborated with. This is
    // the ONE source of the expected reset vector in the testbench -- T-50
    // compares against it and no test or checker repeats the spec default. A
    // second elaboration with another RESET_VECTOR changes the expectation
    // without touching the testbench.
    uvm_config_db#(bit [31:0])::set(uvm_root::get(), "*", "reset_vector", 32'(duv.RESET_VECTOR));
  end

endmodule

`endif