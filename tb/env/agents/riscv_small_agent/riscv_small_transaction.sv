`ifndef RISCV_SMALL_TRANSACTION 
`define RISCV_SMALL_TRANSACTION

class riscv_small_transaction extends uvm_sequence_item;

  /*
   * For the memory-mapped environment, we can pass initialization
   * lists (program) to the driver.
   */
  int instruction_addr [];
  int instruction_list [];
  
  int data_addr [];
  int data_list [];

  /*
   * External trap request (FR-22, Q-35, WP-14b). The platform raises a
   * synchronous trap by presenting its reason on the DUT's `exception[3:0]`
   * input. The SEQUENCE names which instruction must be trapped and which cause
   * code the platform presents; the driver asserts the pin for exactly one core
   * cycle, in the cycle that instruction occupies the ID slot.
   *
   * The value is stimulus, so it is born in the sequence/test (AGENTS.md
   * responsibility 1). The value the MODEL predicts from is not these fields:
   * the monitor observes the same wire and publishes it on the event
   * (`obs_exception`), which is D13's rule and keeps the model passive-capable.
   */
  int exception_addr [];
  int exception_cause [];

  /*
   * Program item for the image/ISA path: the sequence owns the file and builds
   * the memory image here, so the driver only loads words and answers the bus.
   * `program_addr` is a byte address, `program_data` the 32-bit word.
   */
  int program_addr [];
  int program_data [];

  /*
   * For the monitor to capture what happened, we can capture a single cycle 
   * of transaction or memory operations.
   */
  bit op_is_inst;
  int captured_inst_addr;
  int captured_inst_data;
  /*
   * Fetch status: set when the memory was ready with a word while no request
   * was outstanding. The monitor publishes the observation; the verdict is the
   * fetch_pair_checker's. `captured_inst_addr` is then the raw address pin --
   * the address the core presents now -- and NOT the pair of that word.
   */
  bit captured_inst_orphan;

  bit op_is_data_read;
  bit op_is_data_write;
  int captured_data_addr;
  int captured_data_rd;
  int captured_data_wr;
  int captured_data_wr_ctrl;
  int captured_data_wr_strb;

  /*
   * Data-access completion (WP-13 P3: FR-38, G-18; P6b: FR-42, G-22). The
   * monitor publishes ONE data transaction per BEAT, not one per cycle the
   * enable is high; a non-split access is one beat, a crossing access is two,
   * and `captured_data_beat`/`captured_data_beats` say which one this is.
   *
   * `captured_data_grant` is 1 when the core presented the BEAT in a cycle in
   * which the memory asserted `data_ready` -- the handshake -- and 0 when the
   * beat left the bus without such a cycle. For a WRITE that is the defect
   * FR-38 names: the store was accepted in a cycle the memory did not grant it.
   * For a READ it is a fact about this core and not a defect: the load path
   * consumes `data_ready` one stage later (rtl/control.sv:288 checks the WB
   * slot's mux select), so a load's request is off the bus in the cycle the
   * grant arrives -- which is also why a read grant the memory withholds is
   * fatal and T-53 withholds writes only.
   *
   * `captured_data_wait` is how many clock cycles the BEAT stayed on the bus
   * and `captured_data_cycle` the first of them (1-based, post-reset and
   * clk_en-qualified edges), so a checker names the cycle in its message
   * instead of only the address.
   *
   * Beat index (WP-13 P6b: FR-42/G-22). An access whose byte lane plus width
   * crosses the word boundary is executed as TWO word-aligned beats
   * (rtl/misaligned_split.sv), so the unit of publication is the beat:
   *
   *   captured_data_beats = 1  the access was presented once; beat = 1
   *   captured_data_beats = 2  the access crossed the word boundary:
   *                            beat 1 at the address the core computed (the
   *                            suffix strobe), beat 2 at (addr & ~3) + 4 (the
   *                            prefix strobe)
   *
   * The monitor derives the pair from addr[1:0] + bytes > 4, the same rule the
   * RTL derives from access_size(funct3), and reports the beat it OBSERVED --
   * it does not require the second address to be the expected one. Judging the
   * two beats against each other is riscv_small_strb_checker's claim.
   */
  bit          captured_data_grant;
  int unsigned captured_data_wait;
  int unsigned captured_data_cycle;
  int unsigned captured_data_beat;
  int unsigned captured_data_beats;

  /*
   * Retire (commit) event: one instruction leaving the write-back slot, as the
   * probe bound inside the DUT reports it. The event is self-contained -- the
   * instruction word travels with it -- so the reference model executes what
   * the core retired instead of what it fetched (C-16, G-28).
   */
  bit op_is_retire;
  bit [31:0] retire_pc;      // PC of the retired instruction
  bit [31:0] retire_inst;    // its instruction word
  int        retire_rd;      // its destination register (rd0_addr_wb)
  bit [31:0] retire_wdata;   // the value it writes (rd0_data_wb)
  int unsigned retire_seq;   // 1-based commit index in this run
  /*
   * Whether the retired instruction actually writes its destination register
   * (the probe's rd0_wr_en_wb, WP-14). Without it two different obligations are
   * one observation: `CSRRW x0, mscratch, x6` must write nothing, while
   * `CSRRW x5, mscratch, x6` must write x5 -- and today both publish
   * retire_rd = 5 with a value, the destination latch holding whatever the
   * decode left there. FR-47's read-modify-write claim is not observable
   * without this bit.
   */
  bit retire_wr_en;

  /*
   * Trap event (WP-14 §4.2, E6): one per trap the core takes, published from
   * riscv_small_trap_if because the trapping instruction is flushed before
   * write-back and never retires -- a model fed only by retire is blind to the
   * one event the trap path exists to produce.
   *
   * `trap_inst` travels next to `trap_cause` on purpose: it is what lets the
   * reference model DERIVE the expected cause (illegal encoding -> 2, EBREAK ->
   * 3, ECALL -> 11) and compare it with the cause the core took. Publishing
   * only the cause would leave the model repeating the DUT's value.
   */
  bit          op_is_trap;
  bit [31:0]   trap_pc;      // PC of the instruction that trapped (mepc)
  bit [31:0]   trap_inst;    // that instruction word
  int unsigned trap_cause;   // the cause the DUT took (trap_cause[3:0])
  int unsigned trap_seq;     // 1-based trap index in this run

  /*
   * D13: `mtime` and `hart_id` as the MONITOR observed them when it published
   * the event. They are part of the observation, not of the stimulus: the
   * model predicts `time`/`timeh` (FR-49) and `mhartid` (FR-32) from these
   * values, so a DUT that reads a constant fails, and nothing but the monitor
   * tells the model what the platform drove (C-16).
   */
  bit [63:0] obs_mtime;
  bit [3:0]  obs_hart_id;

  /*
   * D13, extended to the external trap request (WP-14b, FR-22): the code the
   * platform was PRESENTING on `exception[3:0]` in the cycle of this event, as
   * the MONITOR read it off the pin. It is part of the observation, never of
   * the stimulus: the reference model predicts an external trap's cause from
   * this and from nothing else, because the pin is an input the platform owns
   * and a config_db copy would be a second source of truth (C-16).
   *
   * Zero means no external request was standing in that cycle, so the cause of
   * a trap published with obs_exception = 0 is the instruction's own.
   */
  bit [3:0] obs_exception;

  /*
   * The core clock cycle this event belongs to: 1-based, counted on the edges
   * the core actually clocked after reset, the same stamp `captured_data_cycle`
   * carries. It is what lets a checker relate a trap to the data beat that held
   * the pipeline (D12), instead of assuming the two ever coincided.
   */
  int unsigned obs_cycle;

  /*
   * Model predictions for the CSR/trap claim (WP-14). They travel on the same
   * analysis port as the store predictions, so a consumer dispatches by type;
   * the scoreboard compares them against the observations above and owns the
   * verdict.
   *
   *   op_is_pred_retire  one per retire observation, in order
   *   op_is_pred_trap    one per trap observation, in order
   *
   * `pred_claim` is 0 for a commit the model makes no claim about (an
   * instruction outside the CSR/trap subset). It is 1 when the model predicted
   * something -- and then:
   *
   *   pred_should_trap  the instruction must NOT retire; it owes the core a trap
   *   pred_cause        the cause that trap must carry (when pred_should_trap)
   *   pred_rd_wr        whether the instruction writes its destination register
   *   pred_value_known  pred_wdata is the value that must be written
   *   pred_rd_wr / pred_rd / pred_wdata are compared when pred_rd_wr and
   *   pred_value_known respectively say so, so "reads a value the model cannot
   *   predict" (a free-running counter) is stated, never silently skipped.
   */
  bit          op_is_pred_retire;
  bit          op_is_pred_trap;
  bit          pred_claim;
  bit          pred_should_trap;
  int unsigned pred_cause;
  bit          pred_rd_wr;
  bit [4:0]    pred_rd;
  bit          pred_value_known;
  bit [31:0]   pred_wdata;
  bit [31:0]   pred_pc;

  `uvm_object_utils_begin(riscv_small_transaction)
    `uvm_field_array_int(instruction_addr, UVM_ALL_ON)
    `uvm_field_array_int(instruction_list, UVM_ALL_ON)
    `uvm_field_array_int(data_addr, UVM_ALL_ON)
    `uvm_field_array_int(data_list, UVM_ALL_ON)
    `uvm_field_array_int(exception_addr, UVM_ALL_ON)
    `uvm_field_array_int(exception_cause, UVM_ALL_ON)
    `uvm_field_array_int(program_addr, UVM_ALL_ON)
    `uvm_field_array_int(program_data, UVM_ALL_ON)
    `uvm_field_int(op_is_inst, UVM_ALL_ON)
    `uvm_field_int(captured_inst_addr, UVM_ALL_ON)
    `uvm_field_int(captured_inst_data, UVM_ALL_ON)
    `uvm_field_int(captured_inst_orphan, UVM_ALL_ON)
    `uvm_field_int(op_is_data_read, UVM_ALL_ON)
    `uvm_field_int(op_is_data_write, UVM_ALL_ON)
    `uvm_field_int(captured_data_addr, UVM_ALL_ON)
    `uvm_field_int(captured_data_rd, UVM_ALL_ON)
    `uvm_field_int(captured_data_wr, UVM_ALL_ON)
    `uvm_field_int(captured_data_wr_ctrl, UVM_ALL_ON)
    `uvm_field_int(captured_data_wr_strb, UVM_ALL_ON)
    `uvm_field_int(captured_data_grant, UVM_ALL_ON)
    `uvm_field_int(captured_data_wait, UVM_ALL_ON)
    `uvm_field_int(captured_data_cycle, UVM_ALL_ON)
    `uvm_field_int(captured_data_beat, UVM_ALL_ON)
    `uvm_field_int(captured_data_beats, UVM_ALL_ON)
    `uvm_field_int(op_is_retire, UVM_ALL_ON)
    `uvm_field_int(retire_pc, UVM_ALL_ON)
    `uvm_field_int(retire_inst, UVM_ALL_ON)
    `uvm_field_int(retire_rd, UVM_ALL_ON)
    `uvm_field_int(retire_wdata, UVM_ALL_ON)
    `uvm_field_int(retire_seq, UVM_ALL_ON)
    `uvm_field_int(retire_wr_en, UVM_ALL_ON)
    `uvm_field_int(op_is_trap, UVM_ALL_ON)
    `uvm_field_int(trap_pc, UVM_ALL_ON)
    `uvm_field_int(trap_inst, UVM_ALL_ON)
    `uvm_field_int(trap_cause, UVM_ALL_ON)
    `uvm_field_int(trap_seq, UVM_ALL_ON)
    `uvm_field_int(obs_mtime, UVM_ALL_ON)
    `uvm_field_int(obs_hart_id, UVM_ALL_ON)
    `uvm_field_int(obs_exception, UVM_ALL_ON)
    `uvm_field_int(obs_cycle, UVM_ALL_ON)
    `uvm_field_int(op_is_pred_retire, UVM_ALL_ON)
    `uvm_field_int(op_is_pred_trap, UVM_ALL_ON)
    `uvm_field_int(pred_claim, UVM_ALL_ON)
    `uvm_field_int(pred_should_trap, UVM_ALL_ON)
    `uvm_field_int(pred_cause, UVM_ALL_ON)
    `uvm_field_int(pred_rd_wr, UVM_ALL_ON)
    `uvm_field_int(pred_rd, UVM_ALL_ON)
    `uvm_field_int(pred_value_known, UVM_ALL_ON)
    `uvm_field_int(pred_wdata, UVM_ALL_ON)
    `uvm_field_int(pred_pc, UVM_ALL_ON)
  `uvm_object_utils_end
   
  function new(string name = "riscv_small_transaction");
    super.new(name);
  endfunction

endclass

`endif
