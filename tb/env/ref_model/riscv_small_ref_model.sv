`ifndef RISCV_SMALL_REF_MODEL 
`define RISCV_SMALL_REF_MODEL

class riscv_small_ref_model extends uvm_component;
  
  `uvm_component_utils(riscv_small_ref_model)
  uvm_analysis_export #(riscv_small_transaction) rm_export;
  uvm_tlm_analysis_fifo #(riscv_small_transaction) rm_fifo;
  uvm_analysis_port #(riscv_small_transaction) rm2sb_port;

  function new(string name="riscv_small_ref_model", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    rm_fifo = new("rm_fifo", this);
    rm_export = new("rm_export", this);
    rm2sb_port = new("rm2sb_port", this);
  endfunction
  
  function void connect_phase(uvm_phase phase);
    rm_export.connect(rm_fifo.analysis_export);
  endfunction

  virtual task run_phase(uvm_phase phase);
    riscv_small_transaction trans;
    forever begin
      rm_fifo.get(trans);
      // Dummy ref model, passes transaction to scoreboard to avoid deadlocks.
      // (The actual scoreboard does internal validation here)
      rm2sb_port.write(trans);
    end
  endtask

endclass

`endif
