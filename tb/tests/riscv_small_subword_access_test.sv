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

  function new(string name = "riscv_small_subword_access_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    seq = riscv_small_subword_seq::type_id::create("seq");
  endfunction : build_phase

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("TEST_RUN", "Starting Sub-word Load Sequence (FR-12)", UVM_LOW)
    seq.start(env.riscv_small_agnt.sequencer);
    phase.drop_objection(this);
  endtask : run_phase

endclass : riscv_small_subword_access_test

`endif
