//------------------------------------------------------------------------------
// Environment module for riscv_small
//------------------------------------------------------------------------------
// This module instantiates agents, monitors, and other components for the riscv_small environment.
//
// The sequence publishes the program item on `program_port`; the reference
// model subscribes to it in the directed mode. The driver never feeds the
// reference. In sanity mode there is no reference model and no scoreboard: the
// sanity checker component watches the monitor and owns the verdict.
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
  riscv_small_agent          riscv_small_agnt;
  riscv_small_ref_model      ref_model;
  riscv_small_coverage       coverage;
  riscv_small_scoreboard     sb;
  riscv_small_sanity_checker sanity_checker;

  /*
   * Program item published by the sequence/test. The reference model
   * subscribes here; a passive environment may leave it unconnected.
   */
  uvm_analysis_port#(riscv_small_transaction) program_port;

  // The image path has no directed transaction for the ISS to predict, and the
  // scoreboard would block forever on rm_fifo.get().
  bit sanity_mode;

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
    if (!uvm_config_db#(bit)::get(this, "", "sanity_mode", sanity_mode))
      sanity_mode = 0;
    program_port = new("program_port", this);
    riscv_small_agnt = riscv_small_agent::type_id::create("riscv_small_agent", this);
    coverage = riscv_small_coverage::type_id::create("coverage", this);
    if (!sanity_mode) begin
      ref_model = riscv_small_ref_model::type_id::create("ref_model", this);
      sb = riscv_small_scoreboard::type_id::create("sb", this);
    end else begin
      sanity_checker = riscv_small_sanity_checker::type_id::create("sanity_checker", this);
    end
  endfunction : build_phase

  /*
   * Connect phase: hook up TLM ports
   */
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Coverage is sampled from what the DUT did, never from what the model predicted.
    riscv_small_agnt.monitor.mon2sb_port.connect(coverage.analysis_export);
    if (!sanity_mode) begin
      // The reference model is fed by the sequence, not by the driver.
      program_port.connect(ref_model.rm_export);
      riscv_small_agnt.monitor.mon2sb_port.connect(sb.sb_export_mon);
      ref_model.rm2sb_port.connect(sb.sb_export_rm);
    end else begin
      riscv_small_agnt.monitor.mon2sb_port.connect(sanity_checker.checker_export);
    end
    // Sequences fetch this at run time; the driver never sees it.
    uvm_config_db#(uvm_analysis_port#(riscv_small_transaction))::set(this, "*", "program_port", program_port);
  endfunction : connect_phase

endclass : riscv_small_environment

`endif
