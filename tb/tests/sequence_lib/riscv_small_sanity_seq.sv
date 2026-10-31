//------------------------------------------------------------------------------
// Sanity program-item sequence for riscv_small
//------------------------------------------------------------------------------
// The sequence owns the image: it reads `hex_file` (+HEX, supplied by the
// test), builds the program item (program_addr[] / program_data[]) and sends it
// to the driver. The driver only loads it and answers the bus; it never reads a
// file, never sees `tohost` and never decides the verdict.
//
// Only non-X, non-zero words are kept: the driver clears its memory before
// loading, so an absent word reads as 0 exactly as $readmemh would leave it.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : October 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_SANITY_SEQ
`define RISCV_SMALL_SANITY_SEQ

class riscv_small_sanity_seq extends uvm_sequence #(riscv_small_transaction);

  `uvm_object_utils(riscv_small_sanity_seq)

  // Image file, read here and never by the driver.
  string hex_file;

  function new (string name = "riscv_small_sanity_seq");
    super.new(name);
  endfunction

  virtual task body();
    logic [31:0] image [0:65535];

    if (hex_file == "")
      `uvm_fatal("SANITY_SEQ", "no hex_file: the test must set seq.hex_file from +HEX")

    foreach (image[i]) image[i] = '0;
    $readmemh(hex_file, image);

    req = riscv_small_transaction::type_id::create("req");
    begin
      int count = 0;
      // XSim rejects push_back() on a dynamic array, so size the item first.
      foreach (image[i])
        if (!$isunknown(image[i]) && image[i] != 0) count++;
      req.program_addr = new[count];
      req.program_data = new[count];
      count = 0;
      foreach (image[i]) begin
        if (!$isunknown(image[i]) && image[i] != 0) begin
          req.program_addr[count] = i * 4;
          req.program_data[count] = image[i];
          count++;
        end
      end
    end
    `uvm_info("SANITY_SEQ", $sformatf("image=%s program_words=%0d", hex_file, req.program_addr.size()), UVM_LOW)

    publish_program(req);
    start_item(req);
    finish_item(req);
  endtask

  // The reference model receives the program from here, never from the driver.
  // In sanity mode this port has no subscriber; the write is harmless.
  function void publish_program(riscv_small_transaction item);
    uvm_analysis_port#(riscv_small_transaction) program_port;
    if (uvm_config_db#(uvm_analysis_port#(riscv_small_transaction))::get(m_sequencer, "", "program_port", program_port))
      program_port.write(item);
  endfunction

endclass

`endif
