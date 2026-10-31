//------------------------------------------------------------------------------
// UVM agent for riscv_small transactions
//------------------------------------------------------------------------------
// This agent handles the driver, monitor, and sequencer for riscv_small transactions.
//
// is_active selects the topology: UVM_ACTIVE builds monitor + driver +
// sequencer, UVM_PASSIVE builds the monitor only (observation). The driver and
// sequencer are created and connected only when the agent is active.
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
   *
   * is_active defaults to UVM_ACTIVE; a passive environment builds the monitor
   * only, so there is no driver and no sequence.
   */
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(uvm_active_passive_enum)::get(this, "", "is_active", is_active))
      is_active = UVM_ACTIVE;
    monitor = riscv_small_monitor::type_id::create("monitor", this);
    if (is_active == UVM_ACTIVE) begin
      driver = riscv_small_driver::type_id::create("driver", this);
      sequencer = riscv_small_sequencer::type_id::create("sequencer", this);
    end
  endfunction : build_phase

  /*
   * Connect phase: connect TLM ports and exports (e.g., analysis port/exports)
   *
   * is_active decides what exists; connect what exists. A null check is the
   * same rule in a legal passive agent, and it keeps a topology defect from
   * crashing on an unconnected port before the test can report it.
   */
  function void connect_phase(uvm_phase phase);
    if (driver != null && sequencer != null)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction : connect_phase
 
endclass : riscv_small_agent

`endif
