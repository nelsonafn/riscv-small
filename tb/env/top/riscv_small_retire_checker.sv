`ifndef RISCV_SMALL_RETIRE_CHECKER
`define RISCV_SMALL_RETIRE_CHECKER

// ============================================================================
// riscv_small_retire_checker
//
// G-28 checker: the commit stream the MONITOR publishes must be the program the
// image describes. The oracle is riscv_small_program_image handed in by
// configuration, never the driver and never a transaction stream.
//
// The claims, per commit (NOT in image order -- a taken branch turns the
// executed stream into a subsequence, and a loop would reorder it):
//
//   1. retire_pc is a word the program placed:      image.lookup_inst(pc)
//   2. the word it carries is the one placed there: expected_word === retire_inst
//   3. retire_pc is not an address the branch skips: !image.is_skipped(pc)
//   4. the number of commits is the program's:       commit_target()
//
// plus two claims about the relation between the two streams, which is what
// makes "retire" distinguishable from "fetch":
//
//   5. the program reached its end (`done`)          -- the drain signal
//   6. fetch_count == retire_count + skipped count   -- every fetch the control
//                                                      flow discarded, and no
//                                                      other, is missing from
//                                                      the commit stream
//
// Claim 6 is where a fetch-counting model stops being able to fake it: for a
// straight-line program fetches == commits, so the two streams are
// indistinguishable; a taken branch makes fetches > commits by exactly the
// discarded fetches, and the commit stream must still be the program.
//
// `done` goes high when the last instruction the program executes has retired.
// The test that owns the run waits on it (bounded by clocks) before dropping
// the objection, so the pipeline drains and the counts are the program's.
//
// Commits after `done` are counted and reported, not judged.
//
// It is a subscriber on the monitor, like riscv_small_fetch_pair_checker, so it
// is built in BOTH agent modes and never stalls a run: no FIFO, no get().
// Without a configured image it only counts and says so in report_phase.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
// ============================================================================
class riscv_small_retire_checker extends uvm_subscriber #(riscv_small_transaction);
  `uvm_component_utils(riscv_small_retire_checker)

  // Oracle: the program as configuration. Null means "no image in this test".
  riscv_small_program_image image;

  int unsigned fetch_count    = 0; // fetch events published by the monitor
  int unsigned retire_count   = 0; // retire (commit) events published
  int unsigned checked_count  = 0; // commits compared against the image
  int unsigned mismatch_count = 0; // commits that were not a placed instruction
  int unsigned skipped_count  = 0; // commits at an address the branch skips
  int unsigned extra_count    = 0; // commits after the program's last instruction
  bit          done           = 0; // every instruction the program executes retired

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(riscv_small_program_image)::get(this, "", "program_image", image))
      image = null;
  endfunction

  // The two streams share the analysis port, so both are counted here: claim 6
  // needs them side by side, and neither may be taken from the other.
  function void write(riscv_small_transaction t);
    bit [31:0] expected_word;

    if (t.op_is_inst) begin
      // An orphan response is a protocol violation, not a fetch: counting it
      // would break claim 6 by one. The fetch checker owns that verdict.
      if (!t.captured_inst_orphan) fetch_count++;
      return;
    end
    if (!t.op_is_retire) return;

    retire_count++;

    if (image == null || image.commit_target() == 0) return;

    if (done) begin
      extra_count++;
      return;
    end

    // Claim 1/2: the commit is a word the program placed at that address.
    if (!image.lookup_inst(t.retire_pc, expected_word)) begin
      mismatch_count++;
      `uvm_error("RETIRE_PAIR",
        $sformatf("[RETIRE_PAIR #%0d] commit #%0d (seq=%0d) is outside the program image: pc=0x%08h inst=0x%08h",
          mismatch_count, checked_count, t.retire_seq, t.retire_pc, t.retire_inst))
    end else if (expected_word !== t.retire_inst) begin
      mismatch_count++;
      `uvm_error("RETIRE_PAIR",
        $sformatf("[RETIRE_PAIR #%0d] commit #%0d (seq=%0d) is not the instruction placed there: observed pc=0x%08h inst=0x%08h, expected inst=0x%08h",
          mismatch_count, checked_count, t.retire_seq, t.retire_pc, t.retire_inst, expected_word))
    end

    // Claim 3: an instruction the control flow skips must never retire. This is
    // the explicit form of "the branch really skipped it" -- counts alone
    // cannot say which instruction was lost.
    if (image.is_skipped(t.retire_pc)) begin
      skipped_count++;
      `uvm_error("RETIRE_SKIPPED",
        $sformatf("[RETIRE_SKIPPED #%0d] commit #%0d (seq=%0d) retired at pc=0x%08h, which the program's branch skips",
          skipped_count, checked_count, t.retire_seq, t.retire_pc))
    end

    checked_count++;
    if (checked_count == image.commit_target()) done = 1;
  endfunction: write

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (image == null || image.commit_target() == 0) return;

    // Claim 4/5: the program ran to its end.
    if (!done)
      `uvm_error("RETIRE_COUNT",
        $sformatf("the program executes %0d instruction(s) but only %0d retired: %0d retire event(s) observed, %0d mismatch(es), %0d skipped address(es) retired",
          image.commit_target(), checked_count, retire_count, mismatch_count, skipped_count))

    // Claim 6: the fetch stream minus the commits is exactly the discarded
    // fetches, no more and no less.
    if (fetch_count != retire_count + image.skip_pc.size())
      `uvm_error("RETIRE_FETCH_COUNT",
        $sformatf("%0d fetch(es) and %0d commit(s): the difference is %0d, expected %0d (the instruction(s) the control flow skips); %0d word(s) placed, %0d executed",
          fetch_count, retire_count, fetch_count - retire_count, image.skip_pc.size(),
          image.inst_size(), image.commit_target()))
  endfunction: check_phase

  function void report_phase(uvm_phase phase);
    string skips;

    if (image == null || image.commit_target() == 0) begin
      `uvm_info(get_full_name(),
        $sformatf("G-28 retire: %0d commit(s) and %0d fetch(es) counted, NONE compared (no program image configured)",
          retire_count, fetch_count),
        UVM_LOW)
      return;
    end

    skips = "";
    foreach (image.skip_pc[i])
      skips = {skips, $sformatf(" 0x%08h", image.skip_pc[i])};

    `uvm_info(get_full_name(),
      $sformatf("G-28 retire: %0d commit(s) of %0d executed, %0d fetch(es), difference %0d (expected %0d), %0d mismatch(es), %0d skipped address(es) retired, %0d after the program, done=%0d",
        retire_count, image.commit_target(), fetch_count,
        fetch_count - retire_count, image.skip_pc.size(),
        mismatch_count, skipped_count, extra_count, done),
      UVM_LOW)
    `uvm_info(get_full_name(),
      $sformatf("G-28 skip: pc(s) the control flow never executes:%s -- %0d retire event(s) at them",
        (skips == "") ? " none" : skips, skipped_count),
      UVM_LOW)
  endfunction: report_phase

endclass: riscv_small_retire_checker

`endif
