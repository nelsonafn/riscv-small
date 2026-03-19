`ifndef RISCV_SMALL_TRANSACTION 
`define RISCV_SMALL_TRANSACTION

class riscv_small_transaction extends uvm_sequence_item;

  /*
   * For the memory-mapped environment, we can pass initialization
   * lists (program) to the driver.
   */
  int instruction_addr [];
  int instruction_list [];
  
  int data_addr [];
  int data_list [];

  /*
   * For the monitor to capture what happened, we can capture a single cycle 
   * of transaction or memory operations.
   */
  bit op_is_inst;
  int captured_inst_addr;
  int captured_inst_data;

  bit op_is_data_read;
  bit op_is_data_write;
  int captured_data_addr;
  int captured_data_rd;
  int captured_data_wr;

  `uvm_object_utils_begin(riscv_small_transaction)
    `uvm_field_array_int(instruction_addr, UVM_ALL_ON)
    `uvm_field_array_int(instruction_list, UVM_ALL_ON)
    `uvm_field_array_int(data_addr, UVM_ALL_ON)
    `uvm_field_array_int(data_list, UVM_ALL_ON)
    `uvm_field_int(op_is_inst, UVM_ALL_ON)
    `uvm_field_int(captured_inst_addr, UVM_ALL_ON)
    `uvm_field_int(captured_inst_data, UVM_ALL_ON)
    `uvm_field_int(op_is_data_read, UVM_ALL_ON)
    `uvm_field_int(op_is_data_write, UVM_ALL_ON)
    `uvm_field_int(captured_data_addr, UVM_ALL_ON)
    `uvm_field_int(captured_data_rd, UVM_ALL_ON)
    `uvm_field_int(captured_data_wr, UVM_ALL_ON)
  `uvm_object_utils_end
   
  function new(string name = "riscv_small_transaction");
    super.new(name);
  endfunction

endclass

`endif
