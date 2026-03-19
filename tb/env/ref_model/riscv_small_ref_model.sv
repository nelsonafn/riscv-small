`ifndef RISCV_SMALL_REF_MODEL
`define RISCV_SMALL_REF_MODEL

// ============================================================================
// riscv_small_ref_model
//
// Modelo de Referência UVM (ISS - Instruction Set Simulator).
// Recebe o subprograma completo (instruções + estado inicial da memória) do
// Driver via rm_export, executa um ISS interno e publica uma transação de
// "previsão" para cada instrução SW encontrada, via rm2sb_port para o
// Scoreboard. O Scoreboard compara essas previsões com as observações reais
// do Monitor vindo da DUT.
//
// Author: Nelson Alves nelsonafn@gmail.com
// ============================================================================
class riscv_small_ref_model extends uvm_component;
  
  `uvm_component_utils(riscv_small_ref_model)

  // ---- Portos TLM ----------------------------------------------------------
  // Entrada: subprograma enviado pelo Driver
  uvm_analysis_export #(riscv_small_transaction) rm_export;
  uvm_tlm_analysis_fifo #(riscv_small_transaction) rm_fifo;
  // Saída: previsões de store para o Scoreboard
  uvm_analysis_port #(riscv_small_transaction) rm2sb_port;

  // ---- Construtor ----------------------------------------------------------
  function new(string name = "riscv_small_ref_model", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build phase ---------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    rm_fifo    = new("rm_fifo", this);
    rm_export  = new("rm_export", this);
    rm2sb_port = new("rm2sb_port", this);
  endfunction

  // ---- Connect phase -------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    rm_export.connect(rm_fifo.analysis_export);
  endfunction

  // ---- Run phase: ISS principal --------------------------------------------
  virtual task run_phase(uvm_phase phase);
    riscv_small_transaction subprog; // subprograma recebido do Driver

    forever begin
      // 1. Aguardar subprograma do Driver
      rm_fifo.get(subprog);
      `uvm_info(get_full_name(),
        $sformatf("ISS: Subprograma recebido — %0d instruções, %0d posições de dados",
          subprog.instruction_list.size(), subprog.data_addr.size()),
        UVM_LOW)

      // 2. Inicializar estado interno do ISS
      begin
        int reg_file[32];   // Banco de registradores (x0..x31)
        int iss_mem[int];   // Memória de dados (word address)

        for (int i = 0; i < 32; i++) reg_file[i] = 0; // x0 sempre zero

        // Popular memória com os dados iniciais (word address == data_addr[i])
        foreach (subprog.data_addr[i])
          iss_mem[subprog.data_addr[i]] = subprog.data_list[i];

        // 3. Simular cada instrução do subprograma
        foreach (subprog.instruction_list[i]) begin
          bit [31:0] inst   = subprog.instruction_list[i];
          bit [6:0]  opcode = inst[6:0];

          // --- LW (I-Type, opcode=0000011) ----------------------------------
          if (opcode == 7'b0000011) begin
            bit [4:0]  rd  = inst[11:7];
            bit [4:0]  rs1 = inst[19:15];
            bit [11:0] imm = inst[31:20];
            int word_addr  = (reg_file[rs1] + $signed(imm)) >> 2;

            if (rd != 0) begin
              reg_file[rd] = iss_mem.exists(word_addr) ? iss_mem[word_addr] : 0;
              `uvm_info(get_full_name(),
                $sformatf("ISS LW: x%0d ← mem_word[%0d] = 0x%0h",
                  rd, word_addr, reg_file[rd]),
                UVM_MEDIUM)
            end

          // --- SW (S-Type, opcode=0100011) ----------------------------------
          end else if (opcode == 7'b0100011) begin
            bit [4:0]  rs2 = inst[24:20];
            bit [4:0]  rs1 = inst[19:15];
            bit [11:0] imm = {inst[31:25], inst[11:7]};
            int word_addr  = (reg_file[rs1] + $signed(imm)) >> 2;
            int byte_addr  = word_addr << 2;

            iss_mem[word_addr] = reg_file[rs2];
            `uvm_info(get_full_name(),
              $sformatf("ISS SW: x%0d (=0x%0h) → mem_byte[%0d] / mem_word[%0d]",
                rs2, reg_file[rs2], byte_addr, word_addr),
              UVM_MEDIUM)

            // Publicar previsão para o Scoreboard
            begin
              riscv_small_transaction pred;
              pred = riscv_small_transaction::type_id::create("pred");
              pred.op_is_data_write    = 1;
              pred.op_is_data_read     = 0;
              pred.captured_data_addr  = byte_addr;
              pred.captured_data_wr    = reg_file[rs2];
              // Também carregar o subprograma para impressão no Scoreboard
              pred.instruction_list    = subprog.instruction_list;
              pred.data_addr           = subprog.data_addr;
              pred.data_list           = subprog.data_list;
              rm2sb_port.write(pred);
            end
          end
          // Demais opcodes (NOP, etc.) são ignorados pelo ISS
        end // foreach instruction

        `uvm_info(get_full_name(), "ISS: Subprograma concluído.", UVM_LOW)
      end
    end // forever
  endtask : run_phase

endclass : riscv_small_ref_model

`endif
