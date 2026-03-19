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
    foreach (req.instruction_addr[i]) begin
      inst_mem[req.instruction_addr[i]] = req.instruction_list[i];
    end
    foreach (req.data_addr[i]) begin
      data_mem[req.data_addr[i]] = req.data_list[i];
    end
    
    // Broadcast the full sequence item containing the subprogram
    drv2rm_port.write(req);
    
    seq_item_port.item_done();

    // 2. Play memory behavior forever
    forever begin
      @(vif.dr_cb);
      
      // Instruction fetch behavior
      if (vif.dr_cb.inst_rd_en) begin
        int pc_word_addr = vif.dr_cb.inst_addr >> 2; // Word aligned index
        if (inst_mem.exists(pc_word_addr)) begin
            vif.dr_cb.inst_data.memory_w <= inst_mem[pc_word_addr];
            vif.dr_cb.inst_ready <= 1;
        end else begin
            vif.dr_cb.inst_data.memory_w <= 0;
            vif.dr_cb.inst_ready <= 1; // Emulate empty memory returning zeros without stalling
        end
      end else begin
        vif.dr_cb.inst_ready <= 1;
      end

      // Modelo de RAM Síncrona com 1 ciclo de latência:
      // Ciclo T  : data_rd_en_ma=1 → stall (data_ready=0), pré-carregar dado no barramento
      // Ciclo T+1: data_ready=1 → DUT amostra dado no posedge de T+2
      if (vif.dr_cb.data_rd_en_ma) begin
        if (data_ready_delay == 0) begin
            // Stall: DUT irá repetir este ciclo na próxima borda
            vif.dr_cb.data_ready <= 0;
            data_ready_delay = 1;
            // Pré-carregar dado no barramento para estabilizar antes do próximo posedge
            d_word_addr = vif.dr_cb.data_addr.u_data >> 2;
            if (data_mem.exists(d_word_addr)) begin
                `uvm_info(get_full_name(), $sformatf("Serving Read data %0h from addr %0d", data_mem[d_word_addr], vif.dr_cb.data_addr.u_data), UVM_LOW);
                vif.dr_cb.data_rd.u_data <= data_mem[d_word_addr];
            end else begin
                vif.dr_cb.data_rd.u_data <= 0;
            end
        end else begin
            // Libera stall: sinal data_rd agora está estável
            vif.dr_cb.data_ready <= 1;
            data_ready_delay = 0;
        end
      end else if (vif.dr_cb.data_wr_en_ma) begin
        // Escrita também tem 1 ciclo de latência
        if (data_ready_delay == 0) begin
            vif.dr_cb.data_ready <= 0;
            data_ready_delay = 1;
            d_word_addr = vif.dr_cb.data_addr.u_data >> 2;
            `uvm_info(get_full_name(), $sformatf("Accepting Data Write %0h to addr %0d", vif.dr_cb.data_wr.u_data, vif.dr_cb.data_addr.u_data), UVM_LOW);
            data_mem[d_word_addr] = vif.dr_cb.data_wr.u_data;
        end else begin
            vif.dr_cb.data_ready <= 1;
            data_ready_delay = 0;
        end
      end else begin
        vif.dr_cb.data_ready <= 1;
        data_ready_delay = 0;
      end
      
    end
  endtask

  task reset();
    vif.dr_cb.inst_ready <= 1;
    vif.dr_cb.inst_data.memory_w <= 0;
    vif.dr_cb.data_ready <= 1;
    vif.dr_cb.data_rd.u_data <= 0;
  endtask

endclass : riscv_small_driver

`endif
