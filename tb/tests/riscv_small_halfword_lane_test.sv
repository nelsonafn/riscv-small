//------------------------------------------------------------------------------
// Halfword lane test for riscv_small (WP-13 P1: FR-11, FR-12, G-34)
//------------------------------------------------------------------------------
// One claim: a halfword access at byte offset 1 respects addr[0], in both
// directions. LH/LHU must take bytes 1-2 of the addressed word, and SH must
// write bytes 1-2 -- not bytes 0-1.
//
// Offset 1 only. A halfword at offset 3 spans bytes 3-4 and therefore crosses
// the word boundary: that is the split (FR-42/G-22, T-52) and cannot pass until
// P6, so it is not claimed here.
//
// The oracle is the reference model plus the scoreboard: the sequence stores
// every value it wants compared with SW, the model executes the loads and the
// store from the retire stream in its own architectural state, and the
// scoreboard compares the SW the monitor observed against the prediction. The
// store half rides the same path -- the program reads the word back with LW and
// reports it with SW -- because riscv_small_strb_checker only enforces strobe
// <-> width coherence and 4'b0011 is a legal halfword pattern.
//
// This test owns the objection and the clock-bounded drain; the scoreboard owns
// the verdict.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_HALFWORD_LANE_TEST
`define RISCV_SMALL_HALFWORD_LANE_TEST

class riscv_small_halfword_lane_test extends riscv_small_base_test;

  `uvm_component_utils(riscv_small_halfword_lane_test)

  riscv_small_halfword_lane_seq seq;
  riscv_small_program_image     image;

  function new(string name = "riscv_small_halfword_lane_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    // The program reports every value with SW, so the model does predict; a run
    // with no prediction is a vacuous pass (WP-8 non-vacuity guard).
    uvm_config_db#(bit)::set(this, "*", "expect_predictions", 1);
    // Program image as configuration (C-16): the source words the program reads
    // are the model's initial data memory, and the retire checker compares the
    // commit stream against the same image.
    image = riscv_small_program_image::type_id::create("program_image");
    uvm_config_db#(riscv_small_program_image)::set(this, "*", "program_image", image);
    super.build_phase(phase);
    seq = riscv_small_halfword_lane_seq::type_id::create("seq");
  endfunction : build_phase

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("TEST_RUN",
      "Starting halfword-lane run (FR-11/FR-12/G-34): LH/LHU/SH at offset 1",
      UVM_LOW)
    seq.start(env.riscv_small_agnt.sequencer);
    // Ends on the checker's `done`, bounded by clocks: the pipeline holds four
    // more instructions when the last fetch is answered, and dropping the
    // objection there would lose the last commits and their comparisons.
    wait_program_drain();
    phase.drop_objection(this);
  endtask : run_phase

endclass : riscv_small_halfword_lane_test

`endif
