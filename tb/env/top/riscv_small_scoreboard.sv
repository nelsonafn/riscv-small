`ifndef RISCV_SMALL_SCOREBOARD
`define RISCV_SMALL_SCOREBOARD

// ============================================================================
// riscv_small_scoreboard
//
// UVM Scoreboard: compares what the Reference Model (ISS) predicted with what
// the Monitor observed on the DUT. It is the only component that prints a
// verdict and raises an error; the monitor observes, the model predicts.
//
// Three claims, matched positionally 1:1 because the model is a pure function
// of the same observation stream:
//
//   STORE   every observed data write against the store contract the model
//           predicts -- byte address, byte strobes, lane-placed data word
//           (FR-11/FR-12/FR-42, WP-6..WP-13);
//   RETIRE  every observed commit against the model's expectation: whether the
//           instruction writes its destination register and with which value
//           (FR-47/FR-32/FR-37/FR-49/FR-51/FR-52), or -- for an encoding that
//           owes a trap -- that it must not have retired at all (FR-24,
//           FR-47, FR-50, FR-25);
//   TRAP    every observed trap against the cause the model DERIVED FROM
//           `trap_inst` (FR-22/FR-25/FR-50), and against the expectation that
//           the instruction was illegal at all (FR-52: a write to `mtval` is
//           accepted and ignored; FR-50: CSRRS with rs1 = x0 never traps).
//
// The (mepc, mcause) pair is compared where it is architecturally visible: the
// handler reads both with CSRRS, so the model's prediction for those reads is
// the pair the trap event must have produced. A DUT that keeps its trap state
// in registers nothing can read fails here, not on a comment.
//
// Non-vacuity (WP-8 decision 6, extended by WP-14 and WP-14b):
//   `expect_predictions`  at least one STORE prediction; a model that receives
//                         nothing cannot fail, so "green with 0 comparisons" is
//                         an error (T-09 has no stimulus and does not raise it);
//   `expect_csr_claims`   at least one CSR retire comparison (WP-14);
//   `expected_traps`      that many trap observations; fewer is an error naming
//                         the count, because a test that claimed traps and saw
//                         none has proven nothing. With `expected_traps_exact`
//                         one MORE is an error too: one request, one entry
//                         (D12b, WP-14b);
//   `trap_cocycle_check`  a commit must have been observed in the trap's own
//                         cycle, so the ordering claim was really exercised
//                         (WP-14b, audit blocker 1);
//   `trap_hold_check`     the trap must belong to a cycle at or after the
//                         crossing access's second beat, so D12's deferral was
//                         really exercised (WP-14b, audit blocker 4).
//
// `done` is the checker's end-of-program signal: it goes high when the commit
// at `last_pc` (published by the test from the program it built) is observed.
// The test waits on it, bounded by clocks, before dropping the objection -- the
// objection is the test's, the verdict is this component's.
//
// Author: Nelson Alves nelsonafn@gmail.com
// ============================================================================

`uvm_analysis_imp_decl(_pred)

class riscv_small_scoreboard extends uvm_scoreboard;
  
  `uvm_component_utils(riscv_small_scoreboard)

  // ---- Input Ports ---------------------------------------------------------
  uvm_analysis_export #(riscv_small_transaction) sb_export_mon; // from Monitor
  // The prediction port is an implementation, not a plain export, so the
  // scoreboard can count what arrived before the run_phase consumes it: the
  // count must be right even when no store was ever observed.
  uvm_analysis_imp_pred #(riscv_small_transaction, riscv_small_scoreboard) sb_export_rm;

  // ---- Internal FIFOs ------------------------------------------------------
  uvm_tlm_analysis_fifo #(riscv_small_transaction) mon_fifo;
  uvm_tlm_analysis_fifo #(riscv_small_transaction) rm_fifo;          // stores
  uvm_tlm_analysis_fifo #(riscv_small_transaction) retire_pred_fifo; // commits
  uvm_tlm_analysis_fifo #(riscv_small_transaction) trap_pred_fifo;   // traps

  // ---- Configuration -------------------------------------------------------
  bit          expect_predictions = 0; // this test claims the model predicts a store
  bit          expect_csr_claims  = 0; // this test claims CSR comparisons (WP-14)
  int unsigned expected_traps     = 0; // traps the program takes (WP-14)
  // WP-14b: `expected_traps` is a lower bound by default, because a run may
  // legitimately observe more (a re-entered handler). A test that claims a trap
  // was taken EXACTLY once sets this, and then one extra observation fails: the
  // claim is "one entry for one request", which is D12b's contract.
  bit          expected_traps_exact = 0;
  // WP-14b (D12): this test claims the trap arrived while a split access held
  // the pipeline. The window is read from the observations: the crossing
  // store's two beats and the trap's own cycle stamp.
  bit          trap_hold_check      = 0;
  // WP-14b (audit blocker 1): this test claims a commit and a trap of the SAME
  // core cycle. Without it a program whose co-cycle read drifted three
  // instructions away would pass while proving nothing, so the coincidence is
  // asserted instead of assumed.
  bit          trap_cocycle_check   = 0;
  int unsigned last_retire_cycle = 0; // cycle of the most recent commit
  int unsigned hold_b1_cycle = 0; // first cycle of the last split access's beat 1
  int unsigned hold_b1_wait  = 0; // cycles that beat stayed on the bus
  int unsigned hold_b2_cycle = 0; // first cycle of its beat 2
  // End of program: the commit at this address ends the run. Published by the
  // test from the program it built; `last_pc_set` keeps a default of 0 from
  // matching a commit at address 0.
  bit [31:0]   last_pc     = '0;
  bit          last_pc_set = 0;
  bit          done        = 0;
  // Every pc a commit was observed at, so `last_pc` may be published AFTER the
  // commit it names (the test learns the address when the sequence finishes,
  // and the pipeline retires it a few cycles later -- but the ordering is not
  // something to rely on twice).
  bit          seen_pc [bit [31:0]];

  // ---- Result Counters -----------------------------------------------------
  int unsigned pred_count        = 0;  // predictions received from the model (all kinds)
  int unsigned store_pred_count  = 0;  // store predictions
  int unsigned obs_count         = 0;  // store observations received from the monitor
  int unsigned pass_count        = 0;
  int unsigned fail_count        = 0;

  int unsigned retire_obs_count    = 0; // commit events observed
  int unsigned retire_claims       = 0; // commits carrying a CSR/trap claim
  int unsigned rd_wr_compare_count = 0; // destination-write-enable comparisons
  int unsigned rd_val_compare_count= 0; // destination-value comparisons
  int unsigned rd_unpredicted      = 0; // commits whose value the model cannot predict
  int unsigned must_trap_fail_count= 0; // commits that owed a trap and retired

  int unsigned trap_obs_count      = 0; // trap events observed
  int unsigned trap_compare_count  = 0; // trap causes compared with the derived cause
  int unsigned trap_spurious_count = 0; // legal instructions that took a trap
  int unsigned phase_errors        = 0; // non-vacuity guards that failed in check_phase

  // ---- Constructor ---------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build phase ---------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(bit)::get(this, "", "expect_predictions", expect_predictions))
      expect_predictions = 0;
    if (!uvm_config_db#(bit)::get(this, "", "expect_csr_claims", expect_csr_claims))
      expect_csr_claims = 0;
    if (!uvm_config_db#(int unsigned)::get(this, "", "expected_traps", expected_traps))
      expected_traps = 0;
    if (!uvm_config_db#(bit)::get(this, "", "expected_traps_exact", expected_traps_exact))
      expected_traps_exact = 0;
    if (!uvm_config_db#(bit)::get(this, "", "trap_hold_check", trap_hold_check))
      trap_hold_check = 0;
    if (!uvm_config_db#(bit)::get(this, "", "trap_cocycle_check", trap_cocycle_check))
      trap_cocycle_check = 0;
    mon_fifo         = new("mon_fifo", this);
    rm_fifo          = new("rm_fifo", this);
    retire_pred_fifo = new("retire_pred_fifo", this);
    trap_pred_fifo   = new("trap_pred_fifo", this);
    sb_export_mon    = new("sb_export_mon", this);
    sb_export_rm     = new("sb_export_rm", this);
  endfunction

  // ---- Connect phase -------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    sb_export_mon.connect(mon_fifo.analysis_export);
  endfunction

  // ---- Prediction arrival: count, then queue by kind -----------------------
  // One port carries the store, retire and trap predictions; the kind decides
  // the FIFO, so the store pairing stays exactly what it was before WP-14 (one
  // prediction per observed write, in order).
  function void write_pred(riscv_small_transaction t);
    pred_count++;
    if (t.op_is_pred_retire)
      retire_pred_fifo.write(t);
    else if (t.op_is_pred_trap)
      trap_pred_fifo.write(t);
    else begin
      store_pred_count++;
      rm_fifo.write(t);
    end
  endfunction

  // Prediction map: byte_addr → expected data (populated by Ref Model)
  int expected_stores[int];

  // ---- Run phase: observation dispatch -------------------------------------
  task run_phase(uvm_phase phase);
    riscv_small_transaction mon_trans; // DUT observation (Monitor)

    forever begin
      mon_fifo.get(mon_trans);

      // Fetch and data-read events are other components' claims (G-32, G-35).
      if (mon_trans.op_is_retire)       compare_retire(mon_trans);
      else if (mon_trans.op_is_trap)    compare_trap(mon_trans);
      else if (mon_trans.op_is_data_write) compare_store(mon_trans);
    end
  endtask : run_phase

  // ---- The store contract ---------------------------------------------------
  // The model publishes exactly one prediction per retired store, so the
  // pairing is 1:1 and positional. The strobes are part of the comparison
  // because a store's byte lane lives there: a halfword at offset 1 must
  // strobe 4'b0110, and a strobe of 4'b0011 writes bytes 0-1 instead
  // (G-34, T-51). riscv_small_strb_checker only proves strobe <-> width
  // coherence, and 4'b0011 IS a legal halfword pattern, so it cannot see
  // this; the prediction can.
  task automatic compare_store(riscv_small_transaction mon_trans);
    riscv_small_transaction exp_trans; // ISS prediction (Ref Model)

    obs_count++;
    // D12 window: keep the cycle stamps of the crossing access's two beats. A
    // trap taken before the second beat was presented cannot have been deferred
    // across the hold the first beat imposed.
    if (mon_trans.captured_data_beats == 2) begin
      if (mon_trans.captured_data_beat == 1) begin
        hold_b1_cycle = mon_trans.captured_data_cycle;
        hold_b1_wait  = mon_trans.captured_data_wait;
      end else begin
        hold_b2_cycle = mon_trans.captured_data_cycle;
      end
    end
    rm_fifo.get(exp_trans);

    if (mon_trans.captured_data_addr == exp_trans.captured_data_addr &&
        (mon_trans.captured_data_wr_strb & 4'hF) == (exp_trans.captured_data_wr_strb & 4'hF) &&
        mon_trans.captured_data_wr   == exp_trans.captured_data_wr) begin

      pass_count++;
      `uvm_info(get_full_name(),
        $sformatf("[PASS #%0d] STORE %0d correct: addr=0x%0h strb=4'b%04b data=0x%0h",
          pass_count, obs_count,
          mon_trans.captured_data_addr,
          mon_trans.captured_data_wr_strb,
          mon_trans.captured_data_wr),
        UVM_LOW)

    end else begin

      fail_count++;
      `uvm_error(get_full_name(),
        $sformatf("[FAIL #%0d] STORE %0d wrong:\n  DUT: addr=0x%0h strb=4'b%04b data=0x%0h\n  EXP: addr=0x%0h strb=4'b%04b data=0x%0h",
          fail_count, obs_count,
          mon_trans.captured_data_addr, mon_trans.captured_data_wr_strb,
          mon_trans.captured_data_wr,
          exp_trans.captured_data_addr, exp_trans.captured_data_wr_strb,
          exp_trans.captured_data_wr))

    end
  endtask

  // ---- The commit claim -----------------------------------------------------
  // One prediction per retire event, in order, so the pairing is positional.
  // The observed side carries rd0_wr_en (the probe's), the destination and the
  // value; the predicted side says whether they are a claim at all.
  task automatic compare_retire(riscv_small_transaction mon_trans);
    riscv_small_transaction exp;
    bit mismatched;

    retire_pred_fifo.get(exp);
    retire_obs_count++;
    seen_pc[mon_trans.retire_pc] = 1'b1;
    last_retire_cycle = mon_trans.obs_cycle;

    // End of program: the commit at the address the test named.
    if (last_pc_set && seen_pc.exists(last_pc))
      done = 1;

    if (!exp.pred_claim) return;
    retire_claims++;

    // An encoding that owes a trap must not retire (FR-24, FR-47, FR-50,
    // FR-25). This is the observation the whole red of WP-14 rests on: with no
    // trap path every illegal access retires as a no-operation.
    if (exp.pred_should_trap) begin
      must_trap_fail_count++;
      `uvm_error("CSR_TRAP_MISSING",
        $sformatf("[CSR_TRAP_MISSING #%0d] pc=0x%08h inst=0x%08h retired but owes cause %0d: an illegal encoding must not execute as a no-operation (FR-24), and an illegal CSR access must raise illegal-instruction (FR-47/FR-50)",
          must_trap_fail_count, mon_trans.retire_pc, mon_trans.retire_inst, exp.pred_cause))
      return;
    end

    // Did the instruction write its destination register at all? This is the
    // CSRRW/CSRRS claim of FR-47 (and `CSRRW rd=x0 writes nothing`, D4).
    rd_wr_compare_count++;
    mismatched = (mon_trans.retire_wr_en !== exp.pred_rd_wr);
    if (!mismatched && exp.pred_rd_wr && (mon_trans.retire_rd != exp.pred_rd))
      mismatched = 1;

    if (mismatched) begin
      fail_count++;
      `uvm_error("CSR_RD_WR",
        $sformatf("[CSR_RD_WR #%0d] pc=0x%08h inst=0x%08h: DUT write=%0d rd=x%0d, EXPECTED write=%0d rd=x%0d -- %s",
          fail_count, mon_trans.retire_pc, mon_trans.retire_inst,
          mon_trans.retire_wr_en, mon_trans.retire_rd, exp.pred_rd_wr, exp.pred_rd,
          exp.pred_rd_wr ? "the instruction must write its destination register (FR-47)"
                         : "the instruction must not write a register (rd = x0, D4)"))
      return;
    end

    // The value, where it is a prediction: a free-running counter (`cycle`) is
    // read and reported, never compared against a guess.
    if (!exp.pred_value_known) begin
      rd_unpredicted++;
      return;
    end
    rd_val_compare_count++;
    if (mon_trans.retire_wdata !== exp.pred_wdata) begin
      fail_count++;
      `uvm_error("CSR_RD_VALUE",
        $sformatf("[CSR_RD_VALUE #%0d] pc=0x%08h inst=0x%08h: DUT x%0d <- 0x%08h, EXPECTED 0x%08h -- %s",
          fail_count, mon_trans.retire_pc, mon_trans.retire_inst,
          mon_trans.retire_rd, mon_trans.retire_wdata, exp.pred_wdata,
          csr_value_clause(mon_trans.retire_inst)))
    end else begin
      `uvm_info(get_full_name(),
        $sformatf("[CSR PASS #%0d] pc=0x%08h inst=0x%08h: x%0d <- 0x%08h",
          rd_val_compare_count, mon_trans.retire_pc, mon_trans.retire_inst,
          mon_trans.retire_rd, mon_trans.retire_wdata),
        UVM_LOW)
    end
  endtask

  // ---- Requirement named by a value mismatch -------------------------------
  // A mismatch on a counter address is not "some CSR": it is the aliasing clause
  // of FR-50 (vol. II §2.1.1.10), and the log has to say so, because the same
  // comparison counter covers every address. Values, not transaction counts,
  // remain the claim; this only names which acceptance cell the value belongs to.
  function string csr_value_clause(bit [31:0] inst);
    case (inst[31:20])
      12'h341, 12'h342:
        return "FR-23: mepc/mcause must be the pair the trap produced -- and a read that RETIRES in the trap's own cycle is older than the trap, so it must still see the PRE-trap value (WP-14b ordering)";
      12'hB00, 12'hB80, 12'hC00, 12'hC80:
        return "FR-50 (vol. II sec. 2.1.1.10): `cycle`/`cycleh` are views of `mcycle`/`mcycleh`, so a write to the machine counter changes what they read";
      12'hB02, 12'hB82, 12'hC02, 12'hC82:
        return "FR-50 (vol. II sec. 2.1.1.10): `instret`/`instreth` are views of `minstret`/`minstreth`, so a write to the machine counter -- and every retirement -- changes what they read";
      default:
        return "FR-47/FR-50: the Zicsr read-modify-write value at this address";
    endcase
  endfunction

  // ---- The trap claim -------------------------------------------------------
  // The model derives the cause from `trap_inst`; this compares it with the
  // cause the core took, and rejects a trap on an instruction the model says is
  // legal (that is FR-52's "a write to mtval is accepted and ignored" and
  // FR-50's `rs1 = x0` clause).
  task automatic compare_trap(riscv_small_transaction mon_trans);
    riscv_small_transaction exp;

    trap_pred_fifo.get(exp);
    trap_obs_count++;

    if (!exp.pred_should_trap) begin
      trap_spurious_count++;
      `uvm_error("CSR_TRAP_SPURIOUS",
        $sformatf("[CSR_TRAP_SPURIOUS #%0d] pc=0x%08h inst=0x%08h took cause %0d, but the instruction is legal and must not trap (FR-52/FR-50)",
          trap_spurious_count, mon_trans.trap_pc, mon_trans.trap_inst, mon_trans.trap_cause))
      return;
    end

    trap_compare_count++;
    if (mon_trans.trap_cause != exp.pred_cause) begin
      fail_count++;
      `uvm_error("CSR_TRAP_CAUSE",
        $sformatf("[CSR_TRAP_CAUSE #%0d] pc=0x%08h inst=0x%08h: DUT cause %0d, EXPECTED %0d (derived from the instruction: 2 illegal, 3 EBREAK, 11 ECALL; or from the platform's request on exception[3:0] when the instruction is legal)",
          fail_count, mon_trans.trap_pc, mon_trans.trap_inst, mon_trans.trap_cause, exp.pred_cause))
    end else begin
      `uvm_info(get_full_name(),
        $sformatf("[CSR PASS #%0d] TRAP pc=0x%08h inst=0x%08h cause=%0d (mepc must read 0x%08h)",
          trap_compare_count, mon_trans.trap_pc, mon_trans.trap_inst, mon_trans.trap_cause,
          mon_trans.trap_pc),
        UVM_LOW)
    end

    // D12 (WP-14b): the guarantee is that a trap is NOT taken while a split
    // access holds the pipeline. The observation that proves it is a cycle
    // comparison: the trap must not belong to a cycle earlier than the one that
    // presented the crossing access's second beat, and beat 1 must really have
    // been held (a beat granted on its first cycle never froze anything).
    if (trap_hold_check) begin
      if (hold_b2_cycle == 0) begin
        fail_count++;
        `uvm_error("TRAP_HOLD",
          $sformatf("[TRAP_HOLD #%0d] pc=0x%08h: the test claims a trap during a crossing access, and no split write beat had been published before it (0 beat(s)) -- the stimulus never reached the port, or the access was not split",
            fail_count, mon_trans.trap_pc))
      end else if (mon_trans.obs_cycle < hold_b2_cycle) begin
        fail_count++;
        `uvm_error("TRAP_HOLD",
          $sformatf("[TRAP_HOLD #%0d] pc=0x%08h: the trap was taken in cycle %0d, before the crossing access's second beat was presented (beat 1 cycle %0d, held %0d cycle(s); beat 2 cycle %0d) -- the request was not deferred while the pipeline was frozen (FR-22/D12)",
            fail_count, mon_trans.trap_pc, mon_trans.obs_cycle, hold_b1_cycle,
            hold_b1_wait, hold_b2_cycle))
      end else begin
        `uvm_info(get_full_name(),
          $sformatf("[D12 PASS] trap at pc=0x%08h taken in cycle %0d, after the crossing access's beat 2 (cycle %0d; beat 1 held %0d cycle(s))",
            mon_trans.trap_pc, mon_trans.obs_cycle, hold_b2_cycle, hold_b1_wait),
          UVM_LOW)
      end
    end

    // Non-vacuity for the ordering claim (WP-14b, audit blocker 1): the commit
    // that shares this trap's cycle must really have been observed in that same
    // cycle, and published before it. A program whose co-cycle read drifted
    // would otherwise pass while proving nothing.
    if (trap_cocycle_check) begin
      if (last_retire_cycle != mon_trans.obs_cycle) begin
        fail_count++;
        `uvm_error("TRAP_COCYCLE",
          $sformatf("[TRAP_COCYCLE #%0d] pc=0x%08h: the trap belongs to cycle %0d and the last commit observed belongs to cycle %0d -- no instruction retired in the trap's own cycle, so the ordering this test claims was never exercised",
            fail_count, mon_trans.trap_pc, mon_trans.obs_cycle, last_retire_cycle))
      end else begin
        `uvm_info(get_full_name(),
          $sformatf("[COCYCLE PASS] trap at pc=0x%08h and the commit before it share cycle %0d",
            mon_trans.trap_pc, mon_trans.obs_cycle),
          UVM_LOW)
      end
    end
  endtask

  // ---- End of program: the checker's `done` --------------------------------
  // Public so the test can wait on it: the commit at `last_pc` ends the run.
  // It is a function and not only the `done` bit because the test publishes
  // `last_pc` after the sequence finishes, which can be after the commit itself
  // has been consumed.
  function bit is_done();
    if (!done && last_pc_set && seen_pc.exists(last_pc))
      done = 1;
    return done;
  endfunction

  // ---- Check phase: non-vacuity --------------------------------------------
  // A test that claims a prediction must have received one. Without these
  // guards "the model runs" and "the model received nothing" are the same green
  // run.
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (expect_predictions && store_pred_count == 0) begin
      phase_errors++;
      `uvm_error("RM_NO_PREDICTION",
        $sformatf("the reference model produced 0 store predictions on a run that expects them (%0d store observation(s) reached the scoreboard, 0 comparison(s) made)",
          obs_count))
    end
    if (expect_csr_claims && rd_wr_compare_count == 0) begin
      phase_errors++;
      `uvm_error("CSR_NO_COMPARISON",
        $sformatf("the run claimed the CSR/trap behaviour but made 0 CSR comparison(s): %0d commit(s) observed, %0d claim(s), %0d trap(s)",
          retire_obs_count, retire_claims, trap_obs_count))
    end
    if (expected_traps > 0 && expected_traps_exact && trap_obs_count != expected_traps) begin
      phase_errors++;
      `uvm_error("TRAP_COUNT",
        $sformatf("%0d trap(s) were observed where the program takes exactly %0d: a trap repeated for one request (D12b) or one was lost (%0d commit(s) observed)",
          trap_obs_count, expected_traps, retire_obs_count))
    end else if (expected_traps > 0 && trap_obs_count < expected_traps) begin
      phase_errors++;
      `uvm_error("TRAP_NOT_OBSERVED",
        $sformatf("%0d of %0d trap(s) the program takes were observed: the trap path did not produce the event the program depends on (%0d commit(s) observed)",
          trap_obs_count, expected_traps, retire_obs_count))
    end
  endfunction

  // ---- Report phase: final summary -----------------------------------------
  // The counts are printed unconditionally: a green run with 0 predictions and
  // 0 comparisons is a vacuous run, and the log has to show it.
  function void report_phase(uvm_phase phase);
    int unsigned total_fail;
    total_fail = fail_count + must_trap_fail_count + trap_spurious_count + phase_errors;
    `uvm_info(get_full_name(),
      $sformatf("\n========================================\n  SCOREBOARD FINAL REPORT\n  store predictions : %0d (%0d observed, %0d PASS)\n  commit observations: %0d (%0d with a CSR/trap claim)\n  CSR rd write/enable comparisons: %0d\n  CSR rd value comparisons       : %0d\n  claims with no value to compare: %0d (rd = x0, or a CSR whose value the model cannot predict)\n  commit(s) that owed a trap     : %0d\n  trap observations              : %0d (%0d cause(s) compared, %0d spurious)\n  non-vacuity guard(s) failed    : %0d\n  store/CSR-value failures       : %0d\n  expect_predictions : %0d\n  expect_csr_claims  : %0d\n  expected_traps     : %0d\n  done               : %0d\n  TOTAL FAIL         : %0d\n========================================",
        store_pred_count, obs_count, pass_count,
        retire_obs_count, retire_claims,
        rd_wr_compare_count, rd_val_compare_count, rd_unpredicted,
        must_trap_fail_count,
        trap_obs_count, trap_compare_count, trap_spurious_count,
        phase_errors,
        fail_count,
        expect_predictions, expect_csr_claims, expected_traps, done, total_fail),
      UVM_NONE)
    if (total_fail > 0)
      `uvm_error(get_full_name(), "SIMULATION ENDED WITH FAILS!")
    else if (store_pred_count == 0 && rd_wr_compare_count == 0 && trap_obs_count == 0)
      `uvm_info(get_full_name(), "NO COMPARISON WAS MADE: this green run proves nothing", UVM_NONE)
    else
      `uvm_info(get_full_name(), "SIMULATION PASSED ALL CHECKS!", UVM_NONE)
  endfunction

endclass : riscv_small_scoreboard

`endif
