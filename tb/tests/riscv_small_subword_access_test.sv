//------------------------------------------------------------------------------
// Sub-word access test for riscv_small
//------------------------------------------------------------------------------
// Evidence for FR-12: LB, LBU, LH and LHU select the byte or halfword lane of
// the word addressed by the effective address, then sign- or zero-extend it.
// The sequence stores every loaded register, so the reference model and the
// scoreboard decide the value through the data port.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : October 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_SUBWORD_ACCESS_TEST
`define RISCV_SMALL_SUBWORD_ACCESS_TEST

class riscv_small_subword_access_test extends riscv_small_base_test;

  `uvm_component_utils(riscv_small_subword_access_test)

  riscv_small_subword_seq seq;
  riscv_small_program_image image;

  function new(string name = "riscv_small_subword_access_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    // The sub-word sequence stores every loaded register, so the model does
    // predict; a run with no prediction is a vacuous pass (WP-8).
    uvm_config_db#(bit)::set(this, "*", "expect_predictions", 1);
    // Program image as configuration (C-16): the source word the loads read is
    // the model's initial data memory, and the checkers compare against it.
    image = riscv_small_program_image::type_id::create("program_image");
    uvm_config_db#(riscv_small_program_image)::set(this, "*", "program_image", image);
    super.build_phase(phase);
    seq = riscv_small_subword_seq::type_id::create("seq");
  endfunction : build_phase

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("TEST_RUN", "Starting Sub-word Load Sequence (FR-12)", UVM_LOW)
    seq.start(env.riscv_small_agnt.sequencer);
    wait_program_drain();
    phase.drop_objection(this);
  endtask : run_phase

endclass : riscv_small_subword_access_test

`endif
