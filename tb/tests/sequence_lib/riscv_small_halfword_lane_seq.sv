//------------------------------------------------------------------------------
// Halfword lane sequence for riscv_small (WP-13 P1: FR-11, FR-12, G-34)
//------------------------------------------------------------------------------
// Two cases, both at halfword offset 1 -- the only ODD halfword offset that
// stays INSIDE the addressed word (bytes 1-2). Offset 3 spans bytes 3-4, i.e.
// it crosses the word boundary: that is the split (FR-42/G-22, T-52) and is
// deliberately absent here.
//
//   load   LH/LHU at 0x401 of 0x9AABDE11. Bytes 0..3 are 11 DE AB 9A, so the
//          halfword at bytes 1-2 is 0xABDE. LH sign-extends it to 0xFFFFABDE
//          (bit 15 is set, so the sign term is part of the claim) and LHU gives
//          0x0000ABDE. A lane that ignores addr[0] returns bytes 0-1 = 0xDE11
//          instead: 0xFFFFDE11 / 0x0000DE11. Both differ from the expectation.
//
//   store  SH at 0x411 of 0x0000BEEF into the word 0x88776655 (bytes 55 66 77
//          88), then read the whole word back with LW and report it with SW.
//          Bytes 1-2 become EF BE, so the expected read-back is 0x88BEEF55. A
//          strobe of 0011 (the defect) writes bytes 0-1 instead and the
//          read-back differs.
//
// The store half is claimed twice, and the two are independent:
//   - on the store itself, because the model predicts the store contract --
//     address, byte strobes and lane-placed data -- so 4'b0011 where 4'b0110 is
//     required fails there, naming the strobe;
//   - on the value the memory ends up holding, through the LW read-back.
//
// Why every value is reported with SW: the reference model executes the loads
// and stores in its own architectural state and publishes one prediction per
// store, so each comparison is the scoreboard's. riscv_small_strb_checker
// cannot stand in for either half of the store claim: it only proves strobe <->
// width coherence, and 4'b0011 IS a legal halfword pattern, so a lane error
// passes it silently.
//
// The sequence owns the program and the values it expects. The driver is a
// memory BFM that knows none of them, the monitor publishes the accesses, the
// scoreboard decides and the test owns the objection.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_HALFWORD_LANE_SEQ
`define RISCV_SMALL_HALFWORD_LANE_SEQ

class riscv_small_halfword_lane_seq extends uvm_sequence #(riscv_small_transaction);

  `uvm_object_utils(riscv_small_halfword_lane_seq)

  // Data addresses. Every address is used as an offset from x0, so it must fit
  // the signed 12-bit immediate of the I/S formats (all of these are < 0x800).
  localparam int LOAD_WORD     = 'h400; // bytes 0..3 = 11 DE AB 9A
  localparam int LOAD_WORD_VAL = 'h9AAB_DE11;
  localparam int LOAD_BYTE     = 'h401; // bytes 1-2: the halfword, offset 1
  localparam int LH_DST        = 'h700; // SW of the LH result
  localparam int LHU_DST       = 'h704; // SW of the LHU result

  localparam int STORE_WORD      = 'h410; // bytes 0..3 = 55 66 77 88
  localparam int STORE_WORD_VAL  = 'h8877_6655;
  localparam int STORE_BYTE      = 'h411; // bytes 1-2: where the halfword lands
  localparam int STORE_DST       = 'h708; // SW of the read-back word
  localparam int HALF_SRC        = 'h420; // 0x0000BEEF, the value SH stores
  localparam int HALF_VAL        = 'h0000_BEEF;

  // What the program must produce. Printed by the sequence so the log names
  // them next to the scoreboard's comparison; the verdict is never taken here.
  localparam int LH_EXPECT       = 'hFFFF_ABDE; // bytes 1-2 = AB DE, sign-extended
  localparam int LHU_EXPECT      = 'h0000_ABDE; // bytes 1-2 = AB DE, zero-extended
  localparam int READBACK_EXPECT = 'h88BE_EF55; // bytes 1-2 <- EF BE
  localparam int HALF_STRB       = 4'b0110;     // bytes 1-2 of the word
  // What the defect produces: the lane ignores addr[0].
  localparam int BUGGY_LH        = 'hFFFF_DE11; // bits [15:0] = bytes 0-1
  localparam int BUGGY_LHU       = 'h0000_DE11;
  localparam int BUGGY_READBACK  = 'h8877_EFBE; // bytes 0-1 <- EF BE
  localparam int BUGGY_STRB      = 4'b0011;     // byte 0 instead of byte 1

  // NOPs that drain the pipeline: enough that this measures lane selection,
  // not the load-use hazard logic.
  localparam int BUBBLE = 5;
  // The SH must complete before the read-back LW reads the same word.
  localparam int GAP    = 3;
  localparam int TAIL   = 5;

  localparam bit [31:0] NOP = 32'h00000033; // ADD x0, x0, x0

  // Program base, set in body() from the value the top published (FR-41).
  protected bit [31:0] mem_base;

  function new (string name = "riscv_small_halfword_lane_seq");
    super.new(name);
  endfunction

  // I-type load: imm[11:0] | rs1 | funct3 | rd | opcode 0000011
  function automatic bit [31:0] enc_load(bit [2:0] f3, bit [4:0] rd, bit [11:0] imm);
    return {imm, 5'd0, f3, rd, 7'b0000011};
  endfunction

  // S-type store: imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode 0100011
  function automatic bit [31:0] enc_store(bit [2:0] f3, bit [4:0] rs2, bit [11:0] imm);
    return {imm[11:5], rs2, 5'd0, f3, imm[4:0], 7'b0100011};
  endfunction

  virtual task body();
    bit [31:0] prog[$];
    int        da[$];
    int        dv[$];
    int        last;

    mem_base = riscv_small_seq_mem_base(m_sequencer);
    req = riscv_small_transaction::type_id::create("req");

    // ---- Load half: LH and LHU at byte offset 1 of the source word ---------
    prog.push_back(enc_load(3'b001, 5'd10, 12'(LOAD_BYTE)));    // LH  x10, 1(x0)
    repeat (BUBBLE) prog.push_back(NOP);
    prog.push_back(enc_store(3'b010, 5'd10, 12'(LH_DST)));      // SW  x10, 0x700

    prog.push_back(enc_load(3'b101, 5'd11, 12'(LOAD_BYTE)));    // LHU x11, 1(x0)
    repeat (BUBBLE) prog.push_back(NOP);
    prog.push_back(enc_store(3'b010, 5'd11, 12'(LHU_DST)));     // SW  x11, 0x704

    // ---- Store half: SH at byte offset 1, then read the word back ----------
    prog.push_back(enc_load(3'b010, 5'd12, 12'(HALF_SRC)));     // LW  x12, 0x420
    repeat (BUBBLE) prog.push_back(NOP);
    prog.push_back(enc_store(3'b001, 5'd12, 12'(STORE_BYTE)));  // SH  x12, 0x411
    repeat (GAP) prog.push_back(NOP);
    prog.push_back(enc_load(3'b010, 5'd13, 12'(STORE_WORD)));   // LW  x13, 0x410
    repeat (BUBBLE) prog.push_back(NOP);
    prog.push_back(enc_store(3'b010, 5'd13, 12'(STORE_DST)));   // SW  x13, 0x708

    repeat (TAIL) prog.push_back(NOP);

    last = prog.size();
    req.instruction_addr = new[last];
    req.instruction_list = new[last];
    foreach (prog[i]) begin
      req.instruction_addr[i] = mem_base + i * 4;
      req.instruction_list[i] = prog[i];
    end

    // ---- Data memory: one entry per byte address the program names ---------
    // The directed BFM answers an access only at a declared address, and it
    // returns the whole word at a byte address (the data port has no lane).
    for (int i = 0; i < 4; i++) begin
      da.push_back(LOAD_WORD + i);  dv.push_back(LOAD_WORD_VAL);
    end
    for (int i = 0; i < 4; i++) begin
      da.push_back(STORE_WORD + i); dv.push_back(STORE_WORD_VAL);
    end
    da.push_back(HALF_SRC); dv.push_back(HALF_VAL);
    // Report destinations: the value is whatever the DUT read back.
    da.push_back(LH_DST);    dv.push_back('x);
    da.push_back(LHU_DST);   dv.push_back('x);
    da.push_back(STORE_DST); dv.push_back('x);

    req.data_addr = new[da.size()];
    req.data_list = new[dv.size()];
    foreach (da[i]) begin
      req.data_addr[i] = da[i];
      req.data_list[i] = dv[i];
    end

    `uvm_info("HALF_LANE",
      $sformatf("LH  @0x%03h of 0x%08h -> 0x%08h (bytes 1-2, sign-extended); a lane that ignores addr[0] gives 0x%08h, expected 0x%08h",
        LOAD_BYTE, LOAD_WORD_VAL, LH_EXPECT, BUGGY_LH, LH_EXPECT), UVM_LOW)
    `uvm_info("HALF_LANE",
      $sformatf("LHU @0x%03h of 0x%08h -> 0x%08h (bytes 1-2, zero-extended); a lane that ignores addr[0] gives 0x%08h, expected 0x%08h",
        LOAD_BYTE, LOAD_WORD_VAL, LHU_EXPECT, BUGGY_LHU, LHU_EXPECT), UVM_LOW)
    `uvm_info("HALF_LANE",
      $sformatf("SH  0x%04h @0x%03h of 0x%08h, read back at 0x%03h -> 0x%08h; the defect strobes 4'b%04b (byte 0) and reads back 0x%08h, expected strobe 4'b%04b / 0x%08h",
        HALF_VAL[15:0], STORE_BYTE, STORE_WORD_VAL, STORE_WORD,
        READBACK_EXPECT, BUGGY_STRB, BUGGY_READBACK, HALF_STRB, READBACK_EXPECT),
      UVM_LOW)

    // The program image is configuration, not a transaction: the test creates
    // it, this sequence fills in what it built, and the model/checkers read it.
    register_image(req);

    // The program item is complete: hand it to the driver, the only consumer.
    start_item(req);
    finish_item(req);
  endtask

  // The program image receives the words this sequence built. It is state a
  // checker reads, never a stream and never a path into the reference model's
  // execution: the model's architectural state is updated from the monitor.
  function void register_image(riscv_small_transaction item);
    riscv_small_program_image image;
    if (!uvm_config_db#(riscv_small_program_image)::get(m_sequencer, "", "program_image", image))
      return;
    foreach (item.instruction_addr[i])
      image.add_inst(item.instruction_addr[i], item.instruction_list[i]);
    foreach (item.data_addr[i])
      image.add_data(item.data_addr[i], item.data_list[i]);
  endfunction

endclass

`endif
