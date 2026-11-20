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

  `uvm_object_utils_begin(riscv_small_transaction)
    `uvm_field_array_int(instruction_addr, UVM_ALL_ON)
    `uvm_field_array_int(instruction_list, UVM_ALL_ON)
    `uvm_field_array_int(data_addr, UVM_ALL_ON)
    `uvm_field_array_int(data_list, UVM_ALL_ON)
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
  `uvm_object_utils_end
   
  function new(string name = "riscv_small_transaction");
    super.new(name);
  endfunction

endclass

`endif
