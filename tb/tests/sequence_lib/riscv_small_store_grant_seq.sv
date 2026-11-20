//------------------------------------------------------------------------------
// Store grant sequence for riscv_small (WP-13 P3: FR-38, G-18)
//------------------------------------------------------------------------------
// One claim: a store is not accepted before the data memory grants it.
//
// The program names the two things the claim needs at the data port:
//
//   LW  x10, 0x408   the value both stores carry (0x12345678), so a store's
//                    data is a distinctive word and not "whatever was in rs2"
//   NOP x3           the load-use gap, so this measures the store and not the
//                    forwarding path
//   SW  x10, 0x418   store A -- the access the memory withholds the grant for
//   SW  x10, 0x424   store B -- back-to-back, so "no further access address
//                    appears until A is granted" is observable as an address
//                    that moved while A had no grant
//   NOP x6           tail: the grants complete, the pipeline drains
//
// The test configures the memory BFM to withhold `data_ready` for two cycles
// (FR-38's acceptance cell: "a data memory that withholds the grant for two
// cycles"), so with the core as it stands store A is presented for exactly one
// cycle whatever the grant does: at the next cycle A is gone and B is on the
// bus. That is the observation riscv_small_store_grant_checker turns into the
// verdict, naming the cycle. This sequence never judges it.
//
// The scoreboard is green either way, and deliberately so: the fields a store
// is compared on (address, strobes, lane data) are correct in both worlds --
// what is wrong is WHEN the core let go of them. A test that only compared the
// fields would call the defect a pass, which is why FR-38 has a protocol
// checker of its own.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_STORE_GRANT_SEQ
`define RISCV_SMALL_STORE_GRANT_SEQ

class riscv_small_store_grant_seq extends uvm_sequence #(riscv_small_transaction);

  `uvm_object_utils(riscv_small_store_grant_seq)

  // Data addresses. Every address is used as an offset from x0, so it must fit
  // the signed 12-bit immediate of the I/S formats (all of these are < 0x800).
  localparam int SRC        = 'h408; // the word both stores carry
  localparam int SRC_VAL    = 'h1234_5678;
  localparam int STORE_A    = 'h418; // word 0x106
  localparam int STORE_B    = 'h424; // word 0x109: a different word, not a rewrite
  localparam int STORE_BASE = 'h0000_0000;

  localparam int BUBBLE = 3; // the load-use gap
  localparam int TAIL   = 6; // the grants complete before the last fetch

  localparam bit [31:0] NOP = 32'h00000033; // ADD x0, x0, x0

  // Program base, set in body() from the value the top published (FR-41).
  protected bit [31:0] mem_base;

  function new (string name = "riscv_small_store_grant_seq");
    super.new(name);
  endfunction

  // I-type load: imm[11:0] | rs1 | funct3 | rd | opcode 0000011
  function automatic bit [31:0] enc_load(bit [2:0] f3, bit [4:0] rd, bit [11:0] imm);
    return {imm, 5'd0, f3, rd, 7'b0000011};
  endfunction

  // S-type store: imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode 0100011
  function automatic bit [31:0] enc_store(bit [2:0] f3, bit [4:0] rs2, bit [11:0] imm);
    return {imm[11:5], rs2, 5'd0, f3, imm[4:0], 7'b0100011};
  endfunction

  virtual task body();
    bit [31:0] prog[$];
    int        da[$];
    int        dv[$];
    int        last;

    mem_base = riscv_small_seq_mem_base(m_sequencer);
    req = riscv_small_transaction::type_id::create("req");

    prog.push_back(enc_load(3'b010, 5'd10, 12'(SRC)));      // LW x10, 0x408
    repeat (BUBBLE) prog.push_back(NOP);
    prog.push_back(enc_store(3'b010, 5'd10, 12'(STORE_A))); // SW x10, 0x418
    prog.push_back(enc_store(3'b010, 5'd10, 12'(STORE_B))); // SW x10, 0x424
    repeat (TAIL) prog.push_back(NOP);

    last = prog.size();
    req.instruction_addr = new[last];
    req.instruction_list = new[last];
    foreach (prog[i]) begin
      req.instruction_addr[i] = mem_base + i * 4;
      req.instruction_list[i] = prog[i];
    end

    // ---- Data memory: one entry per byte address the program names ---------
    // The directed BFM answers an access only at a declared address, and for a
    // store the declared word is the byte base the DUT's strobes are applied to.
    da.push_back(SRC);     dv.push_back(SRC_VAL);
    da.push_back(STORE_A); dv.push_back(STORE_BASE);
    da.push_back(STORE_B); dv.push_back(STORE_BASE);

    req.data_addr = new[da.size()];
    req.data_list = new[dv.size()];
    foreach (da[i]) begin
      req.data_addr[i] = da[i];
      req.data_list[i] = dv[i];
    end

    `uvm_info("STORE_GRANT",
      $sformatf("SW  x10 @0x%03h and SW x10 @0x%03h of 0x%08h, data_ready withheld for the BFM delay: FR-38 requires the core to hold each store until the grant, so exactly one of each reaches the memory",
        STORE_A, STORE_B, SRC_VAL), UVM_LOW)
    `uvm_info("STORE_GRANT",
      $sformatf("the defect (G-18) presents each store for one cycle whatever data_ready does: store A is gone at the cycle the grant arrives and store B's address appears while A had none -- riscv_small_store_grant_checker names the cycle"),
      UVM_LOW)

    // The program image is configuration, not a transaction.
    register_image(req);

    // The program item is complete: hand it to the driver, the only consumer.
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
  endfunction

endclass

`endif
