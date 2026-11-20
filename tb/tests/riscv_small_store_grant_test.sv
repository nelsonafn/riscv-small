//------------------------------------------------------------------------------
// Store grant test for riscv_small (WP-13 P3: FR-38, G-18)
//------------------------------------------------------------------------------
// One claim: a store completes only in a cycle in which the data memory grants
// it. The test configures the memory BFM to withhold the grant for two cycles
// (FR-38's acceptance cell) and enables riscv_small_store_grant_checker, which
// judges the monitor's publication of each data access.
//
// The delay is configuration and lives HERE, not in the driver: the driver is a
// BFM that obeys it, and with the delay at 0 the directed memory answers exactly
// as it did before the option existed (proven by the 47-test log diff in the WP
// report, not by a green count).
//
// The scoreboard still compares the two stores' address/strobes/data and is
// green in both worlds -- the fields are right, the completion is not -- so the
// verdict here is the protocol checker's alone. That is deliberate: T-53 is the
// evidence for FR-38, and a test whose only checker agrees with the defect is
// not evidence.
//
// The test owns the objection and the clock-bounded drain; the checker owns the
// verdict.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_STORE_GRANT_TEST
`define RISCV_SMALL_STORE_GRANT_TEST

class riscv_small_store_grant_test extends riscv_small_base_test;

  `uvm_component_utils(riscv_small_store_grant_test)

  // FR-38's acceptance cell: "a data memory that withholds the grant for two
  // cycles still receives exactly one store". Two edges of withheld grant, so
  // the core must hold the access for at least three cycles before it completes.
  localparam int unsigned READY_DELAY = 2;

  riscv_small_store_grant_seq seq;
  riscv_small_program_image   image;

  function new(string name = "riscv_small_store_grant_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    // Both stores are reported by SW and predicted by the model, so they must be
    // compared: a run with no prediction is a vacuous pass (WP-8 guard).
    uvm_config_db#(bit)::set(this, "*", "expect_predictions", 1);
    // The stimulus that makes FR-38 observable: the memory withholds the grant.
    // Configuration is read in build_phase, so it is set before the components
    // are built -- a sequence cannot set it, it runs too late.
    uvm_config_db#(int unsigned)::set(this, "*", "data_ready_delay", READY_DELAY);
    // The claim: only this test judges a write that ended without a grant.
    uvm_config_db#(bit)::set(this, "*", "store_grant_check", 1);
    // Program image as configuration (C-16): the data words the program reads
    // are the model's initial data memory, and the retire checker compares the
    // commit stream against the same image.
    image = riscv_small_program_image::type_id::create("program_image");
    uvm_config_db#(riscv_small_program_image)::set(this, "*", "program_image", image);
    super.build_phase(phase);
    seq = riscv_small_store_grant_seq::type_id::create("seq");
  endfunction : build_phase

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("TEST_RUN",
      $sformatf("Starting store-grant run (FR-38/G-18): two stores, data_ready withheld for %0d clock edges", READY_DELAY),
      UVM_LOW)
    seq.start(env.riscv_small_agnt.sequencer);
    // Ends on the checker's `done`, bounded by clocks: the pipeline holds four
    // more instructions when the last fetch is answered, and dropping the
    // objection there would lose the last commits and their comparisons.
    wait_program_drain();
    phase.drop_objection(this);
  endtask : run_phase

endclass : riscv_small_store_grant_test

`endif
