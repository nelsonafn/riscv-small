//------------------------------------------------------------------------------
// Corner test for riscv_small
//------------------------------------------------------------------------------
// This UVM test triggers the corner case sequence using factory overrides.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : February 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_CORNER_TEST 
`define RISCV_SMALL_CORNER_TEST

class riscv_small_corner_test extends riscv_small_basic_load_store_test;
 
  /*
   * Declare component utilities for the test-case
   */
  `uvm_component_utils(riscv_small_corner_test)
 
  /*
   * Constructor: new
   */
  function new(string name = "riscv_small_corner_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new
 
  /*
   * Build phase: Override the default sequence type specifically for this test
   */
  virtual function void build_phase(uvm_phase phase);
    // When the basic test tries to create "riscv_small_basic_load_store_seq", this override forces it 
    // to instantiate the "riscv_small_corner_seq" instead!
    riscv_small_basic_load_store_seq::type_id::set_type_override(riscv_small_corner_seq::get_type());
    super.build_phase(phase);
  endfunction : build_phase
 
endclass : riscv_small_corner_test

`endif
