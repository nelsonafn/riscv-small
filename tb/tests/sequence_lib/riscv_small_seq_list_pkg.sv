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

  // The base address of every program this corpus builds. Its ONE source is
  // the value the testbench top published from the DUT's elaborated
  // RESET_VECTOR (`duv.RESET_VECTOR`, FR-41 / Q-33), so a sequence never holds
  // the spec's default and a second elaboration with another vector moves the
  // programs with it. The driver reads the same key to index its memory.
  function automatic bit [31:0] riscv_small_seq_mem_base(uvm_component ctx);
    bit [31:0] base;
    if (!uvm_config_db#(bit [31:0])::get(ctx, "", "reset_vector", base))
      `uvm_fatal("MEM_BASE",
        "no reset_vector was published by the testbench top: the program has no base address")
    return base;
  endfunction
  `include "riscv_small_basic_load_store_seq.sv"
  `include "riscv_small_corner_seq.sv"
  `include "riscv_small_subword_seq.sv"
  `include "riscv_small_halfword_lane_seq.sv"
  `include "riscv_small_store_grant_seq.sv"
  `include "riscv_small_csr_seq.sv"
  `include "riscv_small_trap_order_seq.sv"
  `include "riscv_small_external_trap_seq.sv"
  `include "riscv_small_trap_split_seq.sv"
  `include "riscv_small_branch_seq.sv"
  `include "riscv_small_skip3_seq.sv"
  `include "riscv_small_reset_seq.sv"
  `include "riscv_small_sanity_seq.sv"

endpackage

`endif
