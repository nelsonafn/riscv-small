//------------------------------------------------------------------------------
// External trap request sequence for riscv_small (WP-14b: FR-22, Q-35)
//------------------------------------------------------------------------------
// One claim: the core takes a trap on the platform's synchronous request, the
// reason it reports is the CODE THE PLATFORM PRESENTED on `exception[3:0]`, the
// address it reports is the instruction that was in ID, and the request does not
// have to be standing when the handler reads the pair back.
//
// The stimulus is the pin, and this sequence owns it: `exception_addr` names the
// instruction whose ID slot must be hit, `exception_cause` the code presented
// for exactly that one cycle. The driver times the pin; the monitor observes the
// same wire and publishes it with the trap event, so the model predicts the
// external cause from the observation and never from configuration (D13).
//
// The cause presented is 5 (load access fault, vol. II Table 7), chosen because
// THIS CORE CANNOT PRODUCE IT FROM AN INSTRUCTION: the decoder raises only 2, 3
// and 11. A read of `mcause` that returns 5 therefore cannot be an internal
// cause wearing the same number, and a core that reads a hardwired zero (or the
// stale `mcause` of an earlier trap) fails by value rather than by accident.
//
// The program:
//
//   3..5   mscratch <- 0x1111_1111            the pre-trap marker
//   6,7    x7 = 0x2222                        what the aimed instruction would write
//   8      csrrw x5, mscratch, x7             *** the aimed trap site ***
//   9      csrrs x21, mscratch, x0            must read 0x1111_1111: the trap
//                                             discarded instruction 8 before EX, so
//                                             its CSR write never happened
//  10      csrrs x22, mepc, x0                must read the address of 8
//  11      csrrs x23, mcause, x0              must read 5
//  12      jal to the tail
// 128..131 the handler: read mepc, read mcause, return to mepc + 4
//
// Instruction 8 is a legal Zicsr write on purpose: an internal cause would be a
// decode defect here, and the model would call it spurious. The trap must be the
// platform's. A mis-timed request is not silent either: one cycle early and
// `mepc` names instruction 7 (so the return skips 8 and the marker is never
// destroyed, but x22 disagrees), one cycle late and instruction 8 executes, so
// x21 reads 0x2222 -- both are compared values.
//
// This sequence only builds the program and the schedule. It judges nothing.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_EXTERNAL_TRAP_SEQ
`define RISCV_SMALL_EXTERNAL_TRAP_SEQ

class riscv_small_external_trap_seq extends uvm_sequence #(riscv_small_transaction);

  `uvm_object_utils(riscv_small_external_trap_seq)

  localparam bit [11:0] CSR_MTVEC    = 12'h305;
  localparam bit [11:0] CSR_MSCRATCH = 12'h340;
  localparam bit [11:0] CSR_MEPC     = 12'h341;
  localparam bit [11:0] CSR_MCAUSE   = 12'h342;

  // The marker the aimed instruction would overwrite if it were allowed to
  // execute: 0x1111_1111 before, 0x0000_2222 after.
  localparam bit [31:0] MARKER_VALUE = 32'h1111_1111;
  localparam bit [31:0] STORE_VALUE  = 32'h0000_2222;

  // The code the platform presents. 5 = load access fault (vol. II Table 7); no
  // internal path of this core produces it (only 2, 3 and 11 exist).
  localparam bit [3:0]  EXT_CAUSE = 4'd5;

  localparam int IDX_TRAP_SITE = 8;
  localparam int IDX_SKIP      = 12;
  localparam int IDX_HANDLER   = 128;
  localparam int IDX_TAIL      = 132;
  localparam int PROG_WORDS    = 144;

  localparam bit [31:0] NOP = 32'h0000_0033; // ADD x0, x0, x0

  protected bit [31:0] mem_base;

  bit [31:0] last_pc;

  function new (string name = "riscv_small_external_trap_seq");
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
      `uvm_fatal("EXT_TRAP_SEQ",
        $sformatf("program layout drifted: %s sits at index %0d, expected %0d; the JAL offsets, the mtvec value and the exception schedule are stale",
          what, size, want))
  endfunction

  virtual task body();
    bit [31:0] prog[$];
    int        last;

    mem_base = riscv_small_seq_mem_base(m_sequencer);
    req = riscv_small_transaction::type_id::create("req");

    // ---- The vector -------------------------------------------------------
    prog.push_back(enc_auipc(5'd18, 20'h0));                      // 0
    prog.push_back(enc_addi(5'd18, 5'd18, 12'(IDX_HANDLER * 4))); // 1: x18 = handler
    prog.push_back(enc_csr(3'b001, CSR_MTVEC, 5'd18, 5'd0));      // 2: mtvec <- x18

    // ---- The marker and the aimed instruction ----------------------------
    prog.push_back(enc_lui(5'd6, MARKER_VALUE[31:12]));           // 3: x6 = 0x1111_1000
    prog.push_back(enc_addi(5'd6, 5'd6, 12'(MARKER_VALUE[11:0])));// 4: x6 = 0x1111_1111
    prog.push_back(enc_csr(3'b001, CSR_MSCRATCH, 5'd6, 5'd0));    // 5: mscratch <- x6
    prog.push_back(enc_lui(5'd7, STORE_VALUE[31:12]));            // 6: x7 = 0x2000
    prog.push_back(enc_addi(5'd7, 5'd7, 12'(STORE_VALUE[11:0]))); // 7: x7 = 0x2222
    expect_index(prog.size(), IDX_TRAP_SITE, "the aimed trap site");
    prog.push_back(enc_csr(3'b001, CSR_MSCRATCH, 5'd7, 5'd5));    // 8: *** aimed ***

    // ---- What the trap must leave behind ---------------------------------
    prog.push_back(enc_csr(3'b010, CSR_MSCRATCH, 5'd0, 5'd21));   // 9:  0x1111_1111
    prog.push_back(enc_csr(3'b010, CSR_MEPC,     5'd0, 5'd22));   // 10: addr(8)
    prog.push_back(enc_csr(3'b010, CSR_MCAUSE,   5'd0, 5'd23));   // 11: 5

    expect_index(prog.size(), IDX_SKIP, "the JAL over the handler");
    prog.push_back(enc_jal(5'd0, (IDX_TAIL - IDX_SKIP) * 4));      // 12: skip the handler
    while (prog.size() < IDX_HANDLER) prog.push_back(NOP);         // 13..127

    expect_index(prog.size(), IDX_HANDLER, "the handler");
    prog.push_back(enc_csr(3'b010, CSR_MEPC,   5'd0, 5'd24));      // 128
    prog.push_back(enc_csr(3'b010, CSR_MCAUSE, 5'd0, 5'd25));      // 129
    prog.push_back(enc_addi(5'd26, 5'd24, 12'd4));                 // 130: mepc + 4
    prog.push_back(enc_jalr(5'd0, 5'd26, 12'd0));                  // 131: return

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

    req.data_addr = new[0];
    req.data_list = new[0];

    // ---- The stimulus: one request, one cycle, one instruction -----------
    req.exception_addr  = new[1];
    req.exception_cause = new[1];
    req.exception_addr[0]  = mem_base + IDX_TRAP_SITE * 4;
    req.exception_cause[0] = EXT_CAUSE;

    `uvm_info("EXT_TRAP_SEQ",
      $sformatf("program: %0d instructions at 0x%08h..0x%08h, handler at 0x%08h, exception[3:0] = %0d asserted for one cycle while the instruction at 0x%08h occupies ID (it would otherwise write mscratch = 0x%08h)",
        last, req.instruction_addr[0], last_pc, mem_base + IDX_HANDLER * 4,
        EXT_CAUSE, req.exception_addr[0], STORE_VALUE),
      UVM_LOW)
    `uvm_info("EXT_TRAP_SEQ",
      "the defect this program measures: the pin reaches the DUT only through the interface member, so a testbench top that ties the port to a local constant leaves the request unread -- no trap is observed, mscratch is overwritten by the aimed instruction, and mcause keeps whatever an earlier trap left",
      UVM_LOW)

    start_item(req);
    finish_item(req);
  endtask

endclass

`endif
