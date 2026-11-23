//------------------------------------------------------------------------------
// Trap / retire ordering test for riscv_small (WP-14b: FR-22, FR-23, FR-25)
//------------------------------------------------------------------------------
// One claim: in the cycle a trap is taken, the instruction that RETIRES is
// OLDER than the trapping instruction, so the consumer of the two observations
// must apply the commit first. The program of
// riscv_small_trap_order_seq places a CSR read of `mepc` (and, for a second
// trap, of `mcause`) exactly three instructions before the trap site, so it
// occupies the WRITE-BACK slot in the same cycle the trap is decided in ID.
//
// The value read there is the PRE-trap one: 0xAAAA_A7F0 for `mepc` and 0x1234
// for `mcause`, both written by the program and both values no trap cause can
// produce. A consumer that applies the trap first reads the post-trap state --
// the ecall's own address and cause 11 -- and the scoreboard's value comparison
// names which instruction disagreed.
//
// The verdict belongs to riscv_small_ref_model (which predicts, fed ONLY by the
// monitor's retire and trap streams) and riscv_small_scoreboard (which compares
// against what the monitor observed). This test owns the objection and the
// clock-bounded drain, and configures nothing but the two non-vacuity guards.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_TRAP_ORDER_TEST
`define RISCV_SMALL_TRAP_ORDER_TEST

class riscv_small_trap_order_test extends riscv_small_base_test;

  `uvm_component_utils(riscv_small_trap_order_test)

  // The program takes two traps: the ecall and the ebreak.
  localparam int unsigned EXPECTED_TRAPS = 2;

  // The last fetch is answered a few cycles before the last commit, so this is
  // a drain bound, not a stimulus length.
  localparam int unsigned DRAIN_CYCLES = 500;

  riscv_small_trap_order_seq seq;

  function new(string name = "riscv_small_trap_order_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    // Non-vacuity: a run that compares no CSR value, or observes no trap, is an
    // error -- not a pass. `expected_traps_exact` makes "twice for one request"
    // fail as loudly as "never".
    uvm_config_db#(bit)::set(this, "*", "expect_csr_claims", 1);
    uvm_config_db#(int unsigned)::set(this, "*", "expected_traps", EXPECTED_TRAPS);
    uvm_config_db#(bit)::set(this, "*", "expected_traps_exact", 1);
    // The claim is only exercised if a commit shares the trap's cycle.
    uvm_config_db#(bit)::set(this, "*", "trap_cocycle_check", 1);
    super.build_phase(phase);
    seq = riscv_small_trap_order_seq::type_id::create("seq");
  endfunction : build_phase

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("TEST_RUN",
      $sformatf("Starting the trap/retire ordering run (FR-22/FR-23): %0d traps, each with a CSR read of the trap state in the write-back slot of its cycle",
        EXPECTED_TRAPS),
      UVM_LOW)

    seq.start(env.riscv_small_agnt.sequencer);

    env.sb.last_pc     = seq.last_pc;
    env.sb.last_pc_set = 1;
    wait_trap_drain(DRAIN_CYCLES);

    phase.drop_objection(this);
  endtask : run_phase

  // The timeout is the test's; `done` is the scoreboard's. Bounded by clock
  // edges so a DUT that never reaches the end of the program fails with a named
  // error instead of hanging the simulation.
  task automatic wait_trap_drain(int unsigned max_cycles);
    int unsigned waited;

    waited = 0;
    while (!env.sb.is_done() && waited < max_cycles) begin
      @(posedge env.riscv_small_agnt.monitor.vif.clk);
      waited++;
    end

    if (!env.sb.is_done())
      `uvm_error("TRAP_ORDER_TIMEOUT",
        $sformatf("the program did not reach its last instruction (0x%08h) within %0d clock cycle(s): %0d commit(s), %0d trap(s), %0d CSR value comparison(s) observed",
          seq.last_pc, max_cycles, env.sb.retire_obs_count, env.sb.trap_obs_count,
          env.sb.rd_val_compare_count))
    else
      `uvm_info("TRAP_ORDER_DONE",
        $sformatf("program drained after %0d extra clock cycle(s): %0d commit(s), %0d trap(s), %0d CSR value comparison(s)",
          waited, env.sb.retire_obs_count, env.sb.trap_obs_count,
          env.sb.rd_val_compare_count),
        UVM_LOW)
  endtask : wait_trap_drain

endclass : riscv_small_trap_order_test

`endif
