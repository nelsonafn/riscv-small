//------------------------------------------------------------------------------
// Package for riscv_small reference model components
//------------------------------------------------------------------------------
// This package includes the reference model components for the riscv_small verification.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : October 2023
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_REF_MODEL_PKG
`define RISCV_SMALL_REF_MODEL_PKG

package riscv_small_ref_model_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import riscv_definitions_pkg::*;

  /*
   * Importing packages: agent, ref model, register, etc.
   */
  import riscv_small_agent_pkg::*;

  /*
   * Include ref model files: the program image is configuration both the
   * reference model and the top-level checkers read, so it lives here (the
   * package every consumer already imports) and comes before its users.
   */
  `include "riscv_small_program_image.sv"
  `include "riscv_small_ref_model.sv"

endpackage

`endif



