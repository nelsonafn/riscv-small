//------------------------------------------------------------------------------
// Trap during a split beat (D12) sequence for riscv_small (WP-14b: FR-22, FR-42)
//------------------------------------------------------------------------------
// One claim: a trap is NOT taken while a misaligned access holds the pipeline,
// and taking it on the edge the access completes loses nothing. That is D12's
// guarantee (rtl/control.sv gates `trap_valid` on the four enables and holds the
// flushes while `split_stall` or the data wait is high); no test observed it
// before this one.
//
// The stimulus is T-53's withholding memory: the data BFM withholds the grant
// for two edges per beat, and the access itself CROSSES the word boundary, so
// the crossing store below keeps MA -- and the whole pipeline -- for several
// cycles. The trapping instruction is placed two behind it, which puts it in ID
// on the very cycle the store enters MA: the request exists while the pipeline
// is frozen, and the trap can only be taken when the beat completes.
//
// The program (25 words; the handler sits immediately after the JAL so that no
// placed word is filler and the image's count target is exact):
//
//   3,4    x10 = 0x1234_5678
//   5      mscratch <- x10                    the marker read after the trap
//   6      SW x10, 0x401                      crossing store: beats at 0x400 (lane
//                                             1) and 0x404, held for the grant
//   7      NOP                                in EX while the store is in MA
//   8      ecall                              *** trap site, in ID while the
//                                             store holds MA ***
//   9      csrrs x21, mepc, x0                the ecall's own address
//  10      csrrs x22, mcause, x0              11
//  11      csrrs x23, mscratch, x0            the marker: nothing was lost
//  12      jal to the tail
//  13..16  the handler: read the pair, return to mepc + 4
//  17..24  the tail
//
// The claims this program makes, all through values:
//
//   exactly one trap            `expected_traps` + `expected_traps_exact`: a
//                               trap_valid held for two cycles publishes two
//                               events and fails D12b;
//   the trap is the ecall's     mepc reads the ecall's address (a trap taken one
//                               instruction early or late reads another one);
//   no instruction was lost     the program image + `add_no_retire(ecall)`: every
//                               placed word except the declared trap site must
//                               retire (riscv_small_retire_checker, claim 6),
//                               which is exactly the WP-13 failure mode -- a
//                               flush firing while the pipeline is held and
//                               discarding the instruction behind the store;
//   the trap was deferred       the trap's cycle stamp must be at or after the
//                               crossing access's second beat (the scoreboard's
//                               `trap_hold_check`), so the hold really happened.
//
// This sequence only builds the program and the image. It judges nothing.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_TRAP_SPLIT_SEQ
`define RISCV_SMALL_TRAP_SPLIT_SEQ

class riscv_small_trap_split_seq extends uvm_sequence #(riscv_small_transaction);

  `uvm_object_utils(riscv_small_trap_split_seq)

  localparam bit [11:0] CSR_MTVEC    = 12'h305;
  localparam bit [11:0] CSR_MSCRATCH = 12'h340;
  localparam bit [11:0] CSR_MEPC     = 12'h341;
  localparam bit [11:0] CSR_MCAUSE   = 12'h342;

  // The store: a word at byte offset 1 crosses the word boundary, so the core
  // executes it as two beats -- 0x400 with the suffix strobe, then 0x404.
  localparam int STORE_ADDR = 'h401;
  localparam int BEAT1_ADDR = 'h400;
  localparam int BEAT2_ADDR = 'h404;
  localparam bit [31:0] STORE_VALUE = 32'h1234_5678;

  localparam int IDX_STORE     = 6;
  localparam int IDX_TRAP_SITE = 8;
  localparam int IDX_SKIP      = 12;  // jal over the handler
  localparam int IDX_HANDLER   = 13;
  localparam int IDX_TAIL      = 17;
  localparam int PROG_WORDS    = 25;

  localparam bit [31:0] NOP   = 32'h0000_0033; // ADD x0, x0, x0
  localparam bit [31:0] ECALL = 32'h0000_0073;

  protected bit [31:0] mem_base;

  bit [31:0] last_pc;

  function new (string name = "riscv_small_trap_split_seq");
    super.new(name);
  endfunction

  // ---- Encoders ------------------------------------------------------------
  function automatic bit [31:0] enc_lui(bit [4:0] rd, bit [19:0] imm20);
    return {imm20, rd, 7'b0110111};
  endfunction

  function automatic bit [31:0] enc_auipc(bit [4:0] rd, bit [19:0] imm20);
    return {imm20, rd, 7'b0010111};
  endfunction

  function automatic bit [31:0] enc_addi(bit [4:0] rd, bit [4:0] rs1, bit [11:0] imm);
    return {imm, rs1, 3'b000, rd, 7'b0010011};
  endfunction

  function automatic bit [31:0] enc_jal(bit [4:0] rd, int byte_offset);
    bit [20:0] imm = 21'(byte_offset);
    return {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
  endfunction

  function automatic bit [31:0] enc_jalr(bit [4:0] rd, bit [4:0] rs1, bit [11:0] imm);
    return {imm, rs1, 3'b000, rd, 7'b1100111};
  endfunction

  // S-type store: imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode 0100011
  function automatic bit [31:0] enc_store(bit [2:0] f3, bit [4:0] rs2, bit [4:0] rs1,
                                          bit [11:0] imm);
    return {imm[11:5], rs2, rs1, f3, imm[4:0], 7'b0100011};
  endfunction

  function automatic bit [31:0] enc_csr(bit [2:0] funct3, bit [11:0] csr,
                                        bit [4:0] rs1, bit [4:0] rd);
    return {csr, rs1, funct3, rd, 7'b1110011};
  endfunction

  function void expect_index(int unsigned size, int unsigned want, string what);
    if (size != want)
      `uvm_fatal("TRAP_SPLIT_SEQ",
        $sformatf("program layout drifted: %s sits at index %0d, expected %0d; the JAL offsets, the mtvec value and the declared skip/trap addresses are stale",
          what, size, want))
  endfunction

  virtual task body();
    bit [31:0] prog[$];
    int        da[$];
    int        dv[$];
    int        last;

    mem_base = riscv_small_seq_mem_base(m_sequencer);
    req = riscv_small_transaction::type_id::create("req");

    // ---- The vector -------------------------------------------------------
    prog.push_back(enc_auipc(5'd18, 20'h0));                      // 0
    prog.push_back(enc_addi(5'd18, 5'd18, 12'(IDX_HANDLER * 4))); // 1: x18 = handler
    prog.push_back(enc_csr(3'b001, CSR_MTVEC, 5'd18, 5'd0));      // 2: mtvec <- x18

    // ---- The store operand, the marker, and the crossing store -----------
    prog.push_back(enc_lui(5'd10, STORE_VALUE[31:12]));            // 3: x10 = 0x1234_5000
    prog.push_back(enc_addi(5'd10, 5'd10, 12'(STORE_VALUE[11:0])));// 4: x10 = 0x1234_5678
    prog.push_back(enc_csr(3'b001, CSR_MSCRATCH, 5'd10, 5'd0));    // 5: mscratch <- x10
    expect_index(prog.size(), IDX_STORE, "the crossing store");
    prog.push_back(enc_store(3'b010, 5'd10, 5'd0, 12'(STORE_ADDR))); // 6: SW x10, 0x401
    prog.push_back(NOP);                                            // 7: in EX when the store is in MA
    expect_index(prog.size(), IDX_TRAP_SITE, "the trap site");
    prog.push_back(ECALL);                                          // 8: trap in ID while the store holds MA

    // ---- The values the trap must leave behind ---------------------------
    prog.push_back(enc_csr(3'b010, CSR_MEPC,     5'd0, 5'd21));     // 9:  addr(8)
    prog.push_back(enc_csr(3'b010, CSR_MCAUSE,   5'd0, 5'd22));     // 10: 11
    prog.push_back(enc_csr(3'b010, CSR_MSCRATCH, 5'd0, 5'd23));     // 11: 0x1234_5678

    expect_index(prog.size(), IDX_SKIP, "the JAL over the handler");
    prog.push_back(enc_jal(5'd0, (IDX_TAIL - IDX_SKIP) * 4));        // 12: skip the handler

    // ---- The handler ------------------------------------------------------
    expect_index(prog.size(), IDX_HANDLER, "the handler");
    prog.push_back(enc_csr(3'b010, CSR_MEPC,   5'd0, 5'd24));        // 13
    prog.push_back(enc_csr(3'b010, CSR_MCAUSE, 5'd0, 5'd25));        // 14
    prog.push_back(enc_addi(5'd26, 5'd24, 12'd4));                   // 15: mepc + 4
    prog.push_back(enc_jalr(5'd0, 5'd26, 12'd0));                    // 16: return

    expect_index(prog.size(), IDX_TAIL, "the tail");
    while (prog.size() < PROG_WORDS) prog.push_back(NOP);            // 17..24

    // ---- Program item ----------------------------------------------------
    last = prog.size();
    req.instruction_addr = new[last];
    req.instruction_list = new[last];
    foreach (prog[i]) begin
      req.instruction_addr[i] = mem_base + i * 4;
      req.instruction_list[i] = prog[i];
    end
    last_pc = req.instruction_addr[last - 1];

    // ---- Data memory: one entry per byte address the store's beats name --
    // The directed BFM answers an access only at a declared address, so both
    // beats are declared. `data_ready_delay` (the test's configuration) withholds
    // the grant for each of them, which is what keeps the pipeline frozen long
    // enough for the trap request to exist while it is.
    da.push_back(STORE_ADDR);  dv.push_back(0);
    da.push_back(BEAT1_ADDR);  dv.push_back(0);
    da.push_back(BEAT2_ADDR);  dv.push_back(0);

    req.data_addr = new[da.size()];
    req.data_list = new[dv.size()];
    foreach (da[i]) begin
      req.data_addr[i] = da[i];
      req.data_list[i] = dv[i];
    end

    // The program image is configuration: the retire checker proves that every
    // placed word except the declared trap site retires, and that the trap site
    // does not.
    register_image(req);

    `uvm_info("TRAP_SPLIT_SEQ",
      $sformatf("program: %0d instructions at 0x%08h..0x%08h, handler at 0x%08h, SW x10,0x%03h at 0x%08h (beats 0x%03h/0x%03h), ecall at 0x%08h two instructions behind it",
        last, req.instruction_addr[0], last_pc, mem_base + IDX_HANDLER * 4,
        STORE_ADDR, mem_base + IDX_STORE * 4, BEAT1_ADDR, BEAT2_ADDR,
        mem_base + IDX_TRAP_SITE * 4),
      UVM_LOW)
    `uvm_info("TRAP_SPLIT_SEQ",
      "the defect this program measures: a trap taken while the crossing store holds MA -- or a flush that fires on a held pipeline -- loses the instruction behind the store (the WP-13 failure mode) or publishes the trap more than once (D12b)",
      UVM_LOW)

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
    // The instruction that traps is flushed before write-back: it must NOT
    // retire, and every other placed word must. No word is skipped here: the
    // handler sits right after the JAL and the two fetches that jump discards
    // are re-fetched when the trap enters it and when the handler returns.
    image.add_no_retire(item.instruction_addr[IDX_TRAP_SITE]);
  endfunction

endclass

`endif
