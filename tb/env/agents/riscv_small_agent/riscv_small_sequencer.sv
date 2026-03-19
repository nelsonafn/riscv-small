//------------------------------------------------------------------------------
// Sequencer module for riscv_small agent
//------------------------------------------------------------------------------
// This module defines the sequencer for the riscv_small agent.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : October 2023
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_SEQUENCER
`define RISCV_SMALL_SEQUENCER

class riscv_small_sequencer extends uvm_sequencer#(riscv_small_transaction);
 
  `uvm_component_utils(riscv_small_sequencer)
 
  /*
   * Constructor
   */
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
   
endclass

`endif




