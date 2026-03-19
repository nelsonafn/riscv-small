//------------------------------------------------------------------------------
// Environment module for riscv_small
//------------------------------------------------------------------------------
// This module instantiates agents, monitors, and other components for the riscv_small environment.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : October 2023
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_ENV
`define RISCV_SMALL_ENV

class riscv_small_environment extends uvm_env;
 
  /*
   * Declaration of components
   */
  riscv_small_agent riscv_small_agnt;
  riscv_small_ref_model ref_model;
  riscv_small_coverage coverage;
  riscv_small_scoreboard  sb;
   
  /*
   * Register with factory
   */
  `uvm_component_utils(riscv_small_environment)
     
  /*
   * Constructor
   */
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  /*
   * Build phase: instantiate components
   */
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    riscv_small_agnt = riscv_small_agent::type_id::create("riscv_small_agent", this);
    ref_model = riscv_small_ref_model::type_id::create("ref_model", this);
    coverage = riscv_small_coverage::type_id::create("coverage", this);
    sb = riscv_small_scoreboard::type_id::create("sb", this);
  endfunction : build_phase

  /*
   * Connect phase: hook up TLM ports
   */
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    riscv_small_agnt.driver.drv2rm_port.connect(ref_model.rm_export);
    riscv_small_agnt.monitor.mon2sb_port.connect(sb.sb_export_mon);
    ref_model.rm2sb_port.connect(coverage.analysis_export);
    ref_model.rm2sb_port.connect(sb.sb_export_rm);
  endfunction : connect_phase

endclass : riscv_small_environment

`endif




