//------------------------------------------------------------------------------
// Passive-agent test for riscv_small
//------------------------------------------------------------------------------
// Proves that the agent honours is_active=UVM_PASSIVE: the monitor is built,
// the driver and the sequencer are not. No stimulus is needed -- the claim is
// the configuration of the environment, not a DUT behaviour.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : October 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_PASSIVE_TEST_SV
`define RISCV_SMALL_PASSIVE_TEST_SV

class riscv_small_passive_test extends riscv_small_base_test;

  /*
   * Register with factory
   */
  `uvm_component_utils(riscv_small_passive_test)

  /*
   * Constructor
   */
  function new(string name = "riscv_small_passive_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  /*
   * Build phase: select the passive agent before the env is built.
   */
  virtual function void build_phase(uvm_phase phase);
    uvm_config_db#(uvm_active_passive_enum)::set(this, "*", "is_active", UVM_PASSIVE);
    super.build_phase(phase);
  endfunction : build_phase

  /*
   * Run phase: the environment is built, so the handles are final.
   */
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    if (env.riscv_small_agnt.driver != null)
      `uvm_error("PASSIVE", "is_active=UVM_PASSIVE built a driver")
    if (env.riscv_small_agnt.sequencer != null)
      `uvm_error("PASSIVE", "is_active=UVM_PASSIVE built a sequencer")
    if (env.riscv_small_agnt.monitor == null)
      `uvm_error("PASSIVE", "is_active=UVM_PASSIVE did not build the monitor")
    phase.drop_objection(this);
  endtask : run_phase

endclass : riscv_small_passive_test

`endif
