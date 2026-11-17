//------------------------------------------------------------------------------
// Reference model: architectural state fed by the monitor's retire events
//------------------------------------------------------------------------------
// The model is an ISS for the load/store subset (G-04): it executes the
// instruction the RETIRE event carries, in its own register file and its own
// data memory, and publishes one store prediction per SW.
//
// What it does NOT receive:
//   - the program (no program feed, no analysis FIFO, no export of its own).
//     Only the monitor feeds it, through `mon_export` (C-16, AGENTS.md
//     responsibility 9).
//   - any transaction from the driver or the sequence.
//
// What it DOES receive as configuration:
//   - riscv_small_program_image, once, for the initial content of its data
//     memory. That is the "initial state" of the machine, not a stream: it is
//     read lazily on the first retire event, because the sequence fills it in
//     run_phase, after every build_phase has run.
//
// Why retire and not fetch: `if_id_flush` discards an instruction the monitor
// already saw accepted, so a fetch-driven model executes what the core never
// retired (G-28). The retire event is self-contained -- it carries the
// instruction word -- so there is no pc -> word table and no fetch pairing to
// get wrong.
//
// Why it runs in a passive agent: there is no run_phase at all. Every
// observation is consumed in the analysis write() function, so the model never
// blocks on a FIFO and never needs a sequencer or a driver to exist.
//
// Author: Nelson Alves nelsonafn@gmail.com
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_REF_MODEL
`define RISCV_SMALL_REF_MODEL

`uvm_analysis_imp_decl(_mon)

class riscv_small_ref_model extends uvm_component;

  `uvm_component_utils(riscv_small_ref_model)

  // ---- TLM ports -----------------------------------------------------------
  // Input: everything the monitor publishes (fetch, data, retire). Only the
  // retire events are executed; the rest are ignored by `write_mon`.
  uvm_analysis_imp_mon #(riscv_small_transaction, riscv_small_ref_model) mon_export;
  // Output: store predictions for the Scoreboard
  uvm_analysis_port #(riscv_small_transaction) rm2sb_port;

  // ---- Configuration (not a transaction) -----------------------------------
  riscv_small_program_image image; // initial data memory, or null

  // ---- Architectural state -------------------------------------------------
  int          reg_file [32];      // x0 is hardwired to zero
  int          iss_mem  [int];     // data memory, indexed by word address
  bit          mem_initialised;    // the image is copied in once
  int unsigned commit_count;       // retire events executed
  int unsigned pred_count;         // SW predictions published

  // ---- Constructor ---------------------------------------------------------
  function new(string name = "riscv_small_ref_model", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build phase ---------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon_export = new("mon_export", this);
    rm2sb_port = new("rm2sb_port", this);
    if (!uvm_config_db#(riscv_small_program_image)::get(this, "", "program_image", image))
      image = null;
    clear_state();
  endfunction

  function void clear_state();
    for (int i = 0; i < 32; i++) reg_file[i] = 0; // x0 is always zero
    iss_mem.delete();
    mem_initialised = 0;
    commit_count = 0;
    pred_count = 0;
  endfunction

  // The image is configuration: read once, at the first commit, so the
  // sequence has already filled it. A reader never sees the memory the driver
  // mutates, and the DUT's own stores update only this model's copy.
  function void init_memory();
    if (mem_initialised) return;
    mem_initialised = 1;
    if (image == null) return;
    foreach (image.data[byte_addr])
      iss_mem[byte_addr >> 2] = image.data[byte_addr];
    `uvm_info(get_full_name(),
      $sformatf("ISS: data memory initialised from the program image (%0d word(s))", image.data_size()),
      UVM_MEDIUM)
  endfunction

  // ---- Observation: the only input -----------------------------------------
  // Fetch and data events are published by the monitor too; the ISS needs
  // neither (the retire event carries its instruction and the model owns its
  // memory), so it filters here and executes nothing else.
  function void write_mon(riscv_small_transaction t);
    if (!t.op_is_retire) return;
    commit_count++;
    execute(t.retire_pc, t.retire_inst);
  endfunction

  // ---- The ISS -------------------------------------------------------------
  // Executes one retired instruction. Only the load/store subset is modelled
  // (G-04): the other opcodes have no architectural effect this model tracks.
  function void execute(bit [31:0] pc, bit [31:0] inst);
    bit [6:0] opcode = inst[6:0];

    init_memory();

    // --- Loads (I-Type, opcode=0000011) -------------------------------------
    // LW, LB, LH, LBU, LHU. The lane comes from the low address bits, which is
    // exactly what FR-12 requires of the DUT.
    if (opcode == 7'b0000011) begin
      bit [4:0]  rd       = inst[11:7];
      bit [4:0]  rs1      = inst[19:15];
      bit [2:0]  funct3   = inst[14:12];
      bit [11:0] imm      = inst[31:20];
      int        byte_addr = reg_file[rs1] + $signed(imm);
      int        word_addr = byte_addr >> 2;
      bit [1:0]  lane      = byte_addr[1:0];
      bit [31:0] word      = iss_mem.exists(word_addr) ? iss_mem[word_addr] : 0;
      bit [7:0]  b         = word[8 * lane +: 8];
      bit [15:0] h         = word[16 * lane[1] +: 16];

      if (rd != 0) begin
        case (funct3)
          3'b000:  reg_file[rd] = int'({{24{b[7]}}, b});   // LB
          3'b001:  reg_file[rd] = int'({{16{h[15]}}, h});  // LH
          3'b010:  reg_file[rd] = int'(word);              // LW
          3'b100:  reg_file[rd] = int'({24'b0, b});        // LBU
          3'b101:  reg_file[rd] = int'({16'b0, h});        // LHU
          default: reg_file[rd] = int'(word);              // reserved form
        endcase
        `uvm_info(get_full_name(),
          $sformatf("ISS LD @0x%0h f3=%0b: x%0d <- mem_byte[%0d] (word=0x%0h lane=%0d) = 0x%0h",
            pc, funct3, rd, byte_addr, word, lane, reg_file[rd]),
          UVM_HIGH)
      end

    // --- SW (S-Type, opcode=0100011) ----------------------------------------
    end else if (opcode == 7'b0100011) begin
      bit [4:0]  rs2      = inst[24:20];
      bit [4:0]  rs1      = inst[19:15];
      bit [11:0] imm      = {inst[31:25], inst[11:7]};
      int        word_addr = (reg_file[rs1] + $signed(imm)) >> 2;
      int        byte_addr = word_addr << 2;

      iss_mem[word_addr] = reg_file[rs2];
      `uvm_info(get_full_name(),
        $sformatf("ISS SW @0x%0h: x%0d (=0x%0h) -> mem_byte[%0d] / mem_word[%0d]",
          pc, rs2, reg_file[rs2], byte_addr, word_addr),
        UVM_HIGH)

      // Publish the prediction the Scoreboard compares against the store the
      // monitor observes on the data port.
      begin
        riscv_small_transaction pred;
        pred = riscv_small_transaction::type_id::create("pred");
        pred.op_is_data_write   = 1;
        pred.op_is_data_read    = 0;
        pred.captured_data_addr = byte_addr;
        pred.captured_data_wr   = reg_file[rs2];
        pred_count++;
        rm2sb_port.write(pred);
      end
    end
    // Other opcodes (NOP, branches, ALU) have no effect on this subset.
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info(get_full_name(),
      $sformatf("ISS: %0d retire event(s) executed, %0d store prediction(s) published, data image=%0d word(s)%s",
        commit_count, pred_count,
        (image == null) ? 0 : image.data_size(),
        (image == null) ? " (no program image configured)" : ""),
      UVM_LOW)
  endfunction

endclass : riscv_small_ref_model

`endif
