`ifndef RISCV_SMALL_MONITOR
`define RISCV_SMALL_MONITOR

class riscv_small_monitor extends uvm_monitor;
  virtual riscv_small_interface vif;
  uvm_analysis_port#(riscv_small_transaction) mon2sb_port;
  `uvm_component_utils(riscv_small_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual riscv_small_interface)::get(this, "", "intf", vif))
      `uvm_fatal("NO_VIF",{"virtual interface must be set for: ",get_full_name(),".vif"});
    mon2sb_port = new("mon2sb_port", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(vif.rc_cb);
      
      // Capturar transação de busca de instrução
      if(vif.rc_cb.inst_rd_en && vif.rc_cb.inst_ready) begin
        riscv_small_transaction trans = riscv_small_transaction::type_id::create("inst_trans");
        trans.op_is_inst = 1;
        trans.captured_inst_addr = vif.rc_cb.inst_addr;
        trans.captured_inst_data = vif.rc_cb.inst_data.memory_w;
        `uvm_info(get_full_name(), $sformatf("FETCH MONITOR: PC=0x%0h INST=0x%0h", trans.captured_inst_addr, trans.captured_inst_data), UVM_HIGH);
        // mon2sb_port.write(trans); // Opcional: enviar para SB se necessário
      end

      // Capturar toda transação de dado (zero-latência: cada ciclo com en=1 é válido)
      if(vif.rc_cb.data_rd_en_ma || vif.rc_cb.data_wr_en_ma) begin
        riscv_small_transaction trans = riscv_small_transaction::type_id::create("trans");
        trans.op_is_data_read = vif.rc_cb.data_rd_en_ma;
        trans.op_is_data_write = vif.rc_cb.data_wr_en_ma;
        trans.captured_data_addr = vif.rc_cb.data_addr.u_data;
        trans.captured_data_rd = vif.rc_cb.data_rd.u_data;
        trans.captured_data_wr = vif.rc_cb.data_wr.u_data;

        `uvm_info(get_full_name(), $sformatf("DATA MONITOR: %s addr=0x%0h data=0x%0h", 
          trans.op_is_data_write ? "WRITE" : "READ", 
          trans.captured_data_addr, 
          trans.op_is_data_write ? trans.captured_data_wr : trans.captured_data_rd), UVM_LOW);
        mon2sb_port.write(trans);
      end
    end
  endtask

endclass : riscv_small_monitor

`endif
