`ifndef RISCV_SMALL_DRIVER
`define RISCV_SMALL_DRIVER

class riscv_small_driver extends uvm_driver #(riscv_small_transaction);

  virtual riscv_small_interface vif;
  `uvm_component_utils(riscv_small_driver)
  uvm_analysis_port#(riscv_small_transaction) drv2rm_port;

  logic [31:0] inst_mem [int];
  logic [31:0] data_mem [int];

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual riscv_small_interface)::get(this, "", "intf", vif))
      `uvm_fatal("NO_VIF",{"virtual interface must be set for: ",get_full_name(),".vif"});
    drv2rm_port = new("drv2rm_port", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    int data_ready_delay = 0;
    int d_word_addr;
    reset();

    // 1. Get initial test sequence transaction
    seq_item_port.get_next_item(req);
    req.print();
    foreach (req.instruction_addr[i]) begin
      inst_mem[req.instruction_addr[i]] = req.instruction_list[i];
    end
    foreach (req.data_addr[i]) begin
      data_mem[req.data_addr[i]] = req.data_list[i];
    end
    
    // Broadcast the full sequence item containing the subprogram
    drv2rm_port.write(req);
    
    // Sente PC=0 imediatamente antes de começar o loop principal
    // para que a primeira borda do clock capture LW0 corretamente.
    if (inst_mem.exists(0)) begin
      vif.inst_data.memory_w = inst_mem[0];
    end

    seq_item_port.item_done();

    // 2. Play memory behavior
    fork
      // --- Processo de Busca de Instrução (Combinatorial) ---
      forever begin
        @(vif.inst_addr or vif.inst_rd_en);
        if (vif.inst_rd_en) begin
          int pc_word_addr = vif.inst_addr >> 2;
          if (inst_mem.exists(pc_word_addr)) begin
            vif.inst_data.memory_w = inst_mem[pc_word_addr];
          end else begin
            vif.inst_data.memory_w = 32'h00000033;
          end
        end
      end

      // --- Processo de Acesso a Dados (Combinatorial) ---
      forever begin
        @(vif.data_addr or vif.data_rd_en_ma or vif.data_wr_en_ma or vif.data_wr);
        if (vif.data_rd_en_ma) begin
          int d_word_addr = vif.data_addr.u_data >> 2;
          if (data_mem.exists(d_word_addr)) begin
            vif.data_rd.u_data = data_mem[d_word_addr];
          end else begin
            vif.data_rd.u_data = 0;
          end
        end
        
        if (vif.data_wr_en_ma) begin
          int d_word_addr = vif.data_addr.u_data >> 2;
          data_mem[d_word_addr] = vif.data_wr.u_data;
        end
      end

      // --- Processo de Sinais de Controle (Síncrono via dr_cb) ---
      forever begin
        @(vif.dr_cb);
        vif.dr_cb.inst_ready <= 1;
        vif.dr_cb.data_ready <= 1;
      end
    join
  endtask

  task reset();
    vif.inst_ready = 1;
    vif.inst_data.memory_w = 0;
    vif.data_ready = 1;
    vif.data_rd.u_data = 0;
  endtask

endclass : riscv_small_driver

`endif
