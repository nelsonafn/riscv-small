//------------------------------------------------------------------------------
// Trap / retire ordering sequence for riscv_small (WP-14b: FR-22, FR-23, FR-25)
//------------------------------------------------------------------------------
// One claim: within ONE clock cycle the instruction that RETIRES is older than
// the instruction that TRAPS, so a consumer of the two observations must execute
// the commit first. This sequence builds the case that tells the two orders
// apart: a CSR read of `mepc` (and, on a second trap, of `mcause`) sitting three
// instructions before the trap site, so it occupies the WRITE-BACK slot in the
// very cycle the trap is decided in ID.
//
// The program:
//
//   3..8   mepc <- 0xAAAA_A7F0 and mcause <- 0x1234, distinctive pre-trap
//          values that no trap cause can produce by accident;
//   9      csrrs x20, mepc, x0      <- retires in the cycle trap 1 is taken
//  12      ecall                    trap 1: cause 11, mepc = its own address
//  13,14  the handler's pair (mepc = 12's address, mcause = 11)
//  15     mcause <- 0x1234 again, so trap 2 has a distinctive pre-trap value
//  16     csrrs x23, mcause, x0     <- retires in the cycle trap 2 is taken
//  19      ebreak                   trap 2: cause 3, mepc = its own address
//  20,21  the handler's pair (mepc = 19's address, mcause = 3)
//
// Why three instructions: a 5-stage pipeline puts the instruction in ID at
// cycle c in WB at cycle c + 3. A read placed anywhere else does not share the
// trap's cycle and the test would pass on either order.
//
// The oracle is the reference model. It is fed ONLY by the monitor's retire and
// trap streams, and it must execute the commit of the cycle before the trap of
// that same cycle -- that is the ordering this program measures. With the
// publication order reversed, the model applies the trap first and then reads
// `mepc`/`mcause` that the trap has already overwritten: x20 would be predicted
// as the ecall's address instead of 0xAAAA_A7F0, and x23 as 3 instead of 0x1234.
//
// This sequence only builds the program. It judges nothing.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_TRAP_ORDER_SEQ
`define RISCV_SMALL_TRAP_ORDER_SEQ

class riscv_small_trap_order_seq extends uvm_sequence #(riscv_small_transaction);

  `uvm_object_utils(riscv_small_trap_order_seq)

  // CSR addresses (FR-50). Named, never a bare number in an encoding.
  localparam bit [11:0] CSR_MTVEC  = 12'h305;
  localparam bit [11:0] CSR_MEPC   = 12'h341;
  localparam bit [11:0] CSR_MCAUSE = 12'h342;

  // The pre-trap values the co-cycle reads must return. Both are values a trap
  // can never produce: the vector is at +0x200 and the causes are 3 and 11.
  localparam bit [31:0] MEPC_VALUE   = 32'hAAAA_A7F0;
  localparam bit [31:0] MCAUSE_VALUE = 32'h0000_1234;

  // The layout, named so a drift is a fatal and not a wrong program.
  localparam int IDX_COCYCLE_1 = 9;    // the mepc read that shares trap 1's cycle
  localparam int IDX_TRAP_1    = 12;   // ecall
  localparam int IDX_COCYCLE_2 = 16;   // the mcause read that shares trap 2's cycle
  localparam int IDX_TRAP_2    = 19;   // ebreak
  localparam int IDX_SKIP      = 22;   // jal over the handler
  localparam int IDX_HANDLER   = 128;  // 0x200: a vector nothing else uses
  localparam int IDX_TAIL      = 132;
  localparam int PROG_WORDS    = 144;

  localparam bit [31:0] NOP    = 32'h0000_0033; // ADD x0, x0, x0
  localparam bit [31:0] ECALL  = 32'h0000_0073;
  localparam bit [31:0] EBREAK = 32'h0010_0073;

  protected bit [31:0] mem_base;

  // The address of the program's last instruction: the scoreboard's `done`.
  bit [31:0] last_pc;

  function new (string name = "riscv_small_trap_order_seq");
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

  function automatic bit [31:0] enc_csr(bit [2:0] funct3, bit [11:0] csr,
                                        bit [4:0] rs1, bit [4:0] rd);
    return {csr, rs1, funct3, rd, 7'b1110011};
  endfunction

  function void expect_index(int unsigned size, int unsigned want, string what);
    if (size != want)
      `uvm_fatal("TRAP_ORDER_SEQ",
        $sformatf("program layout drifted: %s sits at index %0d, expected %0d; the JAL offsets, the mtvec value and the co-cycle pairs are stale",
          what, size, want))
  endfunction

  virtual task body();
    bit [31:0] prog[$];
    int        last;

    mem_base = riscv_small_seq_mem_base(m_sequencer);
    req = riscv_small_transaction::type_id::create("req");

    // ---- The vector (FR-29) ----------------------------------------------
    prog.push_back(enc_auipc(5'd18, 20'h0));                     // 0
    prog.push_back(enc_addi(5'd18, 5'd18, 12'(IDX_HANDLER * 4)));// 1: x18 = handler
    prog.push_back(enc_csr(3'b001, CSR_MTVEC, 5'd18, 5'd0));      // 2: mtvec <- x18

    // ---- The pre-trap state the co-cycle reads must return ---------------
    prog.push_back(enc_lui(5'd6, MEPC_VALUE[31:12]));            // 3: x6 = 0xAAAA_A000
    prog.push_back(enc_addi(5'd6, 5'd6, 12'(MEPC_VALUE[11:0]))); // 4: x6 = 0xAAAA_A7F0
    prog.push_back(enc_csr(3'b001, CSR_MEPC, 5'd6, 5'd0));       // 5: mepc <- x6
    prog.push_back(enc_lui(5'd7, MCAUSE_VALUE[31:12]));          // 6: x7 = 0x1000
    prog.push_back(enc_addi(5'd7, 5'd7, 12'(MCAUSE_VALUE[11:0])));// 7: x7 = 0x1234
    prog.push_back(enc_csr(3'b001, CSR_MCAUSE, 5'd7, 5'd0));      // 8: mcause <- x7

    // ---- Trap 1, with its co-cycle commit ---------------------------------
    expect_index(prog.size(), IDX_COCYCLE_1, "the mepc read of trap 1");
    prog.push_back(enc_csr(3'b010, CSR_MEPC, 5'd0, 5'd20));       // 9: reads 0xAAAA_A7F0
    prog.push_back(NOP);                                          // 10
    prog.push_back(NOP);                                          // 11
    expect_index(prog.size(), IDX_TRAP_1, "trap 1 (ecall)");
    prog.push_back(ECALL);                                        // 12: cause 11
    prog.push_back(enc_csr(3'b010, CSR_MEPC, 5'd0, 5'd21));       // 13: addr(12)
    prog.push_back(enc_csr(3'b010, CSR_MCAUSE, 5'd0, 5'd22));     // 14: 11

    // ---- Trap 2, with a co-cycle mcause read ------------------------------
    prog.push_back(enc_csr(3'b001, CSR_MCAUSE, 5'd7, 5'd0));      // 15: mcause <- 0x1234
    expect_index(prog.size(), IDX_COCYCLE_2, "the mcause read of trap 2");
    prog.push_back(enc_csr(3'b010, CSR_MCAUSE, 5'd0, 5'd23));     // 16: reads 0x0000_1234
    prog.push_back(NOP);                                          // 17
    prog.push_back(NOP);                                          // 18
    expect_index(prog.size(), IDX_TRAP_2, "trap 2 (ebreak)");
    prog.push_back(EBREAK);                                       // 19: cause 3
    prog.push_back(enc_csr(3'b010, CSR_MEPC, 5'd0, 5'd24));       // 20: addr(19)
    prog.push_back(enc_csr(3'b010, CSR_MCAUSE, 5'd0, 5'd25));     // 21: 3

    expect_index(prog.size(), IDX_SKIP, "the JAL over the handler");
    prog.push_back(enc_jal(5'd0, (IDX_TAIL - IDX_SKIP) * 4));      // 22: skip the handler

    expect_index(prog.size(), IDX_SKIP + 1, "the filler before the handler");
    while (prog.size() < IDX_HANDLER) prog.push_back(NOP);         // 23..127

    // ---- The handler (FR-23, FR-29) --------------------------------------
    expect_index(prog.size(), IDX_HANDLER, "the handler");
    prog.push_back(enc_csr(3'b010, CSR_MEPC, 5'd0, 5'd26));       // 128
    prog.push_back(enc_csr(3'b010, CSR_MCAUSE, 5'd0, 5'd27));     // 129
    prog.push_back(enc_addi(5'd28, 5'd26, 12'd4));                // 130: mepc + 4
    prog.push_back(enc_jalr(5'd0, 5'd28, 12'd0));                 // 131: return

    expect_index(prog.size(), IDX_TAIL, "the tail");
    while (prog.size() < PROG_WORDS) prog.push_back(NOP);          // 132..143

    // ---- Program item ----------------------------------------------------
    last = prog.size();
    req.instruction_addr = new[last];
    req.instruction_list = new[last];
    foreach (prog[i]) begin
      req.instruction_addr[i] = mem_base + i * 4;
      req.instruction_list[i] = prog[i];
    end
    last_pc = req.instruction_addr[last - 1];

    // No data memory: every operand is an immediate, so this program never
    // reaches the data port and the claim is the CSR/trap ordering alone.
    req.data_addr = new[0];
    req.data_list = new[0];

    `uvm_info("TRAP_ORDER_SEQ",
      $sformatf("program: %0d instructions at 0x%08h..0x%08h, handler at 0x%08h, trap 1 at 0x%08h with the mepc read at 0x%08h in WB, trap 2 at 0x%08h with the mcause read at 0x%08h in WB; pre-trap mepc=0x%08h mcause=0x%08h",
        last, req.instruction_addr[0], last_pc, mem_base + IDX_HANDLER * 4,
        mem_base + IDX_TRAP_1 * 4, mem_base + IDX_COCYCLE_1 * 4,
        mem_base + IDX_TRAP_2 * 4, mem_base + IDX_COCYCLE_2 * 4,
        MEPC_VALUE, MCAUSE_VALUE),
      UVM_LOW)
    `uvm_info("TRAP_ORDER_SEQ",
      "the defect this program measures: a model that applies the trap before the commit of the same cycle predicts the POST-trap mepc/mcause for the two co-cycle reads, so x20 reads the ecall's address where 0xAAAA_A7F0 was written and x23 reads 3 where 0x1234 was written",
      UVM_LOW)

    start_item(req);
    finish_item(req);
  endtask

endclass

`endif
