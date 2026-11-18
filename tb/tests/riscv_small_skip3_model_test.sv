//------------------------------------------------------------------------------
// Monitor-fed model test, three-instruction skip (WP-9 P1: the G-28 invariant)
//------------------------------------------------------------------------------
// The same shape as T-45 -- program image as configuration, model fed only by
// the monitor -- with a program whose taken branch skips THREE words:
//
//   BEQ x0, x0, +16 at 0x08 targets 0x18, skipping 0x0c, 0x10 and 0x14.
//
// The point is the invariant, not the branch. The front end lets exactly two
// fetch slots go when a branch is taken (the PC is two slots ahead of ID and
// the redirect is a registered PC update), so this program fetches 11 words and
// commits 9: the difference is 2 while the program skips 3. A checker that
// asserts fetch - commit == |skip_pc| is wrong here even though the core is
// right; T-45 passed only because its 2-word skip matched the front-end depth.
//
// What must hold instead, and what this test exercises:
//   - 9 commits, each a word the image placed, none at a skipped address;
//   - every fetched pc is either executed (retired at least once) or skipped:
//     0x0c and 0x10 are fetched and skipped, 0x14 is skipped and never
//     fetched, and no fetched pc is silently lost;
//   - the count form, asserted only when no pc is fetched twice, is
//     fetch - commit == the skipped addresses actually fetched (2).
//
// The error channels are the checker's: RETIRE_PAIR, RETIRE_SKIPPED,
// RETIRE_COUNT, RETIRE_FETCH_LOST (a fetched pc that is neither executed nor
// skipped), RETIRE_FETCH_COUNT (the gated count) and the scoreboard's SW
// comparison. The test owns the objection, the drain and the timeout.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_SKIP3_MODEL_TEST_SV
`define RISCV_SMALL_SKIP3_MODEL_TEST_SV

class riscv_small_skip3_model_test extends riscv_small_monitor_model_test;

  `uvm_component_utils(riscv_small_skip3_model_test)

  function new(string name = "riscv_small_skip3_model_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  // The parent already published the configuration (expect_predictions, the
  // program image) and built the straight-line sequence; swap in the program
  // whose branch skips three instructions. The handle type is the parent's, and
  // body() is virtual, so the drain in the parent's run_phase still applies.
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    seq = riscv_small_skip3_seq::type_id::create("seq");
  endfunction : build_phase

endclass : riscv_small_skip3_model_test

`endif
