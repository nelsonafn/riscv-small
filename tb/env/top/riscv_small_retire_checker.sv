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
//      (exact for a program that executes each placed word once; a loop needs
//      an execution count the image cannot express yet -- see
//      riscv_small_program_image, and T-46/P4 below)
//
// plus three claims about the relation between the two streams, which is what
// makes "retire" distinguishable from "fetch":
//
//   5. the program reached its end (`done`)          -- the drain signal
//   6. every fetched pc is an executed pc or a pc the program's control flow
//      skips                                         -- the SET form, true for
//                                                      any control flow
//   7. fetch - commit == |skip_pc ∩ fetched_pcs|      -- the COUNT form, asserted
//                                                      only when every fetched
//                                                      pc was fetched once
//
// Claim 6 is where a fetch-counting model stops being able to fake it: for a
// straight-line program fetches == commits, so the two streams are
// indistinguishable; a taken branch makes the core fetch a word that never
// retires, and the commit stream must still be the program.
//
// The count form alone is NOT the invariant. The PC is two fetch slots ahead of
// ID and the redirect is a registered PC update, so a taken branch lets exactly
// TWO fetches go regardless of how far it jumps (rtl/instruction_fetch.sv,
// rtl/control.sv). A program that skips two words therefore has
// fetch - commit == |skip_pc| by coincidence, which is why T-45 passed; a
// program that skips three fetches 11 and commits 9, and a checker asserting
// 3 would fail a correct core (T-46 is that program). The count form is kept
// for the case where it is still a constant -- no pc fetched twice, every fetch
// inside the image -- and is reported as "NOT asserted" otherwise, so a green
// run never claims a check it did not make.
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

  // Per-address accounting for claim 6/7, so a mismatch names the pc instead of
  // only a number. A squashed fetch leaves a fetch event with no commit at that
  // pc; whether that is legitimate depends on the address (a skipped word) and
  // on the control flow (a loop re-fetches a pc it re-executes).
  int unsigned fetch_pc_hits  [bit [31:0]]; // fetch events per pc
  int unsigned retire_pc_hits [bit [31:0]]; // commit events per pc
  bit [31:0]   fetched_pc_order [$];        // distinct fetched pcs, first-fetch order

  int unsigned unmapped_fetch_count = 0; // fetched pcs outside the image (not judged)
  int unsigned multfetch_pc_count   = 0; // pcs fetched more than once (loop / re-fetched target)
  int unsigned lost_fetch_count     = 0; // fetched, placed, not skipped, never retired
  int unsigned skipped_fetch_count  = 0; // fetch events at pcs the control flow skips
  bit          count_form_asserted  = 0; // claim 7 was checked, not skipped

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
      // would break the stream relation by one. The fetch checker owns that
      // verdict.
      if (!t.captured_inst_orphan) begin
        fetch_count++;
        if (!fetch_pc_hits.exists(t.captured_inst_addr))
          fetched_pc_order.push_back(t.captured_inst_addr);
        fetch_pc_hits[t.captured_inst_addr]++;
      end
      return;
    end
    if (!t.op_is_retire) return;

    retire_count++;
    retire_pc_hits[t.retire_pc]++;

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

  // ---- Claim 6/7 helpers ----------------------------------------------------

  function int unsigned fetched_hits(bit [31:0] pc);
    return fetch_pc_hits.exists(pc) ? fetch_pc_hits[pc] : 0;
  endfunction

  function int unsigned retired_hits(bit [31:0] pc);
    return retire_pc_hits.exists(pc) ? retire_pc_hits[pc] : 0;
  endfunction

  // The first pc whose fetch/commit accounting explains a count mismatch, so
  // the failure names an address instead of only a number. Under the
  // single-fetch gate of claim 7 a mismatch can only come from a pc whose
  // fetch events and commits disagree (the set claim already named it in that
  // case) or from a commit at a skipped address (RETIRE_SKIPPED did).
  function bit [31:0] count_offender();
    bit [31:0] pc;
    foreach (fetched_pc_order[i]) begin
      pc = fetched_pc_order[i];
      if (fetched_hits(pc) != retired_hits(pc)) return pc;
    end
    return 32'hdead_beef;
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (image == null || image.commit_target() == 0) return;

    // Claim 4/5: the program ran to its end.
    if (!done)
      `uvm_error("RETIRE_COUNT",
        $sformatf("the program executes %0d instruction(s) but only %0d retired: %0d retire event(s) observed, %0d mismatch(es), %0d skipped address(es) retired",
          image.commit_target(), checked_count, retire_count, mismatch_count, skipped_count))

    // Claim 6: every pc the core fetched, and the image can speak about, is
    // either an instruction the program executes (it retired at least once) or
    // an address the program's control flow skips. A fetch that is neither was
    // accepted and then silently lost; the address is named so the failure is
    // actionable.
    //
    // Judged only when the program reached its end: if it did not, RETIRE_COUNT
    // already explains the missing commits and this claim would report every
    // instruction still in flight. A fetch outside the image is counted and
    // reported, not judged -- the image cannot say what that address holds
    // (riscv_small_fetch_pair_checker owns that observation).
    foreach (fetched_pc_order[i]) begin
      bit [31:0] pc = fetched_pc_order[i];
      bit [31:0] placed;

      if (fetched_hits(pc) > 1) multfetch_pc_count++;

      if (!image.lookup_inst(pc, placed)) begin
        unmapped_fetch_count++;
        continue;
      end
      if (image.is_skipped(pc)) begin
        skipped_fetch_count += fetched_hits(pc);
        continue;
      end
      if (retired_hits(pc) == 0) begin
        lost_fetch_count++;
        // Judged only when the program reached its end: otherwise RETIRE_COUNT
        // owns the verdict and these pcs may be instructions still in flight.
        if (done)
          `uvm_error("RETIRE_FETCH_LOST",
            $sformatf("[RETIRE_FETCH_LOST #%0d] pc=0x%08h was fetched %0d time(s), is a word the program placed (0x%08h), and the program does not skip it -- yet it never retired",
              lost_fetch_count, pc, fetched_hits(pc), placed))
      end
    end

    // Claim 7: the count form of the same relation, asserted only where it is a
    // constant -- every fetched pc was fetched exactly once and the image knows
    // all of them. Then a discarded fetch can only be a skipped address the
    // front end reached, and fetch - commit == |skip_pc ∩ fetched_pcs|.
    //
    // A loop (or a forward branch whose target was already prefetched) fetches
    // an executed pc twice, and the difference is no longer the skipped set, so
    // the count is reported as not asserted instead of failing a correct core.
    // Claim 6, the set form, is what holds for any control flow.
    if (unmapped_fetch_count == 0 && fetch_count == fetched_pc_order.size()) begin
      bit [31:0] offender;

      count_form_asserted = 1;
      if (fetch_count != retire_count + skipped_fetch_count) begin
        offender = count_offender();
        `uvm_error("RETIRE_FETCH_COUNT",
          $sformatf("%0d fetch(es) and %0d commit(s): the difference is %0d, expected %0d = the skipped address(es) actually fetched; first unaccounted pc=0x%08h (fetched %0d time(s), retired %0d time(s)); %0d word(s) placed, %0d executed",
            fetch_count, retire_count, fetch_count - retire_count, skipped_fetch_count,
            offender, fetched_hits(offender), retired_hits(offender),
            image.inst_size(), image.commit_target()))
      end
    end
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
        fetch_count - retire_count, skipped_fetch_count,
        mismatch_count, skipped_count, extra_count, done),
      UVM_LOW)
    `uvm_info(get_full_name(),
      $sformatf("G-28 skip: pc(s) the control flow never executes:%s -- %0d retire event(s) at them",
        (skips == "") ? " none" : skips, skipped_count),
      UVM_LOW)
    `uvm_info(get_full_name(),
      $sformatf("G-28 fetch set: %0d distinct pc(s) fetched, %0d fetched more than once, %0d outside the image, %0d fetched, placed and never retired; count form %s",
        fetched_pc_order.size(), multfetch_pc_count, unmapped_fetch_count, lost_fetch_count,
        count_form_asserted ? "asserted (every pc fetched once, all inside the image)"
                            : "NOT asserted (a pc was fetched twice or the image does not know every fetch: the difference is not a constant)"),
      UVM_LOW)
  endfunction: report_phase

endclass: riscv_small_retire_checker

`endif
