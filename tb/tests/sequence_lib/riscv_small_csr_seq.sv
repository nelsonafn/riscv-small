//------------------------------------------------------------------------------
// CSR and trap sequence for riscv_small (WP-14: FR-22..FR-25, FR-29, FR-32,
// FR-37, FR-47, FR-49..FR-52)
//------------------------------------------------------------------------------
// One claim: the machine-mode CSR file and the trap entry behave as the
// specification says. This sequence only BUILDS the program -- it never judges
// it and never decides the end of the run.
//
// The program has five parts, in this order:
//
//   1. mtvec <- the handler (FR-29). The vector is computed with AUIPC + ADDI,
//      so it is the address this program actually placed the handler at and not
//      a constant: a core that jumps to 1000 finds nothing there and the run
//      never reaches the tail.
//
//   2. the six Zicsr instructions on mscratch, then the rd = x0 and rs1 = x0
//      clauses, then one read of every implemented address of FR-50 (FR-47,
//      FR-51, FR-52, FR-32, FR-37, FR-49). Every value the model can predict is
//      compared by the scoreboard; `mstatus` is read to exercise the address
//      and stated as not comparable (a reset value A-04 leaves UNSPECIFIED).
//
//   2b. `csrrs x19, mhartid, x24` with x24 = 0 (part 3, the last trap). The
//      write-suppression rule is the REGISTER SPECIFIER, not the value (vol. I,
//      Zicsr): a non-x0 register holding zero still writes, so writing it to a
//      read-only address still raises illegal-instruction. A core (or a model)
//      that tests `src != 0` lets this instruction through.
//
//   3. seven traps BACK TO BACK (FR-24, FR-25, FR-50): ECALL, EBREAK, an
//      unallocated encoding, a read of an unimplemented address, a write to the
//      read-only mhartid, a write to the read-only time view, and the
//      zero-valued non-x0 write above. The instruction at mepc+4 is the NEXT
//      trap site, so the handler's return is proven on every one of them and
//      FR-22's "discard what was fetched" is exercised on the instruction that
//      follows a trap. A write to mtval immediately before the section must NOT
//      trap (FR-52): the legal instructions in a row are the control.
//
//   4. the counter aliases (FR-50; vol. II §2.1.1.10): `cycle`/`cycleh` are
//      views of `mcycle` and `instret`/`instreth` of `minstret`, so a write to
//      the machine counter changes what the read-only alias returns. The high
//      halves are written with a distinctive non-zero value and read back
//      through the aliases; the low halves are then written 0xFFFF_FFFF, which
//      carries into the high half exactly once -- so `cycleh`/`instreth` must
//      read one more than the value the program wrote. That is a value the
//      model can predict without ever counting a clock, and a core that keeps
//      `cycle` in its own register reads zero. `cycle` itself (0xC00) is read
//      too, and is stated as not comparable (a free-running low half).
//
//   5. the handler at +0x200 and a tail. The handler reads mepc and mcause with
//      CSRRS (FR-23 -- the pair the trap event must have produced) and returns
//      with JALR to mepc + 4. It is placed after a JAL so the fall-through path
//      never enters it, and the tail reports the post-trap instret/mcause/mepc.
//
// No data memory is touched: every operand is an immediate, so the program needs
// no program image and the checkers that need one (the fetch-pair and retire
// checkers) stay inert. That is deliberate -- they compare the commit stream
// against the program as a fixed sequence, and a trap legitimately removes an
// instruction from that sequence; T-03's claim is the CSR/trap path, and it is
// made by the model on the retire and trap streams.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_CSR_SEQ
`define RISCV_SMALL_CSR_SEQ

class riscv_small_csr_seq extends uvm_sequence #(riscv_small_transaction);

  `uvm_object_utils(riscv_small_csr_seq)

  // CSR addresses (FR-50). Named here, never as a bare number in an encoding.
  localparam bit [11:0] CSR_MSTATUS    = 12'h300;
  localparam bit [11:0] CSR_MISA       = 12'h301;
  localparam bit [11:0] CSR_MEDELEG    = 12'h302; // NOT implemented: cause 2
  localparam bit [11:0] CSR_MTVEC      = 12'h305;
  localparam bit [11:0] CSR_MSTATUSH   = 12'h310;
  localparam bit [11:0] CSR_MSCRATCH   = 12'h340;
  localparam bit [11:0] CSR_MEPC       = 12'h341;
  localparam bit [11:0] CSR_MCAUSE     = 12'h342;
  localparam bit [11:0] CSR_MTVAL      = 12'h343;
  localparam bit [11:0] CSR_MCYCLE     = 12'hB00;
  localparam bit [11:0] CSR_MINSTRET   = 12'hB02;
  localparam bit [11:0] CSR_MCYCLEH    = 12'hB80;
  localparam bit [11:0] CSR_MINSTRETH  = 12'hB82;
  localparam bit [11:0] CSR_CYCLE      = 12'hC00;
  localparam bit [11:0] CSR_CYCLEH     = 12'hC80;
  localparam bit [11:0] CSR_TIME       = 12'hC01;
  localparam bit [11:0] CSR_TIMEH      = 12'hC81;
  localparam bit [11:0] CSR_INSTRET    = 12'hC02;
  localparam bit [11:0] CSR_MHPMCOUNTER3 = 12'hB03;
  localparam bit [11:0] CSR_MVENDORID  = 12'hF11;
  localparam bit [11:0] CSR_MARCHID    = 12'hF12;
  localparam bit [11:0] CSR_MIMPID     = 12'hF13;
  localparam bit [11:0] CSR_MHARTID    = 12'hF14;
  localparam bit [11:0] CSR_MCONFIGPTR = 12'hF15;

  // The layout, named so a drift is a fatal and not a wrong program. Every
  // index is an instruction index; the address is mem_base + 4 * index.
  localparam int IDX_AUIPC    = 2;   // the AUIPC that starts the mtvec value
  localparam int IDX_GROUPS   = 26;  // the first counter read, after the groups
  localparam int IDX_TRAPS    = 30;  // the first trap site (ECALL)
  localparam int IDX_SKIP     = 57;  // JAL over the handler
  localparam int IDX_HANDLER  = 128; // 0x200: a distinctive, non-zero vector
  localparam int IDX_TAIL     = 132;
  localparam int PROG_WORDS   = 144;

  localparam bit [31:0] NOP = 32'h0000_0033; // ADD x0, x0, x0

  // An encoding reserved for a future standard extension: opcode 1111011 is
  // outside §4.1, so it must raise illegal-instruction (FR-24, Q-05) and not
  // execute as a no-operation.
  localparam bit [31:0] ILLEGAL_WORD = 32'h0000_007B;

  // Program base, set in body() from the value the top published (FR-41).
  protected bit [31:0] mem_base;

  // The address of the program's last instruction. The test publishes it to the
  // scoreboard, whose `done` is the commit at this address: the end of the run
  // is the checker's signal, not a count of objects.
  bit [31:0] last_pc;

  function new (string name = "riscv_small_csr_seq");
    super.new(name);
  endfunction

  // ---- Encoders (one function per format this program uses) ----------------
  function automatic bit [31:0] enc_lui(bit [4:0] rd, bit [19:0] imm20);
    return {imm20, rd, 7'b0110111};
  endfunction

  function automatic bit [31:0] enc_auipc(bit [4:0] rd, bit [19:0] imm20);
    return {imm20, rd, 7'b0010111};
  endfunction

  function automatic bit [31:0] enc_addi(bit [4:0] rd, bit [4:0] rs1, bit [11:0] imm);
    return {imm, rs1, 3'b000, rd, 7'b0010011};
  endfunction

  // J-type: imm[20|10:1|11|19:12].
  function automatic bit [31:0] enc_jal(bit [4:0] rd, int byte_offset);
    bit [20:0] imm = 21'(byte_offset);
    return {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
  endfunction

  // I-type JALR: the handler's return, `jalr x0, 0(x22)`.
  function automatic bit [31:0] enc_jalr(bit [4:0] rd, bit [4:0] rs1, bit [11:0] imm);
    return {imm, rs1, 3'b000, rd, 7'b1100111};
  endfunction

  // SYSTEM: CSR* by funct3 (001/010/011/101/110/111) and ECALL/EBREAK by
  // funct3 = 000 and imm (this program uses the literal 32'h00000073 and
  // 32'h00100073 instead, so the two names stay visible).
  function automatic bit [31:0] enc_csr(bit [2:0] funct3, bit [11:0] csr,
                                        bit [4:0] rs1, bit [4:0] rd);
    return {csr, rs1, funct3, rd, 7'b1110011};
  endfunction

  localparam bit [31:0] ECALL  = 32'h0000_0073;
  localparam bit [31:0] EBREAK = 32'h0010_0073;

  // A layout assertion: the JAL offsets and the mtvec value below are computed
  // from these indices, so a drifted program would still assemble -- into the
  // wrong one. Fail loudly instead.
  function void expect_index(int unsigned size, int unsigned want, string what);
    if (size != want)
      `uvm_fatal("CSR_SEQ",
        $sformatf("program layout drifted: %s sits at index %0d, expected %0d; the JAL offsets and the mtvec value are stale",
          what, size, want))
  endfunction

  virtual task body();
    bit [31:0] prog[$];
    int        last;

    mem_base = riscv_small_seq_mem_base(m_sequencer);
    req = riscv_small_transaction::type_id::create("req");

    // ---- 1. The vector (FR-29) --------------------------------------------
    prog.push_back(enc_lui(5'd6, 20'h12345));                 // 0: x6 = 0x1234_5000
    prog.push_back(enc_addi(5'd6, 5'd6, 12'h678));            // 1: x6 = 0x1234_5678
    expect_index(prog.size(), IDX_AUIPC, "AUIPC x18, 0");
    prog.push_back(enc_auipc(5'd18, 20'h0));                  // 2: x18 = pc of this word
    prog.push_back(enc_addi(5'd18, 5'd18, 12'((IDX_HANDLER - IDX_AUIPC) * 4)));
                                                             // 3: x18 = address of the handler
    prog.push_back(enc_csr(3'b001, CSR_MTVEC, 5'd18, 5'd0));  // 4: mtvec <- x18, rd = x0 (D4)

    // ---- 2a. The six Zicsr instructions on mscratch (FR-47, FR-51) --------
    prog.push_back(enc_csr(3'b001, CSR_MSCRATCH, 5'd6,  5'd5));  // 5:  CSRRW  x5  <- 0 ; mscratch <- x6
    prog.push_back(enc_addi(5'd8, 5'd0, 12'd15));                // 6:  x8  = 15
    prog.push_back(enc_csr(3'b010, CSR_MSCRATCH, 5'd8,  5'd7));  // 7:  CSRRS  x7  <- mscratch ; |= x8
    prog.push_back(enc_addi(5'd10, 5'd0, 12'd240));              // 8:  x10 = 0xF0
    prog.push_back(enc_csr(3'b011, CSR_MSCRATCH, 5'd10, 5'd9));  // 9:  CSRRC  x9  <- mscratch ; &= ~x10
    prog.push_back(enc_csr(3'b101, CSR_MSCRATCH, 5'd31, 5'd11)); // 10: CSRRWI x11 <- mscratch ; <- 31
    prog.push_back(enc_csr(3'b110, CSR_MSCRATCH, 5'd3,  5'd12)); // 11: CSRRSI x12 <- mscratch ; |= 3
    prog.push_back(enc_csr(3'b111, CSR_MSCRATCH, 5'd1,  5'd13)); // 12: CSRRCI x13 <- mscratch ; &= ~1

    // ---- 2b. The rd = x0 and rs1 = x0 clauses (D4/D5, FR-50) -------------
    prog.push_back(enc_addi(5'd16, 5'd0, 12'd2047));             // 13: x16 = 2047
    prog.push_back(enc_csr(3'b001, CSR_MSCRATCH, 5'd16, 5'd0));  // 14: write, no rd (D4)
    prog.push_back(enc_csr(3'b010, CSR_MSCRATCH, 5'd0,  5'd17)); // 15: read, no write (D5)
    prog.push_back(enc_csr(3'b010, CSR_MHARTID,  5'd0,  5'd15)); // 16: read a RO CSR with rs1 = x0

    // ---- 2c. One access per implemented group, plus one not implemented ---
    prog.push_back(enc_csr(3'b010, CSR_MSTATUS,   5'd0, 5'd19)); // 17: not comparable (A-04)
    prog.push_back(enc_csr(3'b010, CSR_MVENDORID, 5'd0, 5'd19)); // 18: 0 (FR-50)
    prog.push_back(enc_csr(3'b010, CSR_MARCHID,   5'd0, 5'd19)); // 19: 0
    prog.push_back(enc_csr(3'b010, CSR_MIMPID,    5'd0, 5'd19)); // 20: 0
    prog.push_back(enc_csr(3'b010, CSR_MCONFIGPTR,5'd0, 5'd19)); // 21: 0
    prog.push_back(enc_csr(3'b010, CSR_MSTATUSH,  5'd0, 5'd19)); // 22: 0, RO zero (FR-50)
    prog.push_back(enc_csr(3'b010, CSR_MTVAL,     5'd0, 5'd19)); // 23: 0, RO zero (FR-52)
    prog.push_back(enc_csr(3'b010, CSR_MHPMCOUNTER3, 5'd0, 5'd19)); // 24: 0, RO zero
    prog.push_back(enc_csr(3'b010, CSR_MISA,      5'd0, 5'd19)); // 25: the built configuration (FR-37)

    // ---- 2d. instret before any counter write (FR-49) --------------------
    // Read FIRST, while `minstret` still holds the architectural retire count:
    // the model predicts commit_count - 1 exactly, and the traps of part 3 are
    // excluded because a trapping instruction never retires.
    expect_index(prog.size(), IDX_GROUPS, "the first counter read");
    prog.push_back(enc_csr(3'b010, CSR_INSTRET,   5'd0,  5'd19));// 26: retired so far

    // ---- 2e. A write to mtval is accepted and ignored, and does NOT trap --
    // x24 is a NON-x0 register holding ZERO, for the last trap site of part 3.
    prog.push_back(enc_addi(5'd24, 5'd0, 12'd0));               // 27: x24 = 0
    prog.push_back(enc_csr(3'b001, CSR_MTVAL,     5'd16, 5'd0)); // 28: write, no trap (FR-52)
    prog.push_back(enc_csr(3'b010, CSR_MTVAL,     5'd0,  5'd19));// 29: still 0

    // ---- 3. Seven traps back to back (FR-22, FR-24, FR-25, FR-50) --------
    // The instruction at mepc + 4 of each site is the NEXT site, so the
    // handler's return is exercised seven times and a core that loses the flush
    // discards or executes the wrong instruction here.
    expect_index(prog.size(), IDX_TRAPS, "the first trap site");
    prog.push_back(ECALL);                                       // 30: cause 11
    prog.push_back(EBREAK);                                      // 31: cause 3
    prog.push_back(ILLEGAL_WORD);                                // 32: cause 2, unallocated
    prog.push_back(enc_csr(3'b010, CSR_MEDELEG, 5'd0, 5'd19));    // 33: cause 2, absent address
    prog.push_back(enc_csr(3'b010, CSR_MHARTID, 5'd16, 5'd19));   // 34: cause 2, write to RO
    prog.push_back(enc_csr(3'b010, CSR_TIME,    5'd16, 5'd19));   // 35: cause 2, write to a RO view
    // The write-suppression clause of vol. I (Zicsr), on the DUT: the source is
    // x24, a non-x0 specifier holding zero, so the instruction WRITES and a
    // read-only destination must still trap. `src != 0` would let it retire.
    prog.push_back(enc_csr(3'b010, CSR_MHARTID, 5'd24, 5'd19));   // 36: cause 2, zero-valued rs1

    // ---- 3b. After the traps: instret, mcause and mepc (FR-23, FR-49) -----
    prog.push_back(enc_csr(3'b010, CSR_INSTRET, 5'd0, 5'd23));   // 37
    prog.push_back(enc_csr(3'b010, CSR_MCAUSE,  5'd0, 5'd23));   // 38: cause of the last trap
    prog.push_back(enc_csr(3'b010, CSR_MEPC,    5'd0, 5'd23));   // 39: pc of the last trapping instruction

    // ---- 4. The counter aliases (FR-50; vol. II §2.1.1.10) ----------------
    // THE CLAIM: `cycleh` and `instreth` are views of the machine counters, so
    // a `csrrw` to `mcycleh`/`minstreth` changes what they read. A core that
    // keeps `cycle` in its own register reads the run's cycle count here, which
    // is zero in the high half.
    prog.push_back(enc_csr(3'b001, CSR_MCYCLEH,   5'd6,  5'd0)); // 40: mcycleh <- 0x12345678
    prog.push_back(enc_csr(3'b010, CSR_CYCLEH,    5'd0,  5'd19));// 41: must read 0x12345678
    prog.push_back(enc_csr(3'b010, CSR_MCYCLEH,   5'd0,  5'd19));// 42: the machine counter itself
    prog.push_back(enc_csr(3'b001, CSR_MINSTRETH, 5'd6,  5'd0)); // 43: minstreth <- 0x12345678
    prog.push_back(enc_csr(3'b010, CSR_INSTRETH,  5'd0,  5'd19));// 44: must read 0x12345678
    prog.push_back(enc_csr(3'b010, CSR_MINSTRETH, 5'd0,  5'd19));// 45: the machine counter itself
    // The LOW halves are written with 0xFFFF_FFFF: the next increment carries
    // into the high half exactly once, so the alias must read 0x12345679. This
    // proves the write reached the shared counter without the model ever having
    // to count a clock -- and a separate `cycle` register reads zero instead.
    prog.push_back(enc_addi(5'd16, 5'd0, 12'hFFF));              // 46: x16 = 0xFFFFFFFF
    prog.push_back(enc_csr(3'b001, CSR_MCYCLE,    5'd16, 5'd0)); // 47: mcycle <- 0xFFFF_FFFF
    prog.push_back(enc_csr(3'b010, CSR_CYCLEH,    5'd0,  5'd19));// 48: must read 0x12345679
    prog.push_back(enc_csr(3'b010, CSR_MCYCLEH,   5'd0,  5'd19));// 49: the same counter, same value
    prog.push_back(enc_csr(3'b010, CSR_CYCLE,     5'd0,  5'd19));// 50: 0xC00 itself, not comparable
    prog.push_back(enc_csr(3'b001, CSR_MINSTRET,  5'd16, 5'd0)); // 51: minstret <- 0xFFFF_FFFF
    prog.push_back(enc_csr(3'b010, CSR_INSTRETH,  5'd0,  5'd19));// 52: must read 0x12345679
    prog.push_back(enc_csr(3'b010, CSR_MINSTRETH, 5'd0,  5'd19));// 53: the same counter, same value
    prog.push_back(enc_csr(3'b010, CSR_INSTRET,   5'd0,  5'd19));// 54: after the write, not comparable
    // `time`/`timeh` stay the `mtime` view (FR-49): unchanged by all of this.
    prog.push_back(enc_csr(3'b010, CSR_TIME,      5'd0,  5'd19));// 55: mtime[31:0] (D13)
    prog.push_back(enc_csr(3'b010, CSR_TIMEH,     5'd0,  5'd19));// 56: mtime[63:32]

    expect_index(prog.size(), IDX_SKIP, "the JAL over the handler");
    prog.push_back(enc_jal(5'd0, (IDX_TAIL - IDX_SKIP) * 4));    // 57: skip the handler

    // Filler so the handler starts at +0x200: a vector nothing else in the
    // program uses, so "the core jumped to mtvec" is visible in the stream.
    expect_index(prog.size(), IDX_SKIP + 1, "the filler before the handler");
    while (prog.size() < IDX_HANDLER) prog.push_back(NOP);       // 58..127

    // ---- 5. The handler (FR-23, FR-29) -----------------------------------
    expect_index(prog.size(), IDX_HANDLER, "the handler");
    prog.push_back(enc_csr(3'b010, CSR_MEPC,   5'd0, 5'd20));    // 128: x20 <- mepc
    prog.push_back(enc_csr(3'b010, CSR_MCAUSE, 5'd0, 5'd21));    // 129: x21 <- mcause
    prog.push_back(enc_addi(5'd22, 5'd20, 12'd4));               // 130: x22 = mepc + 4
    prog.push_back(enc_jalr(5'd0, 5'd22, 12'd0));                // 131: return

    expect_index(prog.size(), IDX_TAIL, "the tail");
    while (prog.size() < PROG_WORDS) prog.push_back(NOP);        // 132..143

    // ---- Program item ----------------------------------------------------
    last = prog.size();
    req.instruction_addr = new[last];
    req.instruction_list = new[last];
    foreach (prog[i]) begin
      req.instruction_addr[i] = mem_base + i * 4;
      req.instruction_list[i] = prog[i];
    end
    last_pc = req.instruction_addr[last - 1];

    // No data accesses at all: the driver answers fetches only, and an empty
    // declaration is the statement that this program reads and writes no
    // memory. `new[0]` keeps the item's arrays defined.
    req.data_addr = new[0];
    req.data_list = new[0];

    `uvm_info("CSR_SEQ",
      $sformatf("program: %0d instructions at 0x%08h..0x%08h, handler at 0x%08h (mtvec <- AUIPC+%0d), seven traps back to back at 0x%08h..0x%08h, counters written 0x12345678 and 0xFFFF_FFFF",
        last, req.instruction_addr[0], last_pc, mem_base + IDX_HANDLER * 4,
        (IDX_HANDLER - IDX_AUIPC) * 4,
        mem_base + IDX_TRAPS * 4, mem_base + (IDX_TRAPS + 6) * 4),
      UVM_LOW)
    `uvm_info("CSR_SEQ",
      "the defects this program measures: with no CSR file and no trap path the SYSTEM group executes as a no-operation, so every CSR instruction retires writing nothing, ECALL/EBREAK/illegal retire as instructions, and no trap event is ever published; and a core that keeps `cycle` in its own register reads zero through `cycleh` after the program writes `mcycleh`/`mcycle`",
      UVM_LOW)

    start_item(req);
    finish_item(req);
  endtask

endclass

`endif
