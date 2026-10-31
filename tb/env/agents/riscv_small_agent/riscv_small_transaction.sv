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
   * Program item for the image/ISA path: the sequence owns the file and builds
   * the memory image here, so the driver only loads words and answers the bus.
   * `program_addr` is a byte address, `program_data` the 32-bit word.
   */
  int program_addr [];
  int program_data [];

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
  int captured_data_wr_ctrl;

  `uvm_object_utils_begin(riscv_small_transaction)
    `uvm_field_array_int(instruction_addr, UVM_ALL_ON)
    `uvm_field_array_int(instruction_list, UVM_ALL_ON)
    `uvm_field_array_int(data_addr, UVM_ALL_ON)
    `uvm_field_array_int(data_list, UVM_ALL_ON)
    `uvm_field_array_int(program_addr, UVM_ALL_ON)
    `uvm_field_array_int(program_data, UVM_ALL_ON)
    `uvm_field_int(op_is_inst, UVM_ALL_ON)
    `uvm_field_int(captured_inst_addr, UVM_ALL_ON)
    `uvm_field_int(captured_inst_data, UVM_ALL_ON)
    `uvm_field_int(op_is_data_read, UVM_ALL_ON)
    `uvm_field_int(op_is_data_write, UVM_ALL_ON)
    `uvm_field_int(captured_data_addr, UVM_ALL_ON)
    `uvm_field_int(captured_data_rd, UVM_ALL_ON)
    `uvm_field_int(captured_data_wr, UVM_ALL_ON)
    `uvm_field_int(captured_data_wr_ctrl, UVM_ALL_ON)
  `uvm_object_utils_end
   
  function new(string name = "riscv_small_transaction");
    super.new(name);
  endfunction

endclass

`endif
