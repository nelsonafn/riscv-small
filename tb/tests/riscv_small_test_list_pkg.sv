//------------------------------------------------------------------------------
// Package for aggregating riscv_small tests
//------------------------------------------------------------------------------
// This package includes all the tests for the riscv_small simulation.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : October 2023
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_TEST_LIST_PKG
`define RISCV_SMALL_TEST_LIST_PKG

package riscv_small_test_list_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import riscv_small_env_pkg::*;
  import riscv_small_seq_list_pkg::*;

  /*
   * Including basic test definition
   */
  `include "riscv_small_basic_load_store_test.sv"
  `include "riscv_small_corner_test.sv"

endpackage 

`endif





