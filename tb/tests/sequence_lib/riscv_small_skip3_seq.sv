//------------------------------------------------------------------------------
// Taken-branch sequence, three-instruction skip (WP-9 P1: G-28 invariant)
//------------------------------------------------------------------------------
// The sibling of riscv_small_branch_seq, whose branch skips exactly two words --
// the number of fetch slots the front end lets go when a branch is taken. That
// coincidence is what let a count-only invariant pass: fetch - commit happened
// to equal |skip_pc|.
//
// This program skips THREE words, so the two are no longer the same number:
//
//   0x00  LW  x1, 0x400(x0)     load A
//   0x04  LW  x2, 0x404(x0)     load B
//   0x08  BEQ x0, x0, +16       taken (x0 == x0); target 0x18
//   0x0c  SW  x1, 0x500(x0)     SKIPPED
//   0x10  SW  x2, 0x504(x0)     SKIPPED
//   0x14  SW  x1, 0x508(x0)     SKIPPED
//   0x18  SW  x1, 0x50c(x0)     executed
//   0x1c  SW  x2, 0x510(x0)     executed
//   0x20..0x2c  NOP x4
//
// The map above is relative to the program base: the words are emitted at
// base+offset, where the base is RESET_VECTOR (0x8000_0000 by default), because
// that is where the core fetches. The branch offset stays a relative +16.
//
// 12 words placed, 9 executed. The core fetches eleven of them: the PC is two
// slots ahead of ID, so when the branch resolves the two words behind it
// (0x0c and 0x10) are already fetched and both die at the IF/ID boundary;
// 0x14 is never fetched at all. Fetch - commit is therefore 2 while the program
// skips 3, and the correct invariant is about WHICH pc was fetched (0x0c, 0x10
// are skipped and never retire; 0x14 is skipped and never fetched), not about
// how many.
//
// Only the two executed stores appear in the data list: if the core ever
// reaches a skipped store the BFM reports an out-of-range access and the
// checker names the retired pc.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_SKIP3_SEQ
`define RISCV_SMALL_SKIP3_SEQ

// Extends the two-skip sequence for its instruction encoders and its
// register_image() only; body() is replaced, and the parent class is untouched
// so T-45 keeps its exact program and counts.
class riscv_small_skip3_seq extends riscv_small_branch_seq;

  `uvm_object_utils(riscv_small_skip3_seq)

  localparam int SRC_A      = 'h400;
  localparam int SRC_B      = 'h404;
  localparam int SKIPPED_0  = 'h500;
  localparam int SKIPPED_1  = 'h504;
  localparam int SKIPPED_2  = 'h508;
  localparam int STORE_A    = 'h50c;
  localparam int STORE_B    = 'h510;
  localparam int VAL_A      = 'h1111_2222;
  localparam int VAL_B      = 'h3333_4444;
  localparam int BRANCH_OFF = 16;  // branch pc 0x08 + 16 = 0x18, three words past the branch
  localparam int TAIL       = 4;
  localparam int BODY_WORDS = 8;   // two loads, the branch, three skipped stores, two stores

  function new (string name = "riscv_small_skip3_seq");
    super.new(name);
  endfunction

  virtual task body();
    int idx;

    mem_base = riscv_small_seq_mem_base(m_sequencer);

    req = riscv_small_transaction::type_id::create("req");
    req.instruction_addr = new[BODY_WORDS + TAIL];
    req.instruction_list = new[BODY_WORDS + TAIL];

    // The three skipped store addresses are deliberately NOT listed: if the core
    // reaches one of them the memory BFM reports an out-of-range access instead
    // of answering politely.
    req.data_addr = new[4];
    req.data_list = new[4];
    req.data_addr[0] = SRC_A;   req.data_list[0] = VAL_A;
    req.data_addr[1] = SRC_B;   req.data_list[1] = VAL_B;
    req.data_addr[2] = STORE_A; req.data_list[2] = 'x;
    req.data_addr[3] = STORE_B; req.data_list[3] = 'x;

    idx = 0;
    req.instruction_addr[idx] = mem_base + idx * 4;
    req.instruction_list[idx] = enc_load(3'b010, 5'd1, SRC_A);
    `uvm_info("SKIP3", $sformatf("[%0d] pc=0x%08h LW   x1, 'h%0h(x0)", idx, mem_base + idx*4, SRC_A), UVM_LOW)
    idx++;

    req.instruction_addr[idx] = mem_base + idx * 4;
    req.instruction_list[idx] = enc_load(3'b010, 5'd2, SRC_B);
    `uvm_info("SKIP3", $sformatf("[%0d] pc=0x%08h LW   x2, 'h%0h(x0)", idx, mem_base + idx*4, SRC_B), UVM_LOW)
    idx++;

    req.instruction_addr[idx] = mem_base + idx * 4;
    req.instruction_list[idx] = enc_beq(5'd0, 5'd0, 13'(BRANCH_OFF));
    `uvm_info("SKIP3", $sformatf("[%0d] pc=0x%08h BEQ  x0, x0, +%0d  -> taken, skips 0x%02h, 0x%02h and 0x%02h",
      idx, mem_base + idx*4, BRANCH_OFF, (mem_base + (idx+1)*4), (mem_base + (idx+2)*4), (mem_base + (idx+3)*4)), UVM_LOW)
    idx++;

    req.instruction_addr[idx] = mem_base + idx * 4;
    req.instruction_list[idx] = enc_sw(5'd1, SKIPPED_0);
    `uvm_info("SKIP3", $sformatf("[%0d] pc=0x%08h SW   x1, 'h%0h(x0)  SKIPPED", idx, mem_base + idx*4, SKIPPED_0), UVM_LOW)
    idx++;

    req.instruction_addr[idx] = mem_base + idx * 4;
    req.instruction_list[idx] = enc_sw(5'd2, SKIPPED_1);
    `uvm_info("SKIP3", $sformatf("[%0d] pc=0x%08h SW   x2, 'h%0h(x0)  SKIPPED", idx, mem_base + idx*4, SKIPPED_1), UVM_LOW)
    idx++;

    req.instruction_addr[idx] = mem_base + idx * 4;
    req.instruction_list[idx] = enc_sw(5'd1, SKIPPED_2);
    `uvm_info("SKIP3", $sformatf("[%0d] pc=0x%08h SW   x1, 'h%0h(x0)  SKIPPED", idx, mem_base + idx*4, SKIPPED_2), UVM_LOW)
    idx++;

    req.instruction_addr[idx] = mem_base + idx * 4;
    req.instruction_list[idx] = enc_sw(5'd1, STORE_A);
    `uvm_info("SKIP3", $sformatf("[%0d] pc=0x%08h SW   x1, 'h%0h(x0)", idx, mem_base + idx*4, STORE_A), UVM_LOW)
    idx++;

    req.instruction_addr[idx] = mem_base + idx * 4;
    req.instruction_list[idx] = enc_sw(5'd2, STORE_B);
    `uvm_info("SKIP3", $sformatf("[%0d] pc=0x%08h SW   x2, 'h%0h(x0)", idx, mem_base + idx*4, STORE_B), UVM_LOW)
    idx++;

    for (int t = 0; t < TAIL; t++) begin
      req.instruction_addr[idx] = mem_base + idx * 4;
      req.instruction_list[idx] = 32'h00000033; // NOP: ADD x0, x0, x0
      idx++;
    end

    // The program image is configuration, and so is its control-flow structure:
    // the three words the branch skips are declared by name, so the checker can
    // assert their absence from the commit stream and count the ones the front
    // end actually reached.
    register_image(req);
    declare_skips3();
    // The driver is the only consumer of the item; the model follows the
    // monitor's commit stream.
    start_item(req);
    finish_item(req);
  endtask

  function void declare_skips3();
    riscv_small_program_image image;
    if (!uvm_config_db#(riscv_small_program_image)::get(m_sequencer, "", "program_image", image))
      return;
    for (int i = 3; i <= 5; i++)
      image.add_skip(mem_base + i * 4);
  endfunction

endclass

`endif
