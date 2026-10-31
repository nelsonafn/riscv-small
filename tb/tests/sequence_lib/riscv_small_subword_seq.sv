//------------------------------------------------------------------------------
// Sub-word load sequence for riscv_small
//------------------------------------------------------------------------------
// Drives the four sub-word load forms (LB, LBU, LH, LHU) at every byte offset
// of one word, then stores each loaded register with SW so the value crosses
// the data port and the scoreboard can compare it against the reference model.
//
// The word 0x7DCC9BAA is chosen so that every case is distinguishable:
//   byte 0 = 0xAA (bit 7 set), byte 1 = 0x9B (bit 7 set),
//   byte 2 = 0xCC (bit 7 set), byte 3 = 0x7D (bit 7 clear),
//   half 0 = 0x9BAA (bit 15 set), half 1 = 0x7DCC (bit 15 clear).
// A load that ignores the low address bits therefore produces a different
// value for every offset except 0, and offset 0 stays as the control.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : October 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_SUBWORD_SEQ
`define RISCV_SMALL_SUBWORD_SEQ

class riscv_small_subword_seq extends uvm_sequence #(riscv_small_transaction);

  `uvm_object_utils(riscv_small_subword_seq)

  // Source word and store destinations. Both must fit the signed 12-bit
  // immediate of the I/S formats.
  localparam int SRC_WORD = 'h400;
  localparam int DST_BASE = 'h700;
  localparam int WORD_VALUE = 'h7DCC_9BAA;

  // NOPs between a load and the store that consumes it: enough to drain the
  // pipeline so this test measures lane selection and not the hazard logic.
  localparam int BUBBLE = 5;
  localparam int TAIL   = 5;

  localparam int N_CASES = 12;

  function new (string name = "riscv_small_subword_seq");
    super.new(name);
  endfunction

  // I-type load: imm[11:0] | rs1 | funct3 | rd | opcode 0000011
  function automatic bit [31:0] enc_load(bit [2:0] f3, bit [4:0] rd, bit [11:0] imm);
    return {imm, 5'd0, f3, rd, 7'b0000011};
  endfunction

  // S-type store word: imm[11:5] | rs2 | rs1 | funct3 010 | imm[4:0] | opcode 0100011
  function automatic bit [31:0] enc_sw(bit [4:0] rs2, bit [11:0] imm);
    return {imm[11:5], rs2, 5'd0, 3'b010, imm[4:0], 7'b0100011};
  endfunction

  virtual task body();
    bit [2:0] f3[12];
    int       off[12];
    int       idx;
    int       last;

    // 4x LB, 4x LBU, 2x LH, 2x LHU
    f3  = '{3'b000, 3'b000, 3'b000, 3'b000,
            3'b100, 3'b100, 3'b100, 3'b100,
            3'b001, 3'b001,
            3'b101, 3'b101};
    off = '{0, 1, 2, 3,
            0, 1, 2, 3,
            0, 2,
            0, 2};

    req = riscv_small_transaction::type_id::create("req");

    last = N_CASES * (1 + BUBBLE + 1);
    req.instruction_addr = new[last + TAIL];
    req.instruction_list = new[last + TAIL];

    // Source word at every byte address it can be addressed with, plus one
    // destination word per case.
    req.data_addr = new[4 + N_CASES];
    req.data_list = new[4 + N_CASES];
    for (int i = 0; i < 4; i++) begin
      req.data_addr[i] = SRC_WORD + i;
      req.data_list[i] = WORD_VALUE;
    end
    for (int k = 0; k < N_CASES; k++) begin
      req.data_addr[4 + k] = DST_BASE + 4 * k;
      req.data_list[4 + k] = 'x;
    end

    idx = 0;
    for (int k = 0; k < N_CASES; k++) begin
      bit [4:0] rd  = 5'(10 + k);            // x10..x21, never x0
      bit [11:0] la = 12'(SRC_WORD + off[k]);
      bit [11:0] sa = 12'(DST_BASE + 4 * k);

      req.instruction_addr[idx] = idx * 4;
      req.instruction_list[idx] = enc_load(f3[k], rd, la);
      `uvm_info("SUBWORD",
        $sformatf("LOAD %s x%0d, 'h%0h(x0)  ->  SW x%0d, 'h%0h(x0)",
          load_name(f3[k]), rd, la, rd, sa), UVM_LOW)
      idx++;

      for (int b = 0; b < BUBBLE; b++) begin
        req.instruction_addr[idx] = idx * 4;
        req.instruction_list[idx] = 32'h00000033; // NOP: ADD x0, x0, x0
        idx++;
      end

      req.instruction_addr[idx] = idx * 4;
      req.instruction_list[idx] = enc_sw(rd, sa);
      idx++;
    end

    for (int i = 0; i < TAIL; i++) begin
      req.instruction_addr[idx] = idx * 4;
      req.instruction_list[idx] = 32'h00000033;
      idx++;
    end

    // The program item is complete: publish it to the reference model, then
    // hand the same item to the driver.
    publish_program(req);
    start_item(req);
    finish_item(req);
  endtask

  // The reference model receives the program from here, never from the driver.
  function void publish_program(riscv_small_transaction item);
    uvm_analysis_port#(riscv_small_transaction) program_port;
    if (uvm_config_db#(uvm_analysis_port#(riscv_small_transaction))::get(m_sequencer, "", "program_port", program_port))
      program_port.write(item);
    else
      `uvm_warning("PROGRAM_PORT", "no program_port: the reference model will not see this program")
  endfunction

  function automatic string load_name(bit [2:0] f3);
    case (f3)
      3'b000: return "LB ";
      3'b001: return "LH ";
      3'b100: return "LBU";
      3'b101: return "LHU";
      default: return "???";
    endcase
  endfunction

endclass

`endif
