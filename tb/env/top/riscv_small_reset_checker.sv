`ifndef RISCV_SMALL_RESET_CHECKER
`define RISCV_SMALL_RESET_CHECKER

// ============================================================================
// riscv_small_reset_checker
//
// FR-41 (reset-vector clause) / G-33 verdict: the FIRST fetch the MONITOR
// publishes after reset must present the address `RESET_VECTOR` names.
//
// Why the monitor and not the pins: the monitor already owns the fetch rule
// (wp-8 §3.1.3) -- it clears its outstanding-request queue while `rst_n` is low
// and never publishes a reset-time pair, so the first `op_is_inst` event it
// publishes in a run IS the first fetch after reset. This checker adds no reset
// logic of its own and never samples the driver, the sequence or the pins.
//
// The expectation is CONFIGURATION, the same shape as the program image:
//   `reset_vector`        bit [31:0], published once by the testbench top from
//                         the value the DUT elaborated with (`duv.RESET_VECTOR`),
//                         so no test and no checker holds a second copy of the
//                         spec's default `0x8000_0000`;
//   `check_reset_vector`  bit, set by the ONE test that makes this claim.
// Without the enable the checker is inert: it counts, reports `NONE compared`
// and raises nothing, so the other tests of the regression are untouched.
//
// The verdict is one UVM_ERROR naming the observed pc and the expected
// RESET_VECTOR when they differ. A run that observes no fetch at all is NOT
// passed here: the test owns the clock-based timeout and raises it, because a
// claim that was never measured is a test defect, not a DUT defect.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
// ============================================================================
class riscv_small_reset_checker extends uvm_subscriber #(riscv_small_transaction);
  `uvm_component_utils(riscv_small_reset_checker)

  // ---- Configuration -------------------------------------------------------
  bit        enabled;        // this test asked for the comparison
  bit        have_expected;  // a `reset_vector` value was published
  bit [31:0] expected;       // RESET_VECTOR as configured (never a literal here)

  // ---- Observation ---------------------------------------------------------
  bit [31:0]   first_pc;      // pc of the first fetch after reset
  bit          have_first;    // that fetch was observed
  bit          done;          // the claim was decided (green or red)
  int unsigned fetch_count;   // fetch events published by the monitor
  int unsigned orphan_count;  // responses with no request outstanding (skipped)
  int unsigned mismatch_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    have_expected = uvm_config_db#(bit [31:0])::get(this, "", "reset_vector", expected);
    if (!uvm_config_db#(bit)::get(this, "", "check_reset_vector", enabled))
      enabled = 0;

    // A test that enables the claim without publishing the value is a
    // testbench defect: fail loudly instead of comparing against a literal.
    if (enabled && !have_expected) begin
      `uvm_fatal("RESET_VECTOR",
        "check_reset_vector=1 but no reset_vector was published; the expected value has no source")
      enabled = 0;
    end
  endfunction

  // Observation only: the monitor publishes, this function records and judges.
  // Analysis writes are nonblocking, so there is no FIFO and no get().
  function void write(riscv_small_transaction t);
    if (!t.op_is_inst) return;

    // An orphan response is not a fetch pair (its address pin is not the pair
    // of the word it carries); riscv_small_fetch_pair_checker judges it.
    if (t.captured_inst_orphan) begin
      orphan_count++;
      return;
    end

    fetch_count++;
    if (!enabled || have_first) return;

    first_pc   = t.captured_inst_addr;
    have_first = 1;
    done       = 1;

    if (first_pc !== expected) begin
      mismatch_count++;
      `uvm_error("RESET_VECTOR",
        $sformatf("[RESET_VECTOR #%0d] first fetch after reset presented pc=0x%08h; RESET_VECTOR expects 0x%08h",
          mismatch_count, first_pc, expected))
    end else begin
      `uvm_info("RESET_VECTOR",
        $sformatf("first fetch after reset at pc=0x%08h == RESET_VECTOR 0x%08h",
          first_pc, expected),
        UVM_LOW)
    end
  endfunction: write

  function void report_phase(uvm_phase phase);
    if (!enabled) begin
      `uvm_info(get_full_name(),
        $sformatf("FR-41 RESET_VECTOR: %0d fetch(es) observed, %0d orphan response(s), NONE compared (no reset-vector expectation configured)",
          fetch_count, orphan_count),
        UVM_LOW)
      return;
    end

    if (!have_first)
      `uvm_info(get_full_name(),
        $sformatf("FR-41 RESET_VECTOR: NOT OBSERVED -- no fetch was published (expected first fetch at 0x%08h)",
          expected),
        UVM_LOW)
    else
      `uvm_info(get_full_name(),
        $sformatf("FR-41 RESET_VECTOR: first fetch after reset pc=0x%08h, expected 0x%08h, %0d fetch(es) observed, %0d orphan response(s), %0d mismatch(es)",
          first_pc, expected, fetch_count, orphan_count, mismatch_count),
        UVM_LOW)
  endfunction: report_phase

endclass: riscv_small_reset_checker

`endif
