//------------------------------------------------------------------------------
// Package for riscv_small environment classes
//------------------------------------------------------------------------------
// This package includes the environment classes and declarations for the riscv_small verification.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : October 2023
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_ENV_PKG
`define RISCV_SMALL_ENV_PKG

package riscv_small_env_pkg;
   
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import riscv_definitions_pkg::*;

  /*
   * Importing packages: agent, ref model, register, etc.
   */
  import riscv_small_agent_pkg::*;
  import riscv_small_ref_model_pkg::*;

  /*
   * Include top env files 
   */
  `include "riscv_small_coverage.sv"
  `include "riscv_small_scoreboard.sv"
  `include "riscv_small_env.sv"

endpackage

`endif


