//------------------------------------------------------------------------------
// External trap request test for riscv_small (WP-14b: FR-22, Q-35, G-37)
//------------------------------------------------------------------------------
// One claim: a synchronous trap request presented by the platform on
// `exception[3:0]` is taken, the reason reported in `mcause` is the CODE THAT
// WAS PRESENTED (5, a code this core cannot produce from an instruction), the
// address reported in `mepc` is the instruction that was in ID, and the
// instruction's own CSR write never happens.
//
// The pin is the stimulus and it has an owner: the sequence schedules it against
// a program address (the item's exception_addr/exception_cause), the DRIVER
// asserts it for exactly one core cycle, and the DUT receives it through the
// interface member -- the same wire the MONITOR observes and publishes with the
// trap event. The model therefore predicts the external cause from the
// observation and never from a config_db key (D13, C-16).
//
// What the run proves, by value:
//   - a trap was observed at all (non-vacuity guard, exactly one);
//   - `mcause` reads 5, the presented code, and not 0 and not an internal cause;
//   - `mepc` reads the aimed instruction's address;
//   - the aimed instruction's CSR write did not happen: a post-trap read of
//     `mscratch` returns the pre-trap marker, so the trap really did discard it
//     before EX.
//
// The chips this test does NOT claim: the interrupt inputs, the priority between
// two requests, and a request held across several cycles (the pin is a level and
// a request that outlives its instruction would trap the handler).
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_EXTERNAL_TRAP_TEST
`define RISCV_SMALL_EXTERNAL_TRAP_TEST

class riscv_small_external_trap_test extends riscv_small_base_test;

  `uvm_component_utils(riscv_small_external_trap_test)

  // One request, one trap: a request left standing would trap the first
  // instruction of the handler as well, and `expected_traps_exact` says so.
  localparam int unsigned EXPECTED_TRAPS = 1;

  localparam int unsigned DRAIN_CYCLES = 500;

  riscv_small_external_trap_seq seq;

  function new(string name = "riscv_small_external_trap_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    uvm_config_db#(bit)::set(this, "*", "expect_csr_claims", 1);
    uvm_config_db#(int unsigned)::set(this, "*", "expected_traps", EXPECTED_TRAPS);
    uvm_config_db#(bit)::set(this, "*", "expected_traps_exact", 1);
    super.build_phase(phase);
    seq = riscv_small_external_trap_seq::type_id::create("seq");
  endfunction : build_phase

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("TEST_RUN",
      "Starting the external trap request run (FR-22/Q-35): exception[3:0] = 5 asserted for one core cycle while a legal CSRRW occupies ID",
      UVM_LOW)

    seq.start(env.riscv_small_agnt.sequencer);

    env.sb.last_pc     = seq.last_pc;
    env.sb.last_pc_set = 1;
    wait_trap_drain(DRAIN_CYCLES);

    phase.drop_objection(this);
  endtask : run_phase

  task automatic wait_trap_drain(int unsigned max_cycles);
    int unsigned waited;

    waited = 0;
    while (!env.sb.is_done() && waited < max_cycles) begin
      @(posedge env.riscv_small_agnt.monitor.vif.clk);
      waited++;
    end

    if (!env.sb.is_done())
      `uvm_error("EXT_TRAP_TIMEOUT",
        $sformatf("the program did not reach its last instruction (0x%08h) within %0d clock cycle(s): %0d commit(s), %0d trap(s), %0d CSR value comparison(s) observed -- a request that was never taken leaves the control instructions retiring normally",
          seq.last_pc, max_cycles, env.sb.retire_obs_count, env.sb.trap_obs_count,
          env.sb.rd_val_compare_count))
    else
      `uvm_info("EXT_TRAP_DONE",
        $sformatf("program drained after %0d extra clock cycle(s): %0d commit(s), %0d trap(s), %0d CSR value comparison(s)",
          waited, env.sb.retire_obs_count, env.sb.trap_obs_count,
          env.sb.rd_val_compare_count),
        UVM_LOW)
  endtask : wait_trap_drain

endclass : riscv_small_external_trap_test

`endif
