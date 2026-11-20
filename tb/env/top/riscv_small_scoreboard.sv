`ifndef RISCV_SMALL_SCOREBOARD
`define RISCV_SMALL_SCOREBOARD

// ============================================================================
// riscv_small_scoreboard
//
// UVM Scoreboard: compares transactions predicted by the Reference Model (ISS)
// with the actual transactions observed by the Monitor on the DUT.
//
//   rm_fifo   → STORE prediction transactions (from Ref Model)
//   mon_fifo  → STORE observation transactions (from Monitor/DUT)
//
// For each STORE observed by the Monitor, the Scoreboard retrieves the next 
// prediction from the RM queue and compares the store contract: the byte
// address, the byte strobes and the lane-placed data word.
//
// The FR-11 store strobe <-> width invariant is NOT here: it lives in
// riscv_small_strb_checker, which is built with or without a reference model.
//
// Non-vacuity (WP-8, decision 6). A model that receives nothing predicts
// nothing, and a comparison that never happens cannot fail: the run would be
// green with zero evidence. `expect_predictions` (config, default 0) turns
// "the model produced no prediction at all" into UVM_ERROR [RM_NO_PREDICTION]
// in check_phase, and report_phase always prints the prediction and comparison
// counts so a vacuous run is visible even where the guard is off (T-09 has no
// stimulus and must not raise it).
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
  uvm_tlm_analysis_fifo #(riscv_small_transaction) rm_fifo;

  // ---- Configuration -------------------------------------------------------
  bit expect_predictions = 0; // this test claims the model predicts something

  // ---- Result Counters -----------------------------------------------------
  int unsigned pred_count = 0;  // predictions received from the model
  int unsigned obs_count  = 0;  // store observations received from the monitor
  int unsigned pass_count = 0;
  int unsigned fail_count = 0;

  // ---- Constructor ---------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build phase ---------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(bit)::get(this, "", "expect_predictions", expect_predictions))
      expect_predictions = 0;
    mon_fifo    = new("mon_fifo", this);
    rm_fifo     = new("rm_fifo",  this);
    sb_export_mon = new("sb_export_mon", this);
    sb_export_rm  = new("sb_export_rm",  this);
  endfunction

  // ---- Connect phase -------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    sb_export_mon.connect(mon_fifo.analysis_export);
  endfunction

  // ---- Prediction arrival: count, then queue for the comparison ------------
  function void write_pred(riscv_small_transaction t);
    pred_count++;
    rm_fifo.write(t);
  endfunction

  // Prediction map: byte_addr → expected data (populated by Ref Model)
  int expected_stores[int];

  // ---- Run phase: comparison -----------------------------------------------
  task run_phase(uvm_phase phase);
    riscv_small_transaction mon_trans; // DUT observation (Monitor)
    riscv_small_transaction exp_trans; // ISS prediction (Ref Model)
    int mon_count = 0;

    forever begin
      // 1. Wait for next data write observation on the DUT
      mon_fifo.get(mon_trans);
      if (!mon_trans.op_is_data_write) continue;
      mon_count++;
      obs_count++;

      // 2. Obtain the next prediction from the Ref Model (blocks until arrival)
      rm_fifo.get(exp_trans);

      // ---- Compare the store contract: address, strobes, lane-placed data ---
      // The model publishes exactly one prediction per retired store, so the
      // pairing is 1:1 and positional. The strobes are part of the comparison
      // because a store's byte lane lives there: a halfword at offset 1 must
      // strobe 4'b0110, and a strobe of 4'b0011 writes bytes 0-1 instead
      // (G-34, T-51). riscv_small_strb_checker only proves strobe <-> width
      // coherence, and 4'b0011 IS a legal halfword pattern, so it cannot see
      // this; the prediction can.
      if (mon_trans.captured_data_addr == exp_trans.captured_data_addr &&
          (mon_trans.captured_data_wr_strb & 4'hF) == (exp_trans.captured_data_wr_strb & 4'hF) &&
          mon_trans.captured_data_wr   == exp_trans.captured_data_wr) begin

        pass_count++;
        `uvm_info(get_full_name(),
          $sformatf("[PASS #%0d] STORE %0d correct: addr=0x%0h strb=4'b%04b data=0x%0h",
            pass_count, mon_count,
            mon_trans.captured_data_addr,
            mon_trans.captured_data_wr_strb,
            mon_trans.captured_data_wr),
          UVM_LOW)

      end else begin

        fail_count++;
        `uvm_error(get_full_name(),
          $sformatf("[FAIL #%0d] STORE %0d wrong:\n  DUT: addr=0x%0h strb=4'b%04b data=0x%0h\n  EXP: addr=0x%0h strb=4'b%04b data=0x%0h",
            fail_count, mon_count,
            mon_trans.captured_data_addr, mon_trans.captured_data_wr_strb,
            mon_trans.captured_data_wr,
            exp_trans.captured_data_addr, exp_trans.captured_data_wr_strb,
            exp_trans.captured_data_wr))

      end
    end
  endtask : run_phase

  // ---- Check phase: non-vacuity --------------------------------------------
  // A test that claims a prediction must have received one. Without this guard
  // "the model runs" and "the model received nothing" are the same green run.
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (expect_predictions && pred_count == 0)
      `uvm_error("RM_NO_PREDICTION",
        $sformatf("the reference model produced 0 predictions on a run that expects them (%0d store observation(s) reached the scoreboard, 0 comparison(s) made)",
          obs_count))
  endfunction

  // ---- Report phase: final summary -----------------------------------------
  // The counts are printed unconditionally: a green run with 0 predictions and
  // 0 comparisons is a vacuous run, and the log has to show it.
  function void report_phase(uvm_phase phase);
    `uvm_info(get_full_name(),
      $sformatf("\n========================================\n  SCOREBOARD FINAL REPORT\n  predictions : %0d\n  comparisons : %0d (%0d observed store(s))\n  PASS : %0d\n  FAIL : %0d\n  expect_predictions : %0d\n========================================",
        pred_count, pass_count + fail_count, obs_count, pass_count, fail_count, expect_predictions),
      UVM_NONE)
    if (fail_count > 0)
      `uvm_error(get_full_name(), "SIMULATION ENDED WITH FAILS!")
    else if (pred_count == 0)
      `uvm_info(get_full_name(), "NO COMPARISON WAS MADE: this green run proves nothing", UVM_NONE)
    else
      `uvm_info(get_full_name(), "SIMULATION PASSED ALL CHECKS!", UVM_NONE)
  endfunction

endclass : riscv_small_scoreboard

`endif
