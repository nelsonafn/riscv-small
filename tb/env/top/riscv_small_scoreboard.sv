`ifndef RISCV_SMALL_SCOREBOARD
`define RISCV_SMALL_SCOREBOARD

class riscv_small_scoreboard extends uvm_scoreboard;
  
  `uvm_component_utils(riscv_small_scoreboard)
  uvm_analysis_export #(riscv_small_transaction) sb_export_mon;
  uvm_analysis_export #(riscv_small_transaction) sb_export_rm; // Required by top env connection
  
  uvm_tlm_analysis_fifo #(riscv_small_transaction) mon_fifo;
  uvm_tlm_analysis_fifo #(riscv_small_transaction) rm_fifo; // Dummy

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon_fifo = new("mon_fifo", this);
    rm_fifo = new("rm_fifo", this);
    sb_export_mon = new("sb_export_mon", this);
    sb_export_rm = new("sb_export_rm", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    sb_export_mon.connect(mon_fifo.analysis_export);
    sb_export_rm.connect(rm_fifo.analysis_export); // Dummy connection
  endfunction

  task run_phase(uvm_phase phase);
    riscv_small_transaction mon_trans;
    riscv_small_transaction rm_trans;
    
    int expected_mem[int];
    int reg_file[32];
    
    // 1. Pegar o subprograma enviado pelo Driver
    rm_fifo.get(rm_trans);
    `uvm_info(get_full_name(), "Recebido Subprograma! Contruindo Reference Model interno...", UVM_LOW);
    
    // Iniciar Registradores com zero
    for (int i=0; i<32; i++) reg_file[i] = 0;
    
    // Popular memória Mapeada
    foreach (rm_trans.data_addr[i]) begin
        expected_mem[rm_trans.data_addr[i]] = rm_trans.data_list[i];
    end
    
    // Parsing das instruções para simular o comportamento da CPU RISC-V 
    foreach (rm_trans.instruction_list[i]) begin
        bit [31:0] inst = rm_trans.instruction_list[i];
        bit [6:0] opcode = inst[6:0];
        
        if (opcode == 7'b0000011) begin // LOAD (LW)
            bit [4:0] rd = inst[11:7];
            bit [4:0] rs1 = inst[19:15];
            bit [11:0] imm = inst[31:20];
            int addr = (reg_file[rs1] + signed'(imm)) >> 2; // word address
            
            if (rd != 0) begin
                if (expected_mem.exists(addr)) begin
                    reg_file[rd] = expected_mem[addr];
                end else begin
                    reg_file[rd] = 0;
                end
                `uvm_info(get_full_name(), $sformatf("ISS LW: x%0d ← mem_word[%0d] = %0h", rd, addr, reg_file[rd]), UVM_LOW);
            end
        end else if (opcode == 7'b0100011) begin // STORE (SW)
            bit [4:0] rs2 = inst[24:20];
            bit [4:0] rs1 = inst[19:15];
            bit [11:0] imm = {inst[31:25], inst[11:7]};
            int addr = (reg_file[rs1] + signed'(imm)) >> 2; // word address
            
            expected_mem[addr] = reg_file[rs2];
            `uvm_info(get_full_name(), $sformatf("ISS SW: x%0d=%0h → mem_word[%0d] (byte=%0d)", rs2, reg_file[rs2], addr, addr*4), UVM_LOW);
        end
    end
    
    // 2. Verificar continuamente os Monitores de Escrita contra o Reference Model
    forever begin
      mon_fifo.get(mon_trans);
      
      if (mon_trans.op_is_data_write) begin
        int d_word_addr = mon_trans.captured_data_addr >> 2;
        
        if (expected_mem.exists(d_word_addr)) begin
          if (mon_trans.captured_data_wr == expected_mem[d_word_addr]) begin
            `uvm_info(get_full_name(), $sformatf("SUCCESS: Store para a memória %0d executou com perfeição de acordo com o Subprograma! (Dado: %0h)", mon_trans.captured_data_addr, mon_trans.captured_data_wr), UVM_LOW);
          end else begin
            `uvm_error(get_full_name(), $sformatf("FAILURE: Corrupção! O Store para o endereço %0d teve erro de dados. Esperado %0h, Encontrado %0h", mon_trans.captured_data_addr, expected_mem[d_word_addr], mon_trans.captured_data_wr));
          end
        end else begin
            `uvm_error(get_full_name(), $sformatf("FAILURE: Unexpected Store para endereço não previsto no programa: %0d", mon_trans.captured_data_addr));
        end
      end
    end
  endtask

endclass

`endif
