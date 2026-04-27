`ifndef RISCV_SMALL_BASIC_LOAD_STORE_SEQ
`define RISCV_SMALL_BASIC_LOAD_STORE_SEQ

class riscv_small_basic_load_store_seq extends uvm_sequence #(riscv_small_transaction);

  `uvm_object_utils(riscv_small_basic_load_store_seq)
 
  // Make N configurable to facilitate debugging
  int N = 31; // Max 31 registers supported (x1 to x31)
  // NOPs between LOAD and STORE phases to drain the 5-stage pipeline.
  // The synchronous RAM model adds 1 stall cycle per access.
  // The last LW (position N-1) needs 5 pipeline cycles + 1 stall cycle = 6 NOPs.
  localparam int BUBBLE_COUNT = 5;
  localparam int FLUSH_CYCLES = 5;

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

    begin
      int used_rd_addr[int];
      for (int i=0; i<N; i++) begin
        int temp_addr;
        // Generate values until an unused one is found
        do begin
          temp_addr = $urandom_range(100, 200 + N) * 4;
        end while (used_rd_addr.exists(temp_addr));
        
        used_rd_addr[temp_addr] = 1; // Mark as used
        rand_rd_addr[i] = temp_addr;
        
        rand_data[i] = $urandom();
        regs[i] = i + 1;
  
        req.data_addr[i] = rand_rd_addr[i];
        req.data_list[i] = rand_data[i];
      end
    end

    // Phase 1: Back-to-back LW - LOAD → LW xI, (addr)(x0) - Type I
    // x0 = 5'd0, base address register
    // xI = 5'(regs[i]), destination register
    // rd_imm = rand_rd_addr[i], offset from base address
    // func3 = 3'b010 = load word
    // opcode = 7'b0000011 = LW opcode
    for (int i=0; i<N; i++) begin
      bit [11:0] rd_imm = rand_rd_addr[i];
      req.instruction_addr[i] = i * 4;
      req.instruction_list[i] = { rd_imm, 5'd0, 3'b010, 5'(regs[i]), 7'b0000011 };
      `uvm_info("LOAD", $sformatf("LOAD: x%0d, 'h%0h(x0) == 'h%0h → x%0d <= DMEM[x0 + 'h%0h] → x%0d <= 'h%h", regs[i], rd_imm, req.instruction_list[i], regs[i], rd_imm, regs[i], rand_data[i]), UVM_LOW);
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
    begin
      int used_wr_addr[int];
      for (int i=0; i<N; i++) begin
        int temp_addr;
        do begin
          temp_addr = $urandom_range(300, 400 + N) * 4;
        end while (used_wr_addr.exists(temp_addr));
        
        used_wr_addr[temp_addr] = 1;
        rand_wr_addr[i] = temp_addr;
        
        req.data_addr[i+N] = rand_wr_addr[i];
        req.data_list[i+N] = '{default: 'x};
        begin
          bit [11:0] wr_imm = rand_wr_addr[i];
          int idx = N + BUBBLE_COUNT + i;
          req.instruction_addr[idx] = idx * 4;
          req.instruction_list[idx] = { wr_imm[11:5], 5'(regs[i]), 5'd0, 3'b010, wr_imm[4:0], 7'b0100011 };
          `uvm_info("STORE", $sformatf("STORE: x%0d, x0('h%0h) == 'h%0h → DMEM[x0 + 'h%0h] <= 0x%0h → DMEM[x0 + 'h%0h] <= 'h%0h", regs[i], wr_imm, req.instruction_list[idx], wr_imm, regs[i], wr_imm, rand_data[i]), UVM_LOW);
        end
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
  endtask

endclass

`endif
