//------------------------------------------------------------------------------
// Package for riscv_small agent components
//------------------------------------------------------------------------------
// This package includes the components and declarations for the riscv_small agent.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : October 2023
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_AGENT_PKG
`define RISCV_SMALL_AGENT_PKG

package riscv_small_agent_pkg;
 
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import riscv_definitions_pkg::*;

  /*
   * Include Agent components: driver, monitor, sequencer
   */
  `include "riscv_small_defines.svh"
  `include "riscv_small_transaction.sv"
  `include "riscv_small_sequencer.sv"
  `include "riscv_small_driver.sv"
  `include "riscv_small_monitor.sv"
  `include "riscv_small_agent.sv"

endpackage

`endif



