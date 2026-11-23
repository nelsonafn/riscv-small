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
//   cp_beat           FR-42/G-22: both beats of a crossing (split) access were
//                     observed on the bus; a non-split access has no bin
//   cp_inst           NFR-06/A-09: one bin per instruction of doc/spec.md §4.1
//   cp_csr_op         FR-47: the six Zicsr instructions were EXECUTED (sampled on
//                     the retire and trap streams, never on a fetch)
//   cp_csr_group      FR-50: each of the five address groups was accessed
//   cp_trap_cause     FR-24/FR-25: cause 2 illegal, 3 breakpoint, 11 ECALL
//
// The CSR coverpoints sample the RETIRE and TRAP streams, not the fetch stream:
// a fetched `CSRRW` proves the decoder saw the encoding, an executed one proves
// the instruction reached write-back (or trapped). The fetch stream cannot tell
// the two, and `cg_inst` already covers it.
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

  // What a cp_beat bin proves (FR-42/G-22, WP-13): the monitor published a beat
  // that belongs to an access the core split into two word-aligned beats. What
  // it does not prove: that the two beats were consistent with each other --
  // that is riscv_small_strb_checker's claim -- so this coverpoint exists to
  // make the coverage report able to say the split was MEASURED, not merely
  // checked. `split_beat1` and `split_beat2` must both be hit for that claim:
  // one bin alone says the core issued one half.
  //
  // `iff (beats == 2)` is what keeps the non-split case out. `captured_data_beat`
  // is 1 for a non-split access too, so a bin on beat 1 without the guard would
  // be hit by every ordinary access and would prove nothing about the split.
  // There is deliberately no bin for `beats == 1` (see cp_subword_lane for the
  // same guards-are-not-bins rule). The width is not a bin: a split SH and a
  // split SW differ only in the spill arithmetic the strb checker already pins
  // per width, and `cp_width` already proves both widths were measured.
  covergroup cg_beat with function sample(int unsigned beat, int unsigned beats);
    option.per_instance = 1;

    cp_beat: coverpoint beat iff (beats == 2) {
      bins split_beat1 = {1};
      bins split_beat2 = {2};
    }
  endgroup: cg_beat

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

  // ---------------------------------------------------------------------------
  // WP-14: CSR and trap coverage (FR-47, FR-50, FR-24, FR-25)
  // ---------------------------------------------------------------------------
  // What a cp_csr_op bin proves: the core EXECUTED that Zicsr instruction --
  // the retire stream carried it, or the trap stream did. What it does not
  // prove: that the read-modify-write semantics were right (the scoreboard's
  // claim). `csrr*` is decoded from the instruction word the monitor published,
  // so a fetch of the encoding cannot hit a bin: `cg_inst` already covers the
  // decoder seeing it.
  //
  // What a cp_csr_group bin proves: the machine-mode address map of FR-50 was
  // actually reached, group by group, including an address the configuration
  // does not implement. The classification is by ADDRESS, never by outcome, so
  // an implemented trap/status address and the unimplemented `medeleg` (0x302)
  // that lives in the same 0x300 window land in different bins.
  localparam bit [2:0] CSR_OP_NONE   = 3'd6;
  localparam bit [2:0] CSR_GRP_TSTATUS = 3'd0; // trap and status   0x300..0x344
  localparam bit [2:0] CSR_GRP_COUNTER = 3'd1; // counters          0xB00/0xC00
  localparam bit [2:0] CSR_GRP_ID      = 3'd2; // identification    0xF11..0xF15
  localparam bit [2:0] CSR_GRP_PERF    = 3'd3; // performance       0xB03../0x323..
  localparam bit [2:0] CSR_GRP_ILLEGAL = 3'd4; // anything else: not implemented

  function bit is_csr_access(int word);
    return (word[6:0] == 7'b1110011) && (word[14:12] != 3'b000);
  endfunction

  // CSRRW=0 CSRRS=1 CSRRC=2 CSRRWI=3 CSRRSI=4 CSRRCI=5, CSR_OP_NONE otherwise.
  function bit [2:0] csr_op_code(int word);
    if (!is_csr_access(word)) return CSR_OP_NONE;
    case (word[14:12])
      3'b001: return 3'd0; // CSRRW
      3'b010: return 3'd1; // CSRRS
      3'b011: return 3'd2; // CSRRC
      3'b101: return 3'd3; // CSRRWI
      3'b110: return 3'd4; // CSRRSI
      3'b111: return 3'd5; // CSRRCI
      default: return CSR_OP_NONE;
    endcase
  endfunction

  function bit [2:0] csr_group_code(int addr);
    case (addr)
      12'h300, 12'h301, 12'h304, 12'h305, 12'h310,
      12'h340, 12'h341, 12'h342, 12'h343, 12'h344: return CSR_GRP_TSTATUS;
      12'hB00, 12'hB02, 12'hB80, 12'hB82,
      12'hC00, 12'hC01, 12'hC02, 12'hC80, 12'hC81, 12'hC82: return CSR_GRP_COUNTER;
      12'hF11, 12'hF12, 12'hF13, 12'hF14, 12'hF15: return CSR_GRP_ID;
      default: begin
        if (addr >= 12'hB03 && addr <= 12'hB1F) return CSR_GRP_PERF;
        if (addr >= 12'h323 && addr <= 12'h33F) return CSR_GRP_PERF;
        return CSR_GRP_ILLEGAL;
      end
    endcase
  endfunction

  // The guards are not bins: `has_csr` keeps an ECALL/EBREAK (a SYSTEM encoding
  // with funct3 = 000) out of cp_csr_op/cp_csr_group, and `has_cause` keeps a
  // retire out of cp_trap_cause. A guard that silently folded the two would
  // make an ECALL look like a CSR access to address 0x000.
  covergroup cg_csr with function sample(bit [2:0] csr_op, bit [2:0] csr_grp,
                                         bit has_csr, int cause, bit has_cause);
    option.per_instance = 1;

    cp_csr_op: coverpoint csr_op iff (has_csr) {
      bins csrrw  = {3'd0};
      bins csrrs  = {3'd1};
      bins csrrc  = {3'd2};
      bins csrrwi = {3'd3};
      bins csrrsi = {3'd4};
      bins csrrci = {3'd5};
    }

    cp_csr_group: coverpoint csr_grp iff (has_csr) {
      bins trap_status  = {CSR_GRP_TSTATUS};
      bins counters     = {CSR_GRP_COUNTER};
      bins identification = {CSR_GRP_ID};
      bins performance  = {CSR_GRP_PERF};
      bins illegal      = {CSR_GRP_ILLEGAL};
    }

    cp_trap_cause: coverpoint cause iff (has_cause) {
      bins illegal_instruction = {2};
      bins breakpoint          = {3};
      bins ecall_m             = {11};
    }
  endgroup: cg_csr

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_mem = new();
    cg_beat = new();
    cg_inst = new();
    cg_csr = new();
  endfunction: new

  function void write(riscv_small_transaction t);
    // Trap events (WP-14): the cause and, when the trapping instruction is a
    // CSR access, its opcode and address group. A trapped instruction never
    // reaches the retire stream, so this is the only place those bins can be
    // sampled for it.
    if (t.op_is_trap) begin
      cg_csr.sample(csr_op_code(t.trap_inst),
                    csr_group_code(t.trap_inst[31:20]),
                    is_csr_access(t.trap_inst),
                    int'(t.trap_cause),
                    1'b1);
      return;
    end
    // Retire (commit) events: a CSR instruction the core EXECUTED. Retire
    // events carry no data-port fields, so they never feed cg_mem.
    if (t.op_is_retire) begin
      cg_csr.sample(csr_op_code(t.retire_inst),
                    csr_group_code(t.retire_inst[31:20]),
                    is_csr_access(t.retire_inst),
                    0,
                    1'b0);
      return;
    end
    // Fetch transactions share the analysis port but not the memory covergroup:
    // sampling them would leave lane/direction bins that no data access made.
    // They feed cg_inst instead, through the local decoder. An orphan response
    // is not a fetch -- no request produced it -- so it samples nothing.
    if (t.op_is_inst) begin
      if (t.captured_inst_orphan) return;
      cg_inst.sample(decode_inst(t.captured_inst_data));
      return;
    end
    $cast(cov_trans, t);
    cg_mem.sample(cov_trans.captured_data_wr_ctrl[1:0],
                  cov_trans.captured_data_addr[1:0],
                  cov_trans.op_is_data_write);
    // The split-beat coverpoint samples the same published beat: beat 1/2 of a
    // crossing access, and nothing when the access was not split.
    cg_beat.sample(cov_trans.captured_data_beat,
                   cov_trans.captured_data_beats);
  endfunction: write

endclass: riscv_small_coverage

`endif
