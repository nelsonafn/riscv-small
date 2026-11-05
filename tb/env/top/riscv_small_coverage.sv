`ifndef RISCV_SMALL_COVERAGE
`define RISCV_SMALL_COVERAGE

// ============================================================================
// riscv_small_coverage
//
// Functional coverage collector. It subscribes to the MONITOR, so every sample
// is something the DUT actually did, never something the reference model
// predicted. Bins are named after the requirement they can prove:
//
//   cp_width          FR-09/FR-10/FR-11/FR-12: word, halfword and byte traffic
//   cp_lane           FR-11/FR-12: the byte lane selected by addr[1:0]
//   cp_dir            both directions on the data port
//   cp_subword_lane   FR-12: a lane other than 0 is reached by a sub-word access
//   cp_inst           NFR-06/A-09: one bin per instruction of doc/spec.md §4.1
//
// Author: Nelson Alves nelsonafn@gmail.com
// ============================================================================
class riscv_small_coverage extends uvm_subscriber #(riscv_small_transaction);
  `uvm_component_utils(riscv_small_coverage)

  riscv_small_transaction cov_trans;

  // cg_inst codes: one per instruction that doc/spec.md §4.1 says
  // rtl/instruction_decode.sv decodes today. INST_NONE is the sentinel for a
  // word outside that subset (an opcode with no decode arm, or a funct3 the
  // table does not list): it has no bin, so such a fetch is counted by nothing
  // instead of being folded into a neighbour.
  localparam bit [5:0] INST_LUI   = 6'd0;   // 0110111
  localparam bit [5:0] INST_AUIPC = 6'd1;   // 0010111
  localparam bit [5:0] INST_JAL   = 6'd2;   // 1101111
  localparam bit [5:0] INST_JALR  = 6'd3;   // 1100111
  localparam bit [5:0] INST_BEQ   = 6'd4;   // 1100011, funct3 000
  localparam bit [5:0] INST_BNE   = 6'd5;   // 1100011, funct3 001
  localparam bit [5:0] INST_BLT   = 6'd6;   // 1100011, funct3 100
  localparam bit [5:0] INST_BGE   = 6'd7;   // 1100011, funct3 101
  localparam bit [5:0] INST_BLTU  = 6'd8;   // 1100011, funct3 110
  localparam bit [5:0] INST_BGEU  = 6'd9;   // 1100011, funct3 111
  localparam bit [5:0] INST_LB    = 6'd10;  // 0000011, funct3 000
  localparam bit [5:0] INST_LH    = 6'd11;  // 0000011, funct3 001
  localparam bit [5:0] INST_LW    = 6'd12;  // 0000011, funct3 010
  localparam bit [5:0] INST_LBU   = 6'd13;  // 0000011, funct3 100
  localparam bit [5:0] INST_LHU   = 6'd14;  // 0000011, funct3 101
  localparam bit [5:0] INST_SB    = 6'd15;  // 0100011, funct3 000
  localparam bit [5:0] INST_SH    = 6'd16;  // 0100011, funct3 001
  localparam bit [5:0] INST_SW    = 6'd17;  // 0100011, funct3 010
  localparam bit [5:0] INST_ADDI  = 6'd18;  // 0010011, funct3 000
  localparam bit [5:0] INST_SLLI  = 6'd19;  // 0010011, funct3 001
  localparam bit [5:0] INST_SLTI  = 6'd20;  // 0010011, funct3 010
  localparam bit [5:0] INST_SLTIU = 6'd21;  // 0010011, funct3 011
  localparam bit [5:0] INST_XORI  = 6'd22;  // 0010011, funct3 100
  localparam bit [5:0] INST_SRLI  = 6'd23;  // 0010011, funct3 101, inst[30] = 0
  localparam bit [5:0] INST_SRAI  = 6'd24;  // 0010011, funct3 101, inst[30] = 1
  localparam bit [5:0] INST_ORI   = 6'd25;  // 0010011, funct3 110
  localparam bit [5:0] INST_ANDI  = 6'd26;  // 0010011, funct3 111
  localparam bit [5:0] INST_ADD   = 6'd27;  // 0110011, funct3 000, inst[30] = 0
  localparam bit [5:0] INST_SUB   = 6'd28;  // 0110011, funct3 000, inst[30] = 1
  localparam bit [5:0] INST_SLL   = 6'd29;  // 0110011, funct3 001
  localparam bit [5:0] INST_SLT   = 6'd30;  // 0110011, funct3 010
  localparam bit [5:0] INST_SLTU  = 6'd31;  // 0110011, funct3 011
  localparam bit [5:0] INST_XOR   = 6'd32;  // 0110011, funct3 100
  localparam bit [5:0] INST_SRL   = 6'd33;  // 0110011, funct3 101, inst[30] = 0
  localparam bit [5:0] INST_SRA   = 6'd34;  // 0110011, funct3 101, inst[30] = 1
  localparam bit [5:0] INST_OR    = 6'd35;  // 0110011, funct3 110
  localparam bit [5:0] INST_AND   = 6'd36;  // 0110011, funct3 111
  localparam bit [5:0] INST_NONE  = 6'h3f;  // not in §4.1: no bin

  // Local decoder: opcode + funct3 + bit 30 of the fetched word, the same
  // fields rtl/instruction_decode.sv examines (it looks at funct7[5] only, and
  // only for the shifts and for SUB/SRA). It is observation of the word the
  // monitor published, so it stays inside the collector: no TB package, no
  // monitor change, no reference-model change.
  function bit [5:0] decode_inst(int word);
    bit [6:0] opcode;
    bit [2:0] funct3;
    bit       funct7_b5;

    opcode    = word[6:0];
    funct3    = word[14:12];
    funct7_b5 = word[30];

    case (opcode)
      7'b0110111: return INST_LUI;
      7'b0010111: return INST_AUIPC;
      7'b1101111: return INST_JAL;
      7'b1100111: return INST_JALR;
      7'b1100011: begin
        case (funct3)
          3'b000: return INST_BEQ;
          3'b001: return INST_BNE;
          3'b100: return INST_BLT;
          3'b101: return INST_BGE;
          3'b110: return INST_BLTU;
          3'b111: return INST_BGEU;
          default: return INST_NONE;   // 010, 011: not accepted by §4.1
        endcase
      end
      7'b0000011: begin
        case (funct3)
          3'b000: return INST_LB;
          3'b001: return INST_LH;
          3'b010: return INST_LW;
          3'b100: return INST_LBU;
          3'b101: return INST_LHU;
          default: return INST_NONE;   // 011, 110, 111: not accepted by §4.1
        endcase
      end
      7'b0100011: begin
        case (funct3)
          3'b000: return INST_SB;
          3'b001: return INST_SH;
          3'b010: return INST_SW;
          default: return INST_NONE;   // 011..111: not accepted by §4.1
        endcase
      end
      7'b0010011: begin
        case (funct3)
          3'b000: return INST_ADDI;
          3'b001: return INST_SLLI;
          3'b010: return INST_SLTI;
          3'b011: return INST_SLTIU;
          3'b100: return INST_XORI;
          3'b101: return funct7_b5 ? INST_SRAI : INST_SRLI;
          3'b110: return INST_ORI;
          default: return INST_ANDI;
        endcase
      end
      7'b0110011: begin
        case (funct3)
          3'b000: return funct7_b5 ? INST_SUB : INST_ADD;
          3'b001: return INST_SLL;
          3'b010: return INST_SLT;
          3'b011: return INST_SLTU;
          3'b100: return INST_XOR;
          3'b101: return funct7_b5 ? INST_SRA : INST_SRL;
          3'b110: return INST_OR;
          default: return INST_AND;
        endcase
      end
      // 0001111 (FENCE/FENCE.I), 1110011 (ECALL/EBREAK/CSR*) and every opcode
      // without a decode arm: no-op in the RTL, and no bin here.
      default: return INST_NONE;
    endcase
  endfunction: decode_inst

  covergroup cg_mem with function sample(bit [1:0] width, bit [1:0] lane, bit is_write);
    option.per_instance = 1;

    cp_width: coverpoint width {
      bins byte_w = {2'b00};
      bins half_w = {2'b01};
      bins word_w = {2'b10};
    }

    cp_lane: coverpoint lane {
      bins lane0 = {2'b00};
      bins lane1 = {2'b01};
      bins lane2 = {2'b10};
      bins lane3 = {2'b11};
    }

    cp_dir: coverpoint is_write {
      bins read  = {1'b0};
      bins write = {1'b1};
    }

    // A word access is naturally aligned, so only sub-word accesses can reach
    // lanes 1-3. Sampling this one guarded keeps the word cases out of it
    // without ignoring any legal combination.
    cp_subword_lane: coverpoint lane iff (width != 2'b10) {
      bins lane0 = {2'b00};
      bins lane1 = {2'b01};
      bins lane2 = {2'b10};
      bins lane3 = {2'b11};
    }
  endgroup: cg_mem

  // What a cp_inst bin proves: the instruction class reached IF/ID, i.e. the
  // core accepted a fetch of that encoding. What it does not prove:
  // retirement -- `if_id_flush` (rtl/control.sv:246-258) can discard a fetch
  // the monitor has already published, so a bin can be hit by an instruction
  // the core never executed. The missing retire observation is gap G-28,
  // owned by E3.
  //
  // One explicit bin per code, no auto-bins: INST_NONE is outside every bin,
  // so it is counted by nothing.
  //
  // `and`, `or` and `xor` are SystemVerilog reserved words, so those three bins
  // carry a trailing underscore (`and_`, `or_`, `xor_`); they are the only
  // names that differ from the §4.1 mnemonic. An escaped identifier (`\and`)
  // keeps the exact spelling but xcrg prints the backslash, and the collector
  // publishes bin names verbatim into summary.json, which a bare `\` makes
  // invalid JSON.
  covergroup cg_inst with function sample(bit [5:0] inst_code);
    option.per_instance = 1;

    cp_inst: coverpoint inst_code {
      bins lui   = {INST_LUI};
      bins auipc = {INST_AUIPC};
      bins jal   = {INST_JAL};
      bins jalr  = {INST_JALR};
      bins beq   = {INST_BEQ};
      bins bne   = {INST_BNE};
      bins blt   = {INST_BLT};
      bins bge   = {INST_BGE};
      bins bltu  = {INST_BLTU};
      bins bgeu  = {INST_BGEU};
      bins lb    = {INST_LB};
      bins lh    = {INST_LH};
      bins lw    = {INST_LW};
      bins lbu   = {INST_LBU};
      bins lhu   = {INST_LHU};
      bins sb    = {INST_SB};
      bins sh    = {INST_SH};
      bins sw    = {INST_SW};
      bins addi  = {INST_ADDI};
      bins slli  = {INST_SLLI};
      bins slti  = {INST_SLTI};
      bins sltiu = {INST_SLTIU};
      bins xori  = {INST_XORI};
      bins srli  = {INST_SRLI};
      bins srai  = {INST_SRAI};
      bins ori   = {INST_ORI};
      bins andi  = {INST_ANDI};
      bins add   = {INST_ADD};
      bins sub   = {INST_SUB};
      bins sll   = {INST_SLL};
      bins slt   = {INST_SLT};
      bins sltu  = {INST_SLTU};
      bins xor_  = {INST_XOR};
      bins srl   = {INST_SRL};
      bins sra   = {INST_SRA};
      bins or_   = {INST_OR};
      bins and_  = {INST_AND};
    }
  endgroup: cg_inst

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_mem = new();
    cg_inst = new();
  endfunction: new

  function void write(riscv_small_transaction t);
    // Fetch transactions share the analysis port but not the memory covergroup:
    // sampling them would leave lane/direction bins that no data access made.
    // They feed cg_inst instead, through the local decoder.
    if (t.op_is_inst) begin
      cg_inst.sample(decode_inst(t.captured_inst_data));
      return;
    end
    $cast(cov_trans, t);
    cg_mem.sample(cov_trans.captured_data_wr_ctrl[1:0],
                  cov_trans.captured_data_addr[1:0],
                  cov_trans.op_is_data_write);
  endfunction: write

endclass: riscv_small_coverage

`endif
