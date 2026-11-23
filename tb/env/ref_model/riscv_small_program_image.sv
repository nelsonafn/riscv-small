//------------------------------------------------------------------------------
// Program image: the program as CONFIGURATION, never as a transaction
//------------------------------------------------------------------------------
// The image carries the two things an oracle needs to predict what the core
// should do, and nothing else:
//
//   inst[byte_pc]  the word the program placed at that instruction address
//   data[byte_a]   the initial word of the data memory at that address
//
// It is created by the test, filled in by the sequence that builds the program,
// and handed to the checkers and to the reference model through uvm_config_db.
// It is not an analysis port and it is not a stream: it is state that is
// written once, before the DUT starts, and only read afterwards. The DUT's own
// memory mutations are never written back here -- they are observed on the
// monitor -- so a reader cannot see the memory the driver mutates (C-16,
// AGENTS.md testbench responsibility 9).
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_PROGRAM_IMAGE
`define RISCV_SMALL_PROGRAM_IMAGE

class riscv_small_program_image extends uvm_object;

  `uvm_object_utils(riscv_small_program_image)

  // Byte address -> word. Associative arrays, so the image costs nothing for
  // the addresses the program does not use (the data image of the directed
  // programs sits at 0x190..0x790).
  bit [31:0] inst [int unsigned];
  bit [31:0] data [int unsigned];

  // The instruction addresses in the order the program placed them. The image
  // is the program's static order, so a checker can say "the first retire event
  // is the program's first instruction" without owning a program of its own.
  bit [31:0] inst_order [$];

  // Control-flow structure, also configuration: the addresses the program's
  // branches skip over. A commit at one of them is a defect (the core executed
  // an instruction the program did not), so the retire checker can assert the
  // absence by name instead of only noticing that the counts disagree.
  //
  // commit_target() is therefore "placed instructions minus the ones the
  // control flow skips". That is exact for a straight-line program and for a
  // forward skip; a program that loops or re-executes an address needs an
  // execution count declared by its sequence, which nothing in this corpus
  // does yet.
  bit [31:0] skip_pc [$];

  // A placed instruction the TRAP path removes from the commit stream
  // (WP-14b, FR-22): the instruction that traps is flushed before write-back
  // and never retires, so "every placed word retires" is false for exactly
  // these addresses. The sequence declares them, and the retire checker then
  // asserts BOTH halves: none of them ever retires, and every OTHER placed word
  // does -- which is what turns "no instruction was lost" into a claim instead
  // of a count that silently tolerates the difference.
  bit [31:0] no_retire_pc [$];

  function new(string name = "riscv_small_program_image");
    super.new(name);
  endfunction

  // ---- Build side: the sequence that owns the program fills these in --------

  function void add_inst(bit [31:0] byte_addr, bit [31:0] word);
    if (!inst.exists(byte_addr)) inst_order.push_back(byte_addr);
    inst[byte_addr] = word;
  endfunction

  function void add_data(bit [31:0] byte_addr, bit [31:0] word);
    data[byte_addr] = word;
  endfunction

  // An instruction address the program's control flow never executes. The
  // sequence that built the branch declares it; the checker proves it silent.
  function void add_skip(bit [31:0] byte_addr);
    if (!is_skipped(byte_addr)) skip_pc.push_back(byte_addr);
  endfunction

  function bit is_skipped(bit [31:0] byte_addr);
    foreach (skip_pc[i])
      if (skip_pc[i] == byte_addr) return 1'b1;
    return 1'b0;
  endfunction

  // The instruction that occupies this address TRAPS: it must not retire.
  // Declared by the sequence that placed the trap site (WP-14b, FR-22/D12).
  function void add_no_retire(bit [31:0] byte_addr);
    if (!is_no_retire(byte_addr)) no_retire_pc.push_back(byte_addr);
  endfunction

  function bit is_no_retire(bit [31:0] byte_addr);
    foreach (no_retire_pc[i])
      if (no_retire_pc[i] == byte_addr) return 1'b1;
    return 1'b0;
  endfunction

  // ---- Read side: checkers and the reference model --------------------------

  // One accessor per question, so a caller never has to know that a missing
  // key is a zero word: `found` is the answer, `word` is only valid with it.
  function bit lookup_inst(bit [31:0] byte_addr, output bit [31:0] word);
    if (!inst.exists(byte_addr)) return 1'b0;
    word = inst[byte_addr];
    return 1'b1;
  endfunction

  function bit lookup_data(bit [31:0] byte_addr, output bit [31:0] word);
    if (!data.exists(byte_addr)) return 1'b0;
    word = data[byte_addr];
    return 1'b1;
  endfunction

  function int unsigned inst_size();
    return inst.num();
  endfunction

  // How many instructions the program executes: everything it placed, minus the
  // addresses its control flow skips and minus the instructions its traps
  // remove from the commit stream.
  function int unsigned commit_target();
    return inst.num() - skip_pc.size() - no_retire_pc.size();
  endfunction

  function int unsigned data_size();
    return data.num();
  endfunction

endclass

`endif
