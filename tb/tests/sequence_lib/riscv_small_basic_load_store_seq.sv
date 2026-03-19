`ifndef RISCV_SMALL_BASIC_SEQ 
`define RISCV_SMALL_BASIC_SEQ

class riscv_small_basic_load_store_seq extends uvm_sequence#(riscv_small_transaction);
   
  `uvm_object_utils(riscv_small_basic_load_store_seq)
 
  // Deixe N configurável para facilitar depuração
  int N = 30; // Max 31 registradores suportados (x1 a x31)
  // Número de NOPs entre a fase de LOAD e STORE para drenar o pipeline (~3 estágios)
  localparam int BUBBLE_COUNT = 3;
 
  function new(string name = "riscv_small_basic_load_store_seq");
    super.new(name);
  endfunction
 
  virtual task body();
    int rand_rd_addr[];
    int rand_wr_addr[];
    int rand_data[];
    int regs[];

    req = riscv_small_transaction::type_id::create("req");
    start_item(req);
    
    // NOP inicial + N loads + BUBBLE_COUNT NOPs + N stores + 1 NOP final
    req.instruction_addr = new[1 + N + BUBBLE_COUNT + N + 1];
    req.instruction_list = new[1 + N + BUBBLE_COUNT + N + 1];
    req.data_addr = new[N];
    req.data_list = new[N];

    rand_rd_addr = new[N];
    rand_wr_addr = new[N];
    rand_data = new[N];
    regs = new[N];

    // Dummy NOP at PC=0 para absorver o atraso do clocking block no driver
    req.instruction_addr[0] = 0;
    req.instruction_list[0] = 32'h00000033;

    // Gerar valores aleatórios para N cargas e N escritas
    for (int i=0; i<N; i++) begin
      rand_rd_addr[i] = $urandom_range(100, 200 + N); // Range 1 de dados (aleatórios)
      rand_wr_addr[i] = $urandom_range(300, 400 + N); // Range 2 de dados (aleatórios)
      rand_data[i] = $urandom();
      regs[i] = i + 1; // Registradores de x1 até xN
      
      // Popular memória inicial
      req.data_addr[i] = rand_rd_addr[i];
      req.data_list[i] = rand_data[i];
      
      // Primeira fase: Instruções de LOAD
      // LW rx, (rd_addr*4)(x0)
      begin
        bit [11:0] rd_imm = rand_rd_addr[i] * 4;
        req.instruction_addr[i + 1] = i + 1;
        // I-Type opcode: 0000011, funct3: 010, rd: regs[i], rs1: x0
        req.instruction_list[i + 1] = { rd_imm, 5'd0, 3'b010, 5'(regs[i]), 7'b0000011 };
      end
    end

    // Fase 2: NOPs para drenar o pipeline e garantir WB dos loads antes dos stores
    for (int b = 0; b < BUBBLE_COUNT; b++) begin
      int idx = N + 1 + b;
      req.instruction_addr[idx] = idx;
      req.instruction_list[idx]  = 32'h00000033; // NOP (ADD x0, x0, x0)
    end

    // Fase 3: Instruções de STORE
    for (int i=0; i<N; i++) begin
      // SW rx, (wr_addr*4)(x0)
      begin
        bit [11:0] wr_imm = rand_wr_addr[i] * 4;
        int idx = 1 + N + BUBBLE_COUNT + i;
        req.instruction_addr[idx] = idx;
        // S-Type opcode: 0100011, funct3: 010, rs2: regs[i], rs1: x0
        req.instruction_list[idx] = { wr_imm[11:5], 5'(regs[i]), 5'd0, 3'b010, wr_imm[4:0], 7'b0100011 };
      end
    end

    // NOP final para a CPU não executar lixo além do programa
    begin
      int idx = 1 + N + BUBBLE_COUNT + N;
      req.instruction_addr[idx] = idx;
      req.instruction_list[idx]  = 32'h00000033;
    end

    `uvm_info(get_full_name(), $sformatf("SENDING %0d RANDOM LOADS SEGUIDOS DE %0d STORES", N, N), UVM_LOW);
    finish_item(req);
    
    #100000;
  endtask
   
endclass

`endif
