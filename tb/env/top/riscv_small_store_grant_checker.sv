`ifndef RISCV_SMALL_STORE_GRANT_CHECKER
`define RISCV_SMALL_STORE_GRANT_CHECKER

// ============================================================================
// riscv_small_store_grant_checker
//
// FR-38 / G-18 checker: a store completes only in a cycle in which the data
// memory grants it. The monitor publishes one data transaction per BEAT
// (WP-13 P6b; a non-split access is one beat) together with
// `captured_data_grant`, so the claim is a property of ONE observation, like
// the strobe check:
//
//   op_is_data_write && !captured_data_grant
//     -> the core presented the store and the memory never asserted
//        `data_ready` in any cycle of it: the core walked away from the store
//        before the grant, so it completed it in a cycle the memory did not
//        grant. That is the defect: rtl/control.sv:288 gates the data_ready
//        stall on the load destination, so a store ignores the wait (G-18) and
//        a memory that withheld the grant never receives it.
//
// The grant is the HANDSHAKE (the request presented in a cycle in which
// data_ready is high), which is the observable form of FR-38's "completes only
// in a cycle in which the data memory grants it" for a level-based port. The
// claim is scoped to writes on purpose: this core consumes a load's grant one
// stage later (rtl/control.sv:288 reads the WB slot's mux select), so a load's
// request is off the bus in the grant cycle and the monitor publishes it with
// grant=0 -- a fact about the port, not a store accepted early.
//
// The message names the cycle, because "mismatch" is not a diagnosis: the first
// cycle the access was presented and how many cycles it stayed on the bus are in
// it, together with the address, the strobes and the data.
//
// The checker is INERT unless the test that owns the run enables it
// (`store_grant_check` via config_db). It has to be: with a memory that grants
// every access on the first opportunity, every store this core issues today is
// published without a grant -- that IS G-18, observed in the 47 tests that
// predate this one, and none of them claims FR-38. A test that enables the claim
// and exercises nothing is an error ([STORE_GRANT_VACUOUS]) instead of a green
// run, because a checker that cannot fail is not evidence (WP-8, decision 6).
//
// It subscribes to the monitor (never to the driver, never to the sequence) and
// it is built in BOTH agent modes: no FIFO, no get(), so it cannot stall a run.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
// ============================================================================
class riscv_small_store_grant_checker extends uvm_subscriber #(riscv_small_transaction);
  `uvm_component_utils(riscv_small_store_grant_checker)

  // ---- Configuration -------------------------------------------------------
  bit enabled = 0; // this run claims FR-38 (the memory withholds the grant)

  // ---- Counters ------------------------------------------------------------
  int unsigned write_count     = 0; // writes published by the monitor
  int unsigned waited_count    = 0; // writes that stayed on the bus > 1 cycle
  int unsigned granted_count   = 0; // writes the memory granted
  int unsigned violation_count = 0; // writes accepted before the grant

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(bit)::get(this, "", "store_grant_check", enabled))
      enabled = 0;
  endfunction

  function void write(riscv_small_transaction t);
    // Reads have no grant contract this checker claims, and the other streams
    // (fetch, retire) are not data accesses at all.
    if (!t.op_is_data_write) return;

    write_count++;
    if (t.captured_data_wait > 1) waited_count++;

    if (t.captured_data_grant) begin
      granted_count++;
      return;
    end

    // Inert unless the claim is on: the 47 tests before T-53 run against this
    // core as it is, where every store is published without a grant (G-18),
    // and none of them claims FR-38.
    if (!enabled) return;

    violation_count++;
    `uvm_error("STORE_GRANT",
      $sformatf("[STORE_GRANT #%0d] write accepted at cycle %0d while data_ready was low: addr=0x%0h strb=4'b%04b data=0x%0h was presented from cycle %0d for %0d cycle(s) and withdrawn without a grant (FR-38, G-18)",
        violation_count,
        t.captured_data_cycle + t.captured_data_wait, // the cycle it left the bus
        t.captured_data_addr,
        t.captured_data_wr_strb,
        t.captured_data_wr,
        t.captured_data_cycle,
        t.captured_data_wait))
  endfunction: write

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (!enabled) return;

    // Non-vacuity: the claim is "a store that waits is not accepted before the
    // grant", so a run in which no store was ever held for the grant (or no
    // store was published at all) proves neither half.
    if (write_count == 0)
      `uvm_error("STORE_GRANT_VACUOUS",
        "the run claims FR-38 but the monitor published no write: nothing was compared")
    else if (violation_count == 0 && waited_count == 0)
      `uvm_error("STORE_GRANT_VACUOUS",
        $sformatf("%0d write(s) published and none of them was held for the grant: the memory granted every access on the first opportunity, so the wait this run claims was never exercised",
          write_count))
  endfunction: check_phase

  function void report_phase(uvm_phase phase);
    // Silent unless the claim is on, so a run that does not ask for it keeps its
    // exact log.
    if (!enabled) return;
    `uvm_info(get_full_name(),
      $sformatf("FR-38 store grant: %0d write(s) published, %0d waited more than one cycle, %0d with a grant cycle, %0d accepted before the grant",
        write_count, waited_count, granted_count, violation_count),
      UVM_LOW)
  endfunction: report_phase

endclass: riscv_small_store_grant_checker

`endif
