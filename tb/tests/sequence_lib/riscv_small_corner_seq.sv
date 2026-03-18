//------------------------------------------------------------------------------
// Corner sequence for riscv_small
//------------------------------------------------------------------------------
// This sequence generates corner-case transactions for the riscv_small (zeros, maxes).
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : February 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_CORNER_SEQ 
`define RISCV_SMALL_CORNER_SEQ

class riscv_small_corner_seq extends riscv_small_basic_load_store_seq;
   
  /*
   * Declaration of sequence utilities
   */
  `uvm_object_utils(riscv_small_corner_seq)
 
  /*
   * Sequence constructor
   */
  function new(string name = "riscv_small_corner_seq");
    super.new(name);
  endfunction
 
  /*
   * Body method: Sends corner case transactions via the sequencer
   */
  virtual task body();
    super.body();
  endtask
   
endclass

`endif
