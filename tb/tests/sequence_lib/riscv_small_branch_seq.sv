//------------------------------------------------------------------------------
// Taken-branch sequence for riscv_small (WP-8 follow-up: retire != fetch)
//------------------------------------------------------------------------------
// The only program in the directed corpus whose control flow does NOT execute
// every instruction it places: a taken forward BEQ skips two stores.
//
//   0x00  LW  x1, 0x400(x0)     load A
//   0x04  LW  x2, 0x404(x0)     load B
//   0x08  BEQ x0, x0, +12       taken (x0 == x0); target 0x14
//   0x0c  SW  x1, 0x500(x0)     SKIPPED -- never fetched into the pipeline as
//   0x10  SW  x2, 0x504(x0)     SKIPPED    an executed instruction, never retired
//   0x14  SW  x1, 0x508(x0)     executed
//   0x18  SW  x2, 0x50c(x0)     executed
//   0x1c..0x2c  NOP x5
//
// Two facts make this program the evidence that the observation is a RETIRE and
// not a fetch:
//   - the commit count is 10, not 12, while the fetch count is 12: the two
//     addresses the core prefetched behind the branch are discarded by
//     if_id_flush and never reach write-back;
//   - the two skipped stores are real SW words: a model that executed what it
//     fetched would publish two predictions the DUT never makes.
// The target is branch+12, so the two fetches the core discards are exactly the
// two instructions the branch skips and no address is fetched twice.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_BRANCH_SEQ
`define RISCV_SMALL_BRANCH_SEQ

class riscv_small_branch_seq extends riscv_small_basic_load_store_seq;

  `uvm_object_utils(riscv_small_branch_seq)

  localparam int SRC_A      = 'h400;
  localparam int SRC_B      = 'h404;
  localparam int SKIPPED_0  = 'h500;
  localparam int SKIPPED_1  = 'h504;
  localparam int STORE_A    = 'h508;
  localparam int STORE_B    = 'h50c;
  localparam int VAL_A      = 'h1111_2222;
  localparam int VAL_B      = 'h3333_4444;
  localparam int BRANCH_OFF = 12;  // branch + 12 = the instruction after both skipped words
  localparam int TAIL       = 5;
  localparam int BODY_WORDS = 7;   // two loads, the branch, two skipped stores, two stores

  function new (string name = "riscv_small_branch_seq");
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

  // B-type: imm[12] | imm[10:5] | rs2 | rs1 | funct3 000 | imm[4:1] | imm[11] | 1100011
  function automatic bit [31:0] enc_beq(bit [4:0] rs1, bit [4:0] rs2, bit [12:0] imm);
    return {imm[12], imm[10:5], rs2, rs1, 3'b000, imm[4:1], imm[11], 7'b1100011};
  endfunction

  virtual task body();
    int idx;

    req = riscv_small_transaction::type_id::create("req");
    req.instruction_addr = new[BODY_WORDS + TAIL];
    req.instruction_list = new[BODY_WORDS + TAIL];

    // Loads and the stores the program will make. The two skipped store
    // addresses are deliberately NOT listed: if the core ever reaches them the
    // memory BFM reports an out-of-range access instead of answering politely.
    req.data_addr = new[4];
    req.data_list = new[4];
    req.data_addr[0] = SRC_A;   req.data_list[0] = VAL_A;
    req.data_addr[1] = SRC_B;   req.data_list[1] = VAL_B;
    req.data_addr[2] = STORE_A; req.data_list[2] = 'x;
    req.data_addr[3] = STORE_B; req.data_list[3] = 'x;

    idx = 0;
    req.instruction_addr[idx] = idx * 4;
    req.instruction_list[idx] = enc_load(3'b010, 5'd1, SRC_A);
    `uvm_info("BRANCH", $sformatf("[%0d] pc=0x%02h LW   x1, 'h%0h(x0)", idx, idx*4, SRC_A), UVM_LOW)
    idx++;

    req.instruction_addr[idx] = idx * 4;
    req.instruction_list[idx] = enc_load(3'b010, 5'd2, SRC_B);
    `uvm_info("BRANCH", $sformatf("[%0d] pc=0x%02h LW   x2, 'h%0h(x0)", idx, idx*4, SRC_B), UVM_LOW)
    idx++;

    req.instruction_addr[idx] = idx * 4;
    req.instruction_list[idx] = enc_beq(5'd0, 5'd0, 13'(BRANCH_OFF));
    `uvm_info("BRANCH", $sformatf("[%0d] pc=0x%02h BEQ  x0, x0, +%0d  -> taken, skips 0x%02h and 0x%02h",
      idx, idx*4, BRANCH_OFF, (idx+1)*4, (idx+2)*4), UVM_LOW)
    idx++;

    req.instruction_addr[idx] = idx * 4;
    req.instruction_list[idx] = enc_sw(5'd1, SKIPPED_0);
    `uvm_info("BRANCH", $sformatf("[%0d] pc=0x%02h SW   x1, 'h%0h(x0)  SKIPPED", idx, idx*4, SKIPPED_0), UVM_LOW)
    idx++;

    req.instruction_addr[idx] = idx * 4;
    req.instruction_list[idx] = enc_sw(5'd2, SKIPPED_1);
    `uvm_info("BRANCH", $sformatf("[%0d] pc=0x%02h SW   x2, 'h%0h(x0)  SKIPPED", idx, idx*4, SKIPPED_1), UVM_LOW)
    idx++;

    req.instruction_addr[idx] = idx * 4;
    req.instruction_list[idx] = enc_sw(5'd1, STORE_A);
    `uvm_info("BRANCH", $sformatf("[%0d] pc=0x%02h SW   x1, 'h%0h(x0)", idx, idx*4, STORE_A), UVM_LOW)
    idx++;

    req.instruction_addr[idx] = idx * 4;
    req.instruction_list[idx] = enc_sw(5'd2, STORE_B);
    `uvm_info("BRANCH", $sformatf("[%0d] pc=0x%02h SW   x2, 'h%0h(x0)", idx, idx*4, STORE_B), UVM_LOW)
    idx++;

    for (int t = 0; t < TAIL; t++) begin
      req.instruction_addr[idx] = idx * 4;
      req.instruction_list[idx] = 32'h00000033; // NOP: ADD x0, x0, x0
      idx++;
    end

    // The program image is configuration, and so is its control-flow structure:
    // the two words the branch skips are declared, not inferred, so the checker
    // can assert their absence from the commit stream by name.
    register_image(req);
    declare_skips();
    // The driver is the only consumer of the item; the model follows the
    // monitor's commit stream.
    start_item(req);
    finish_item(req);
  endtask

  function void declare_skips();
    riscv_small_program_image image;
    if (!uvm_config_db#(riscv_small_program_image)::get(m_sequencer, "", "program_image", image))
      return;
    for (int i = 3; i <= 4; i++)
      image.add_skip(i * 4);
  endfunction

endclass

`endif
