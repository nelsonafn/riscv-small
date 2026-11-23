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
  import riscv_small_ref_model_pkg::*;
  import riscv_small_seq_list_pkg::*;

  /*
   * Including basic test definition
   */
  `include "riscv_small_base_test.sv"
  `include "riscv_small_basic_load_store_test.sv"
  `include "riscv_small_corner_test.sv"
  `include "riscv_small_subword_access_test.sv"
  `include "riscv_small_halfword_lane_test.sv"
  `include "riscv_small_store_grant_test.sv"
  `include "riscv_small_csr_test.sv"
  `include "riscv_small_trap_order_test.sv"
  `include "riscv_small_external_trap_test.sv"
  `include "riscv_small_trap_split_test.sv"
  `include "riscv_small_sanity_test.sv"
  `include "riscv_small_passive_test.sv"
  `include "riscv_small_monitor_model_test.sv"
  `include "riscv_small_branch_model_test.sv"
  `include "riscv_small_skip3_model_test.sv"
  `include "riscv_small_reset_vector_test.sv"

endpackage 

`endif





