//------------------------------------------------------------------------------
// UVM agent for riscv_small transactions
//------------------------------------------------------------------------------
// This agent handles the driver, monitor, and sequencer for riscv_small transactions.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : October 2023
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_AGENT 
`define RISCV_SMALL_AGENT

class riscv_small_agent extends uvm_agent;

  /*
   * Declaration of UVC components such as driver, monitor, sequencer, etc.
   */
  riscv_small_driver    driver;
  riscv_small_sequencer sequencer;
  riscv_small_monitor   monitor;

  /*
   * Declaration of component utils 
   */
  `uvm_component_utils(riscv_small_agent)

  /*
   * Constructor
   */
  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  /*
   * Build phase: construct the components such as driver, monitor, sequencer, etc.
   */
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    driver = riscv_small_driver::type_id::create("driver", this);
    sequencer = riscv_small_sequencer::type_id::create("sequencer", this);
    monitor = riscv_small_monitor::type_id::create("monitor", this);
  endfunction : build_phase

  /*
   * Connect phase: connect TLM ports and exports (e.g., analysis port/exports)
   */
  function void connect_phase(uvm_phase phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction : connect_phase
 
endclass : riscv_small_agent

`endif
