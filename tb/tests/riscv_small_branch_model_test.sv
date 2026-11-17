//------------------------------------------------------------------------------
// Monitor-fed model test, taken-branch program (WP-8 follow-up: G-28)
//------------------------------------------------------------------------------
// The same shape as T-44 -- program image as configuration, model fed by the
// monitor only -- with the one program in the directed corpus whose control flow
// does not execute every instruction it places:
//
//   BEQ x0, x0, +12 at 0x08 skips the two stores at 0x0c and 0x10.
//
// That is what makes retire distinguishable from fetch: the core fetches 12
// words and retires 10, the two missing ones are exactly the discarded fetches,
// and the two skipped stores never reach write-back. T-44 (straight line) could
// not say that: there fetches == commits.
//
// The error channels are the checker's: RETIRE_PAIR (a commit that is not a
// placed word), RETIRE_SKIPPED (a commit at an address the branch skips),
// RETIRE_COUNT (the program did not run to its end), RETIRE_FETCH_COUNT (the
// fetch/commit difference is not the skipped set) and the scoreboard's SW
// comparison. The test owns the objection, the drain and the timeout.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_BRANCH_MODEL_TEST_SV
`define RISCV_SMALL_BRANCH_MODEL_TEST_SV

class riscv_small_branch_model_test extends riscv_small_monitor_model_test;

  `uvm_component_utils(riscv_small_branch_model_test)

  function new(string name = "riscv_small_branch_model_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  // The parent already published the configuration (expect_predictions, the
  // program image) and built the straight-line sequence; swap in the program
  // whose branch skips two instructions. The handle type is the parent's, and
  // body() is virtual, so the drain in the parent's run_phase still applies.
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    seq = riscv_small_branch_seq::type_id::create("seq");
  endfunction : build_phase

endclass : riscv_small_branch_model_test

`endif
