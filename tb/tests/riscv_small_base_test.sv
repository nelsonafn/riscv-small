//------------------------------------------------------------------------------
// Base test class for riscv_small
//------------------------------------------------------------------------------
// This UVM test serves as the base for all riscv_small tests, defining common 
// features like the colored report server.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : April 2024
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_BASE_TEST_SV
`define RISCV_SMALL_BASE_TEST_SV

class riscv_small_base_test extends uvm_test;

  /*
   * Components
   */
  riscv_small_environment env;
   
  /*
   * Register with factory
   */
  `uvm_component_utils(riscv_small_base_test)
     
  /*
   * Constructor
   */
  function new(string name = "riscv_small_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  /*
   * Build phase: instantiate components and replace report server
   */
  function void build_phase(uvm_phase phase);
    colored_report_server my_server;
    super.build_phase(phase);

    // Set the colored report server
    my_server = new("my_server");
    uvm_report_server::set_server(my_server);
    `uvm_info("BASE_TEST", "Colored Report Server set.", UVM_LOW)
    
    // Instantiate environment
    env = riscv_small_environment::type_id::create("env", this);
    `uvm_info("BASE_TEST", "Environment instantiated.", UVM_LOW)
  endfunction : build_phase

endclass : riscv_small_base_test

`endif
