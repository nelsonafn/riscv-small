`ifndef RISCV_SMALL_COVERAGE
`define RISCV_SMALL_COVERAGE

// ============================================================================
// riscv_small_coverage
//
// Functional coverage collector. It subscribes to the MONITOR, so every sample
// is something the DUT actually did, never something the reference model
// predicted. Bins are named after the requirement they can prove:
//
//   cp_width          FR-09/FR-10/FR-11/FR-12: word, halfword and byte traffic
//   cp_lane           FR-11/FR-12: the byte lane selected by addr[1:0]
//   cp_dir            both directions on the data port
//   cp_subword_lane   FR-12: a lane other than 0 is reached by a sub-word access
//
// Author: Nelson Alves nelsonafn@gmail.com
// ============================================================================
class riscv_small_coverage extends uvm_subscriber #(riscv_small_transaction);
  `uvm_component_utils(riscv_small_coverage)

  riscv_small_transaction cov_trans;

  covergroup cg_mem with function sample(bit [1:0] width, bit [1:0] lane, bit is_write);
    option.per_instance = 1;

    cp_width: coverpoint width {
      bins byte_w = {2'b00};
      bins half_w = {2'b01};
      bins word_w = {2'b10};
    }

    cp_lane: coverpoint lane {
      bins lane0 = {2'b00};
      bins lane1 = {2'b01};
      bins lane2 = {2'b10};
      bins lane3 = {2'b11};
    }

    cp_dir: coverpoint is_write {
      bins read  = {1'b0};
      bins write = {1'b1};
    }

    // A word access is naturally aligned, so only sub-word accesses can reach
    // lanes 1-3. Sampling this one guarded keeps the word cases out of it
    // without ignoring any legal combination.
    cp_subword_lane: coverpoint lane iff (width != 2'b10) {
      bins lane0 = {2'b00};
      bins lane1 = {2'b01};
      bins lane2 = {2'b10};
      bins lane3 = {2'b11};
    }
  endgroup: cg_mem

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_mem = new();
  endfunction: new

  function void write(riscv_small_transaction t);
    $cast(cov_trans, t);
    cg_mem.sample(cov_trans.captured_data_wr_ctrl[1:0],
                  cov_trans.captured_data_addr[1:0],
                  cov_trans.op_is_data_write);
  endfunction: write

endclass: riscv_small_coverage

`endif
