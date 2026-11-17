//------------------------------------------------------------------------------
// Monitor-fed model test for riscv_small (WP-8: C-16 / G-28 / G-32)
//------------------------------------------------------------------------------
// The same program as T-01, run with the reference model fed ONLY by the
// monitor. Three claims:
//
//   G-32  every fetch the monitor publishes is the (pc, word) pair the program
//         placed there -- riscv_small_fetch_pair_checker against the program
//         image, which is configuration, not a transaction stream.
//   G-28  the commit stream is the program: riscv_small_retire_checker compares
//         the retire events, in order, against the image, so a flushed fetch is
//         proven not to execute and a pipeline bubble is proven not to retire.
//   C-16  the run is not vacuous: the model publishes store predictions with
//         the monitor as its only input (RM_NO_PREDICTION catches the opposite),
//         and the scoreboard compares them.
//
// Any UVM_ERROR is a FAIL. The test owns the objection and the timeout, and
// waits for the retire checker's `done` -- every image instruction retired --
// before dropping the objection, so the pipeline drains instead of the run
// ending on the last fetch.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_MONITOR_MODEL_TEST_SV
`define RISCV_SMALL_MONITOR_MODEL_TEST_SV

class riscv_small_monitor_model_test extends riscv_small_base_test;

  `uvm_component_utils(riscv_small_monitor_model_test)

  riscv_small_basic_load_store_seq seq;
  riscv_small_program_image        image;

  function new(string name = "riscv_small_monitor_model_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  // All configuration is published BEFORE super.build_phase(): the environment
  // and its children read it in their own build_phase.
  virtual function void build_phase(uvm_phase phase);
    uvm_config_db#(bit)::set(this, "*", "expect_predictions", 1);
    image = riscv_small_program_image::type_id::create("program_image");
    uvm_config_db#(riscv_small_program_image)::set(this, "*", "program_image", image);
    super.build_phase(phase);
    seq = riscv_small_basic_load_store_seq::type_id::create("seq");
  endfunction : build_phase

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("TEST_RUN", "Starting the monitor-fed model run (C-16/G-28/G-32)", UVM_LOW)

    seq.start(env.riscv_small_agnt.sequencer);

    // Drain: the program is complete when the retire stream delivered every
    // instruction the image placed (the base test owns the bound and the
    // timeout; the checker owns `done`).
    wait_program_drain();

    phase.drop_objection(this);
  endtask : run_phase

endclass : riscv_small_monitor_model_test

`endif
