//------------------------------------------------------------------------------
// Trap during a split beat (D12) test for riscv_small (WP-14b: FR-22, FR-42)
//------------------------------------------------------------------------------
// One claim: a trap raised while a misaligned access holds the pipeline is taken
// exactly once, on the edge that releases it, and it loses no instruction.
//
// That is D12's guarantee. It is structural in the RTL -- rtl/control.sv gates
// `trap_valid` on the four pipeline enables and holds the flushes while
// `split_stall` or the data wait is high -- and no test observed it before this
// one. The stimulus is T-53's withholding memory: the data BFM withholds the
// grant for two edges per beat, and the access crosses the word boundary, so a
// crossing store keeps MA frozen for several cycles with the trapping
// instruction two behind it, already in ID.
//
// The four claims, and who owns each:
//
//   exactly one trap   riscv_small_scoreboard (`expected_traps_exact`): the
//                      D12b contract is one cycle of `trap_valid` per trap, so a
//                      held request publishes two events and fails here;
//   the right trap     the reference model derives cause 11 from the ECALL and
//                      the handler reads `mepc`/`mcause` back by value;
//   nothing was lost   riscv_small_retire_checker against the program image: the
//                      declared trap site must NOT retire, every other placed
//                      word must -- the WP-13 failure mode was a flush firing on
//                      a held pipeline and discarding the instruction behind the
//                      store, which this catches by naming the pc;
//   the trap was held  riscv_small_scoreboard (`trap_hold_check`): the trap's
//                      cycle stamp must be at or after the crossing access's
//                      second beat, so the hold really happened and this test is
//                      not passing on a stimulus that never overlapped.
//
// The verdict belongs to the checkers. This test owns the objection and the
// clock-bounded drain, and configures the memory's grant delay -- stimulus, not
// an opinion.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_TRAP_SPLIT_TEST
`define RISCV_SMALL_TRAP_SPLIT_TEST

class riscv_small_trap_split_test extends riscv_small_base_test;

  `uvm_component_utils(riscv_small_trap_split_test)

  // T-53's acceptance cell: the data memory withholds the grant for two cycles.
  // Applied per beat, it keeps the crossing store on the bus for several cycles
  // while the ECALL behind it waits in ID.
  localparam int unsigned READY_DELAY = 2;

  localparam int unsigned EXPECTED_TRAPS = 1;

  riscv_small_trap_split_seq seq;
  riscv_small_program_image image;

  function new(string name = "riscv_small_trap_split_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    uvm_config_db#(bit)::set(this, "*", "expect_csr_claims", 1);
    uvm_config_db#(int unsigned)::set(this, "*", "expected_traps", EXPECTED_TRAPS);
    uvm_config_db#(bit)::set(this, "*", "expected_traps_exact", 1);
    // The claim that the trap really met a held pipeline.
    uvm_config_db#(bit)::set(this, "*", "trap_hold_check", 1);
    // The stimulus that makes it observable: the memory withholds the grant.
    uvm_config_db#(int unsigned)::set(this, "*", "data_ready_delay", READY_DELAY);
    // The program image is configuration (C-16): the retire checker's oracle for
    // "every placed word except the trap site retires", and the model's initial
    // data memory.
    image = riscv_small_program_image::type_id::create("program_image");
    uvm_config_db#(riscv_small_program_image)::set(this, "*", "program_image", image);
    super.build_phase(phase);
    seq = riscv_small_trap_split_seq::type_id::create("seq");
  endfunction : build_phase

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("TEST_RUN",
      $sformatf("Starting the trap-during-split run (FR-22/D12): a crossing SW at 0x401 with data_ready withheld for %0d edges, and an ECALL two instructions behind it",
        READY_DELAY),
      UVM_LOW)

    seq.start(env.riscv_small_agnt.sequencer);

    // Two ends of the same program: the scoreboard's `done` is the commit at the
    // last instruction (all earlier observations compared), and the retire
    // checker's is its own count target. Waiting on both keeps a missing commit
    // from being read as a pass.
    env.sb.last_pc     = seq.last_pc;
    env.sb.last_pc_set = 1;
    wait_trap_drain(2000);
    wait_program_drain(2000);

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
      `uvm_error("TRAP_SPLIT_TIMEOUT",
        $sformatf("the program did not reach its last instruction (0x%08h) within %0d clock cycle(s): %0d commit(s), %0d trap(s), %0d store prediction(s) compared, %0d observed",
          seq.last_pc, max_cycles, env.sb.retire_obs_count, env.sb.trap_obs_count,
          env.sb.store_pred_count, env.sb.obs_count))
    else
      `uvm_info("TRAP_SPLIT_DONE",
        $sformatf("program drained after %0d extra clock cycle(s): %0d commit(s), %0d trap(s), %0d store beat(s) compared",
          waited, env.sb.retire_obs_count, env.sb.trap_obs_count, env.sb.obs_count),
        UVM_LOW)
  endtask : wait_trap_drain

endclass : riscv_small_trap_split_test

`endif
