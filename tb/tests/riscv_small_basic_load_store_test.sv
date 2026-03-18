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

class riscv_small_basic_load_store_test extends uvm_test;
 
  /*
   * Declare component utilities for the test-case
   */
  `uvm_component_utils(riscv_small_basic_load_store_test)
 
  riscv_small_environment env;
  riscv_small_basic_load_store_seq   seq;
 
  /*
   * Constructor: new
   * Initializes the test with a given name and parent component.
   */
  function new(string name = "riscv_small_basic_load_store_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new
 
  /*
   * Build phase: Instantiate environment and sequence
   * This phase constructs the environment and sequence components.
   */
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = riscv_small_environment::type_id::create("env", this);
    seq = riscv_small_basic_load_store_seq::type_id::create("seq");
  endfunction : build_phase
 
  /*
   * Run phase: Start the sequence on the agent’s sequencer
   * This phase starts the sequence, which generates and sends transactions to the DUT.
   */
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq.start(env.riscv_small_agnt.sequencer);
    phase.drop_objection(this);
  endtask : run_phase
 
endclass : riscv_small_basic_load_store_test

`endif












