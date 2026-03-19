`ifndef RISCV_SMALL_COVERAGE
`define RISCV_SMALL_COVERAGE

class riscv_small_coverage extends uvm_subscriber #(riscv_small_transaction);
  `uvm_component_utils(riscv_small_coverage)

  riscv_small_transaction cov_trans;

  covergroup cg_sum;
    // Empty covergroup to prevent compile errors
  endgroup: cg_sum

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_sum = new();
  endfunction: new

  function void write(riscv_small_transaction t);
    $cast(cov_trans, t);
    cg_sum.sample();
  endfunction: write

endclass: riscv_small_coverage

`endif
