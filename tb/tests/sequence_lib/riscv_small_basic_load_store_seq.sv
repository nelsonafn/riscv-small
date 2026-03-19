`ifndef RISCV_SMALL_BASIC_LOAD_STORE_SEQ
`define RISCV_SMALL_BASIC_LOAD_STORE_SEQ

class riscv_small_basic_load_store_seq extends uvm_sequence #(riscv_small_transaction);

  `uvm_object_utils(riscv_small_basic_load_store_seq)
 
  // Deixe N configurável para facilitar depuração
  int N = 31; // Max 31 registradores suportados (x1 a x31)
  // NOPs entre fase LOAD e STORE para drenar o pipeline de 5 estágios
  // O modelo de RAM síncrona adiciona 1 ciclo de stall por acesso.
  // O último LW (posição N-1) precisa de 5 ciclos pipeline + 1 ciclo stall = 6 NOPs.
  localparam int BUBBLE_COUNT = 0;

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
    
    // N loads + BUBBLE_COUNT NOPs + N stores + 1 NOP final
    req.instruction_addr = new[N + BUBBLE_COUNT + N + 1];
    req.instruction_list = new[N + BUBBLE_COUNT + N + 1];
    req.data_addr = new[N];
    req.data_list = new[N];

    rand_rd_addr = new[N];
    rand_wr_addr = new[N];
    rand_data = new[N];
    regs = new[N];

    for (int i=0; i<N; i++) begin
      rand_rd_addr[i] = $urandom_range(100, 200 + N);
      rand_wr_addr[i] = $urandom_range(300, 400 + N);
      rand_data[i] = $urandom();
      regs[i] = i + 1;

      req.data_addr[i] = rand_rd_addr[i];
      req.data_list[i] = rand_data[i];

      // Fase 1: LW back-to-back - LOAD → LW xI, (addr*4)(x0)
      begin
        bit [11:0] rd_imm = rand_rd_addr[i] * 4;
        req.instruction_addr[i] = i * 4;
        req.instruction_list[i] = { rd_imm, 5'd0, 3'b010, 5'(regs[i]), 7'b0000011 };
      end
    end

    // Fase 2: Drenagem - NOPs para drenar o pipeline — garante WB de todos os LW antes dos SW
    for (int b = 0; b < BUBBLE_COUNT; b++) begin
      int idx = N + b;
      req.instruction_addr[idx] = idx * 4;
      req.instruction_list[idx]  = 32'h00000033; // NOP (ADD x0, x0, x0)
    end

    // Fase 3: Stores - STORE → SW xI, (wr_addr*4)(x0) 
    for (int i=0; i<N; i++) begin
      begin
        bit [11:0] wr_imm = rand_wr_addr[i] * 4;
        int idx = N + BUBBLE_COUNT + i;
        req.instruction_addr[idx] = idx * 4;
        req.instruction_list[idx] = { wr_imm[11:5], 5'(regs[i]), 5'd0, 3'b010, wr_imm[4:0], 7'b0100011 };
      end
    end

    // NOP final
    begin
      int idx = N + BUBBLE_COUNT + N;
      req.instruction_addr[idx] = idx * 4;
      req.instruction_list[idx]  = 32'h00000033;
    end

    finish_item(req);

    // Esperar tempo suficiente para o pipeline processar tudo
    // N loads + BUBBLE_COUNT + N stores = ~67 ciclos * 10ns = ~700ns
    #10us;
  endtask

endclass

`endif
