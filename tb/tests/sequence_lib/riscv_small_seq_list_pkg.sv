//------------------------------------------------------------------------------
// Package for listing riscv_small sequences
//------------------------------------------------------------------------------
// This package includes the basic sequence for the riscv_small testbench.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : October 2023
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_SEQ_LIST_PKG 
`define RISCV_SMALL_SEQ_LIST_PKG

package riscv_small_seq_list_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import riscv_definitions_pkg::*;

  import riscv_small_agent_pkg::*;
  import riscv_small_ref_model_pkg::*;
  import riscv_small_env_pkg::*;

  /*
   * Including basic sequence definition
   */
  `include "riscv_small_defines.svh"
  `include "riscv_small_basic_load_store_seq.sv"
  `include "riscv_small_corner_seq.sv"

endpackage

`endif
