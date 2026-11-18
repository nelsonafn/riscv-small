//------------------------------------------------------------------------------
// Reset-vector test for riscv_small (WP-11 P2: FR-41 / G-33)
//------------------------------------------------------------------------------
// One claim: the first fetch after reset presents the address RESET_VECTOR
// names. The claim is made by riscv_small_reset_checker from the MONITOR's
// observation; this test owns the objection and the clock-based timeout.
//
// Reset: the testbench top holds `rst_n` low for five cycles and releases it.
// The test does not drive reset (there is no reset pin on the driver modport)
// and does not need to: the monitor discards reset-time activity, so the first
// fetch it publishes is the first fetch after that release.
//
// Expectation: configuration. The top publishes the value the DUT elaborated
// with (`duv.RESET_VECTOR`) into `reset_vector`; this test only enables the
// comparison, so it holds no copy of the spec's default and a second
// elaboration with another value changes the expectation for free.
//
// The sequence is started with join_none: the item ends when the directed
// driver sees the program's last address -- which is RESET_VECTOR, the address
// the program is placed at. Waiting on the sequence instead of on the checker
// would tie the run's end to a driver detail; the run ends on the verdict,
// bounded by clocks.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_RESET_VECTOR_TEST_SV
`define RISCV_SMALL_RESET_VECTOR_TEST_SV

class riscv_small_reset_vector_test extends riscv_small_base_test;

  `uvm_component_utils(riscv_small_reset_vector_test)

  // The first fetch follows the reset release within a handful of cycles; the
  // bound is generous so it measures the DUT, not the scheduler.
  localparam int unsigned FIRST_FETCH_TIMEOUT_CYCLES = 200;

  riscv_small_reset_seq seq;

  function new(string name = "riscv_small_reset_vector_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    // Enable the claim. The expected address comes from the testbench top,
    // which reads it from the elaborated DUT parameter -- never from here.
    uvm_config_db#(bit)::set(this, "*", "check_reset_vector", 1);
    super.build_phase(phase);
    seq = riscv_small_reset_seq::type_id::create("seq");
  endfunction : build_phase

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("TEST_RUN",
      "Starting the reset-vector run (FR-41/G-33): first fetch after reset",
      UVM_LOW)

    fork
      seq.start(env.riscv_small_agnt.sequencer);
    join_none

    wait_first_fetch(FIRST_FETCH_TIMEOUT_CYCLES);

    phase.drop_objection(this);
  endtask : run_phase

  // The timeout is the test's; the verdict and `done` are the checker's.
  task automatic wait_first_fetch(int unsigned max_cycles);
    riscv_small_reset_checker rc;
    int unsigned waited;

    rc = env.reset_checker;
    if (rc == null) begin
      `uvm_fatal("RESET_VECTOR", "the environment built no reset checker; the claim cannot be made")
      return;
    end

    waited = 0;
    while (!rc.done && waited < max_cycles) begin
      @(posedge env.riscv_small_agnt.monitor.vif.clk);
      waited++;
    end

    if (!rc.done)
      `uvm_error("RESET_TIMEOUT",
        $sformatf("no fetch was published within %0d clock cycle(s); the first-fetch claim was NOT measured",
          max_cycles))
    else
      `uvm_info("RESET_DONE",
        $sformatf("first fetch decided after %0d clock cycle(s)", waited),
        UVM_LOW)
  endtask : wait_first_fetch

endclass : riscv_small_reset_vector_test

`endif
