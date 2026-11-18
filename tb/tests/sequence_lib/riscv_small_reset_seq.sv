//------------------------------------------------------------------------------
// Reset-vector sequence for riscv_small (WP-11 P2/P3a: FR-41 / G-33)
//------------------------------------------------------------------------------
// The program item is born HERE (TB responsibility 1): the reset vector is
// read from configuration, never from the DUT and never from a literal, and the
// single word below is the whole stimulus.
//
// The program is placed AT the reset vector -- the first address the core
// presents after reset -- so the memory BFM answers the first fetch and the
// checker (riscv_small_reset_checker) judges which address it was. P3 removed
// the 0x0/0x4/0x8 guard words P2 needed while the core still reset at 0: there
// is no second address to answer any more, and the guard was not part of the
// claim.
//
// The sequence does NOT drive reset: `rst_n` is a testbench-top signal and the
// driver's modport has it as an input. The top holds it low for five cycles, so
// the hold and the release are the top's, and this sequence only waits for the
// item to be consumed.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_RESET_SEQ
`define RISCV_SMALL_RESET_SEQ

class riscv_small_reset_seq extends uvm_sequence #(riscv_small_transaction);

  `uvm_object_utils(riscv_small_reset_seq)

  // NOP: ADD x0, x0, x0. Any legal word retires; the claim is the address.
  localparam bit [31:0] NOP = 32'h00000033;

  function new (string name = "riscv_small_reset_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] reset_vector;

    // Configuration, not stimulus: the value the DUT elaborated with was
    // published by the testbench top. A missing value is a test defect.
    if (!uvm_config_db#(bit [31:0])::get(m_sequencer, "", "reset_vector", reset_vector)) begin
      `uvm_fatal("RESET_VECTOR",
        "no reset_vector was published by the testbench top; the program cannot be placed")
      return;
    end

    req = riscv_small_transaction::type_id::create("req");
    req.instruction_addr = new[1];
    req.instruction_list = new[1];

    // One word, at RESET_VECTOR: the first fetch after reset presents exactly
    // this address. It is also the last address the directed driver's end
    // detector keys on, so the item completes when the core actually fetches
    // the reset vector. On a core that resets elsewhere the fetch is never
    // answered and the run is ended by the checker's verdict and the test's
    // timeout, not by the BFM.
    req.instruction_addr[0] = reset_vector;
    req.instruction_list[0] = NOP;
    `uvm_info("RESET_SEQ",
      $sformatf("program word at RESET_VECTOR 0x%08h (NOP 0x%08h)", reset_vector, NOP),
      UVM_LOW)

    start_item(req);
    finish_item(req);
  endtask

endclass

`endif
