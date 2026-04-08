`ifndef RISCV_SMALL_DRIVER
`define RISCV_SMALL_DRIVER

class riscv_small_driver extends uvm_driver #(riscv_small_transaction);

  virtual riscv_small_interface.drv vif;
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
      vif.dr_cb.inst_data.memory_w <= inst_mem[0];
    end

    seq_item_port.item_done();
    `uvm_info("DRIVER", "Sequence item sent to the ref model", UVM_LOW)

    // 2. Play memory behavior
    fork
      // --- Processo de Busca de Instrução (Combinatorial) ---
      forever begin
        @(vif.dr_cb);
        vif.dr_cb.inst_ready <= 0;
        if (vif.dr_cb.inst_rd_en) begin
          int pc_word_addr = vif.dr_cb.inst_addr >> 2;
          //`uvm_info("DRIVER", $sformatf("Driver read instruction: PC=0x%0h INST=0x%0h", vif.dr_cb.inst_addr, inst_mem[pc_word_addr]), UVM_LOW)
          if (inst_mem.exists(pc_word_addr)) begin
            vif.dr_cb.inst_data.memory_w <= inst_mem[pc_word_addr];
            vif.dr_cb.inst_ready <= 1;
            `uvm_info("FETCH_DRIVER", $sformatf("READ_INST: PC=0x%0h INST=0x%0h", vif.dr_cb.inst_addr, inst_mem[pc_word_addr]), UVM_HIGH);
          end else begin
            vif.dr_cb.inst_data.memory_w <= 32'h00000033;
            vif.dr_cb.inst_ready <= 0;
            `uvm_warning("FETCH_DRIVER", $sformatf("READ_NOP: PC=0x%0h is out of range", vif.dr_cb.inst_addr));
          end
        end
      end

      // --- Processo de Acesso a Dados (Combinatorial) ---
      forever begin
        @(vif.dr_cb);
        vif.dr_cb.data_ready <= 0;
        //@(vif.dr_cb.data_addr or vif.dr_cb.data_rd_en_ma or vif.dr_cb.data_wr_en_ma or vif.dr_cb.data_wr);
        if (vif.dr_cb.data_rd_en_ma) begin
          int d_word_addr = vif.dr_cb.data_addr.u_data >> 2;
          if (data_mem.exists(d_word_addr)) begin
            vif.dr_cb.data_rd.u_data <= data_mem[d_word_addr];
            vif.dr_cb.data_ready <= 1;
            `uvm_info("DATA_DRIVER", $sformatf("READ_DATA: ADDR=0x%0h DATA=0x%0h", vif.dr_cb.data_addr.u_data, data_mem[d_word_addr]), UVM_HIGH);
          end else begin
            vif.dr_cb.data_rd.u_data <= 0;
            vif.dr_cb.data_ready <= 0;
            `uvm_warning("DATA_DRIVER", $sformatf("READ_DATA: ADDR=0x%0h is out of range", vif.dr_cb.data_addr.u_data));
          end
        end
        
        if (vif.dr_cb.data_wr_en_ma) begin
          int d_word_addr = vif.dr_cb.data_addr.u_data >> 2;
          if (data_mem.exists(d_word_addr)) begin
            data_mem[d_word_addr] = vif.dr_cb.data_wr.u_data;
            vif.dr_cb.data_ready <= 1;
            `uvm_info("DATA_DRIVER", $sformatf("WRITE_DATA: ADDR=0x%0h DATA=0x%0h", vif.dr_cb.data_addr.u_data, vif.dr_cb.data_wr.u_data), UVM_HIGH);
          end else begin
            vif.dr_cb.data_ready <= 0;
            `uvm_warning("DATA_DRIVER", $sformatf("WRITE_DATA: ADDR=0x%0h is out of range", vif.dr_cb.data_addr.u_data));
          end
        end
      end

      // --- Processo de Sinais de Controle (Síncrono via dr_cb) ---
      //forever begin
      //  @(vif.dr_cb);
      //  vif.dr_cb.inst_ready <= 1;
      //  vif.dr_cb.data_ready <= 1;
      //end
    join
  endtask

  task reset();
    vif.dr_cb.inst_ready <= 0;
    vif.dr_cb.inst_data.memory_w <= 0;
    vif.dr_cb.data_ready <= 0;
    vif.dr_cb.data_rd.u_data <= 0;
  endtask

endclass : riscv_small_driver

`endif
