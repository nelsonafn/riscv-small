`ifndef RISCV_SMALL_BASIC_LOAD_STORE_SEQ
`define RISCV_SMALL_BASIC_LOAD_STORE_SEQ

class riscv_small_basic_load_store_seq extends uvm_sequence #(riscv_small_transaction);

  `uvm_object_utils(riscv_small_basic_load_store_seq)
 
  // Make N configurable to facilitate debugging
  int N = 2; // Max 31 registers supported (x1 to x31)
  // NOPs between LOAD and STORE phases to drain the 5-stage pipeline.
  // The synchronous RAM model adds 1 stall cycle per access.
  // The last LW (position N-1) needs 5 pipeline cycles + 1 stall cycle = 6 NOPs.
  localparam int BUBBLE_COUNT = 5;
  localparam int FLUSH_CYCLES = 4;

  function new (string name = "riscv_small_basic_load_store_seq");
    super.new(name);
  endfunction

  virtual task body();
    int rand_rd_addr[];
    int rand_wr_addr[];
    int rand_data[];
    int regs[];

    req = riscv_small_transaction::type_id::create("req");
    start_item(req);
    
    // N loads + BUBBLE_COUNT NOPs + N stores + FLUSH_CYCLES NOP final
    req.instruction_addr = new[N + BUBBLE_COUNT + N + FLUSH_CYCLES];
    req.instruction_list = new[N + BUBBLE_COUNT + N + FLUSH_CYCLES];
    req.data_addr = new[N*2]; // N loads + N stores
    req.data_list = new[N*2]; // N loads + N stores

    rand_rd_addr = new[N];
    rand_wr_addr = new[N];
    rand_data = new[N];
    regs = new[N];

    for (int i=0; i<N; i++) begin
      rand_rd_addr[i] = $urandom_range(100, 200 + N) * 4;
      rand_data[i] = $urandom();
      regs[i] = i + 1;

      req.data_addr[i] = rand_rd_addr[i];
      req.data_list[i] = rand_data[i];

      // Phase 1: Back-to-back LW - LOAD → LW xI, (addr)(x0) - Type I
      // x0 = 5'd0, base address register
      // xI = 5'(regs[i]), destination register
      // rd_imm = rand_rd_addr[i], offset from base address
      // func3 = 3'b010 = load word
      // opcode = 7'b0000011 = LW opcode
      begin
        bit [11:0] rd_imm = rand_rd_addr[i];
        req.instruction_addr[i] = i * 4;
        req.instruction_list[i] = { rd_imm, 5'd0, 3'b010, 5'(regs[i]), 7'b0000011 };
        `uvm_info("LOAD", $sformatf("LOAD: x%0d, (x0, %0d) → 'h%h,  rd_imm[11:5]=%h, rd_imm[4:0]=%h, rd_imm=%h", regs[i], rand_data[i], req.instruction_list[i], rd_imm[11:5], rd_imm[4:0], rd_imm), UVM_LOW);
      end
    end

    // Phase 2: Drainage - NOPs to drain the pipeline — ensures WB of all LWs before SWs
    for (int b = 0; b < BUBBLE_COUNT; b++) begin
      int idx = N + b;
      req.instruction_addr[idx] = idx * 4;
      req.instruction_list[idx]  = 32'h00000033; // NOP (ADD x0, x0, x0)
    end

    // Phase 3: Stores - STORE → SW xI, (wr_addr)(x0) - Type S
    // x0 = 5'd0, base address register
    // xI = 5'(regs[i]), source register for store
    // wr_imm = rand_wr_addr[i], offset from base address
    // func3 = 3'b010 = store word
    // opcode = 7'b0100011 = SW opcode
    for (int i=0; i<N; i++) begin
      rand_wr_addr[i] = $urandom_range(300, 400 + N) * 4;
      req.data_addr[i+N] = rand_wr_addr[i];
      req.data_list[i+N] = '{default: 'x};
      begin
        bit [11:0] wr_imm = rand_wr_addr[i];
        int idx = N + BUBBLE_COUNT + i;
        req.instruction_addr[idx] = idx * 4;
        req.instruction_list[idx] = { wr_imm[11:5], 5'(regs[i]), 5'd0, 3'b010, wr_imm[4:0], 7'b0100011 };
        `uvm_info("STORE", $sformatf("STORE: x%0d, (x0, %0d) → 'h%h,  wr_imm[11:5]=%h, wr_imm[4:0]=%h, wr_imm=%h", regs[i], rand_data[i], req.instruction_list[idx], wr_imm[11:5], wr_imm[4:0], wr_imm), UVM_LOW);
      end
    end

    // Final flush
    for (int f = 0; f < FLUSH_CYCLES; f++) begin
      int idx = N + BUBBLE_COUNT + N + f;
      req.instruction_addr[idx] = idx * 4;
      req.instruction_list[idx]  = 32'h00000033;
    end

    finish_item(req);

    // Wait long enough for the pipeline to process everything
    // N loads + BUBBLE_COUNT + N stores = approx 200ns
    #200ns;
  endtask

endclass

`endif
