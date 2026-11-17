//------------------------------------------------------------------------------
// Basic test for riscv_small
//------------------------------------------------------------------------------
// This UVM test sets up the environment and sequence for the riscv_small verification.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : October 2023
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_BASIC_LOAD_STORE_TEST 
`define RISCV_SMALL_BASIC_LOAD_STORE_TEST

class riscv_small_basic_load_store_test extends riscv_small_base_test;
 
  /*
   * Declare component utilities for the test-case
   */
  `uvm_component_utils(riscv_small_basic_load_store_test)
 
  riscv_small_basic_load_store_seq   seq;
  riscv_small_program_image          image;
 
  /*
   * Constructor: new
   * Initializes the test with a given name and parent component.
   */
  function new(string name = "riscv_small_basic_load_store_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new
 
  /*
   * Build phase: Instantiate sequence
   * This phase constructs the sequence components.
   */
  virtual function void build_phase(uvm_phase phase);
    // Non-vacuity claim (WP-8): this program makes the model predict stores,
    // so a run that receives no prediction must fail instead of staying green.
    uvm_config_db#(bit)::set(this, "*", "expect_predictions", 1);
    // The program image is CONFIGURATION (C-16): the sequence fills it with
    // the words it built, the model reads it once for its initial data memory,
    // and the fetch/retire checkers compare against it. No stimulus flows here.
    image = riscv_small_program_image::type_id::create("program_image");
    uvm_config_db#(riscv_small_program_image)::set(this, "*", "program_image", image);
    super.build_phase(phase);
    seq = riscv_small_basic_load_store_seq::type_id::create("seq");
  endfunction : build_phase
 
  /*
   * Run phase: Start the sequence on the agent’s sequencer
   * This phase starts the sequence, which generates and sends transactions to the DUT.
   */
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("TEST_RUN", "Starting Basic Load/Store Sequence", UVM_LOW)
    seq.start(env.riscv_small_agnt.sequencer);
    wait_program_drain();
    phase.drop_objection(this);
  endtask : run_phase
 
endclass : riscv_small_basic_load_store_test

`endif












