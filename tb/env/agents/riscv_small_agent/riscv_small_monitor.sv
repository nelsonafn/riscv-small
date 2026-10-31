`ifndef RISCV_SMALL_MONITOR
`define RISCV_SMALL_MONITOR

// ============================================================================
// riscv_small_monitor
//
// Observes the DUT ports and publishes what it saw -- fetch AND data -- on the
// analysis port. It never drives, never judges and never holds the verdict.
//
// `trace` (+TRACE) prints one line per event. It is off by default because one
// sanity image is thousands of fetches and the `SANITY:` verdict must stay
// readable in the same log.
// ============================================================================
class riscv_small_monitor extends uvm_monitor;
  virtual riscv_small_interface.mon_mp vif;
  uvm_analysis_port#(riscv_small_transaction) mon2sb_port;
  `uvm_component_utils(riscv_small_monitor)

  bit trace;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual riscv_small_interface)::get(this, "", "intf", vif))
      `uvm_fatal("NO_VIF",{"virtual interface must be set for: ",get_full_name(),".vif"});
    if (!uvm_config_db#(bit)::get(this, "", "trace", trace))
      trace = 0;
    mon2sb_port = new("mon2sb_port", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk);
      
      // Capture instruction fetch transaction
      if(vif.inst_rd_en && vif.inst_ready) begin
        riscv_small_transaction trans = riscv_small_transaction::type_id::create("inst_trans");
        trans.op_is_inst = 1;
        trans.captured_inst_addr = vif.inst_addr;
        trans.captured_inst_data = vif.inst_data.memory_w;
        if (trace)
          `uvm_info("FETCH_MONITOR", $sformatf("READ_INST: PC=0x%0h INST=0x%0h", trans.captured_inst_addr, trans.captured_inst_data), UVM_LOW);
        mon2sb_port.write(trans);
      end

      // Capture every data transaction (zero-latency: every cycle with en=1 is valid)
      if(vif.data_rd_en || vif.data_wr_en) begin
        riscv_small_transaction trans = riscv_small_transaction::type_id::create("trans");
        trans.op_is_data_read = vif.data_rd_en;
        trans.op_is_data_write = vif.data_wr_en;
        trans.captured_data_addr = vif.data_addr.u_data;
        trans.captured_data_rd = vif.data_rd.u_data;
        trans.captured_data_wr = vif.data_wr.u_data;
        trans.captured_data_wr_ctrl = vif.data_rd_wr_ctrl;

        if (trace)
          `uvm_info("DATA_MONITOR", $sformatf("DATA %s: ADDR=0x%0h DATA=0x%0h WIDTH=%0d",
            trans.op_is_data_write ? "WRITE" : "READ",
            trans.captured_data_addr,
            trans.op_is_data_write ? trans.captured_data_wr : trans.captured_data_rd,
            trans.captured_data_wr_ctrl), UVM_LOW);
        mon2sb_port.write(trans);
      end
    end
  endtask

endclass : riscv_small_monitor

`endif
