//------------------------------------------------------------------------------
// CSR and trap test for riscv_small (WP-14: FR-22..FR-25, FR-29, FR-32, FR-37,
// FR-47, FR-49..FR-52)
//------------------------------------------------------------------------------
// One claim: the machine-mode CSR file answers at the addresses of FR-50, the
// six Zicsr instructions implement the read-modify-write semantics of FR-47,
// `cycle`/`cycleh` and `instret`/`instreth` are VIEWS of the machine counters
// rather than separate registers (FR-50; vol. II §2.1.1.10), and the trap entry
// of FR-22/FR-23/FR-25/FR-29 produces the cause, the mepc and the vector the
// program depends on.
//
// Two clauses this program pins deliberately, because an oracle that gets them
// wrong makes a green run prove nothing:
//   - writing `mcycle`/`mcycleh`/`minstret`/`minstreth` changes what
//     `cycle`/`cycleh`/`instret`/`instreth` read. The high halves are written
//     with a distinctive value; the low halves are written 0xFFFF_FFFF, whose
//     carry is exactly one into the high half -- a value the model predicts
//     without counting a clock, and a separate counter cannot produce;
//   - the Zicsr write suppression is the REGISTER SPECIFIER `rs1 = x0`, not the
//     value: `csrrs` from a non-x0 register holding zero still writes, so it
//     still traps on a read-only address.
//
// Who decides: riscv_small_ref_model predicts (it derives the expected cause
// from the trapping instruction and keeps its own CSR file) and
// riscv_small_scoreboard compares against what the MONITOR observed on the
// retire and trap streams. This test owns the objection and the clock-bounded
// drain, and configures the DUT's two straps -- nothing else.
//
// D13: `mtime` and `hart_id` are driven NON-ZERO (`TIME_VALUE`, `HART_ID`), so
// a DUT that reads a constant zero for `time`/`timeh`/`mhartid` fails. They are
// stimulus of the DUT: the value is born here, the driver drives it, and the
// MONITOR observes the same wire and hands it to the model. The model never
// reads these keys -- a config_db value would be a second source of truth
// (C-16).
//
// No program image is configured, on purpose. riscv_small_retire_checker
// compares the commit stream against the program as a fixed sequence, and a
// trap legitimately removes an instruction from that sequence; making it
// trap-aware is not this WP's claim. Without an image it is inert (it reports
// "NONE compared"), so the only verdict here is the CSR/trap one.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_CSR_TEST
`define RISCV_SMALL_CSR_TEST

class riscv_small_csr_test extends riscv_small_base_test;

  `uvm_component_utils(riscv_small_csr_test)

  // D13: both NON-ZERO. `mtime` is 0x0000_0001_2345_6789, so `time` must read
  // 0x23456789 and `timeh` 0x00000001 -- a DUT returning the wrong half, or
  // zero, fails. It is held constant for the run: the value is read in EX and
  // observed with the retire event, so a moving timer would make the
  // observation later than the read (see riscv_small_ref_model).
  localparam bit [63:0] TIME_VALUE = 64'h0000_0001_2345_6789;
  localparam bit [3:0]  HART_ID    = 4'b0101; // 5: not 0, not all ones

  // The program takes seven traps (ECALL, EBREAK, an unallocated encoding, an
  // absent CSR address, two writes to read-only addresses, and a `csrrs` whose
  // source is a non-x0 register holding zero). The checker raises when fewer
  // are observed: a run that claimed traps and saw none has proven nothing.
  localparam int unsigned EXPECTED_TRAPS = 7;

  // The last fetch is answered ~4-5 cycles before the last commit, so this is a
  // drain bound, not a stimulus length.
  localparam int unsigned DRAIN_CYCLES = 500;

  riscv_small_csr_seq seq;

  function new(string name = "riscv_small_csr_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  // All configuration is published BEFORE super.build_phase(): the environment
  // and its children read it in their own build_phase.
  virtual function void build_phase(uvm_phase phase);
    // The non-vacuity guard of the CSR claim: a run that compares no CSR value
    // is an error, not a pass.
    uvm_config_db#(bit)::set(this, "*", "expect_csr_claims", 1);
    uvm_config_db#(int unsigned)::set(this, "*", "expected_traps", EXPECTED_TRAPS);
    // D13: the platform's stimulus. The driver drives these onto the interface;
    // the monitor observes them and the model predicts from the observation.
    uvm_config_db#(bit [63:0])::set(this, "*", "mtime", TIME_VALUE);
    uvm_config_db#(bit [3:0])::set(this, "*", "hart_id", HART_ID);
    super.build_phase(phase);
    seq = riscv_small_csr_seq::type_id::create("seq");
  endfunction : build_phase

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("TEST_RUN",
      $sformatf("Starting the CSR/trap run (FR-47/FR-50/FR-22..FR-25): mtime=0x%016h hart_id=%0d, %0d traps expected",
        TIME_VALUE, HART_ID, EXPECTED_TRAPS),
      UVM_LOW)

    seq.start(env.riscv_small_agnt.sequencer);

    // The program's last address is known once the sequence has built it. The
    // scoreboard's `done` is the commit at that address -- the end of the run is
    // the checker's signal, and this is where it learns which address to watch.
    env.sb.last_pc     = seq.last_pc;
    env.sb.last_pc_set = 1;
    wait_csr_drain(DRAIN_CYCLES);

    phase.drop_objection(this);
  endtask : run_phase

  // The timeout is the test's; `done` is the scoreboard's. Bounded by clock
  // edges so a DUT that never reaches the end of the program fails with a named
  // error instead of hanging the simulation.
  task automatic wait_csr_drain(int unsigned max_cycles);
    int unsigned waited;

    waited = 0;
    while (!env.sb.is_done() && waited < max_cycles) begin
      @(posedge env.riscv_small_agnt.monitor.vif.clk);
      waited++;
    end

    if (!env.sb.is_done())
      `uvm_error("CSR_DRAIN_TIMEOUT",
        $sformatf("the program did not reach its last instruction (0x%08h) within %0d clock cycle(s): %0d commit(s), %0d trap(s), %0d CSR comparison(s) observed",
          seq.last_pc, max_cycles, env.sb.retire_obs_count, env.sb.trap_obs_count,
          env.sb.rd_wr_compare_count))
    else
      `uvm_info("CSR_DRAIN_DONE",
        $sformatf("program drained after %0d extra clock cycle(s): %0d commit(s), %0d trap(s), %0d CSR write comparison(s), %0d CSR value comparison(s)",
          waited, env.sb.retire_obs_count, env.sb.trap_obs_count,
          env.sb.rd_wr_compare_count, env.sb.rd_val_compare_count),
        UVM_LOW)
  endtask : wait_csr_drain

endclass : riscv_small_csr_test

`endif
