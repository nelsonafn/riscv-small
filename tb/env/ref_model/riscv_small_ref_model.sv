`ifndef RISCV_SMALL_REF_MODEL
`define RISCV_SMALL_REF_MODEL

// ============================================================================
// riscv_small_ref_model
//
// UVM Reference Model (ISS - Instruction Set Simulator).
// Receives the complete subprogram (instructions + initial memory state) from 
// the Driver via rm_export, executes an internal ISS, and publishes a 
// "prediction" transaction for each found SW instruction, via rm2sb_port to 
// the Scoreboard. The Scoreboard compares these predictions with the actual 
// observations from the Monitor coming from the DUT.
//
// Author: Nelson Alves nelsonafn@gmail.com
// ============================================================================
class riscv_small_ref_model extends uvm_component;
  
  `uvm_component_utils(riscv_small_ref_model)

  // ---- TLM Ports -----------------------------------------------------------
  // Input: subprogram sent by the Driver
  uvm_analysis_export #(riscv_small_transaction) rm_export;
  uvm_tlm_analysis_fifo #(riscv_small_transaction) rm_fifo;
  // Output: store predictions for the Scoreboard
  uvm_analysis_port #(riscv_small_transaction) rm2sb_port;

  // ---- Constructor ---------------------------------------------------------
  function new(string name = "riscv_small_ref_model", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build phase ---------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    rm_fifo    = new("rm_fifo", this);
    rm_export  = new("rm_export", this);
    rm2sb_port = new("rm2sb_port", this);
  endfunction

  // ---- Connect phase -------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    rm_export.connect(rm_fifo.analysis_export);
  endfunction

  // ---- Run phase: Main ISS -------------------------------------------------
  virtual task run_phase(uvm_phase phase);
    riscv_small_transaction subprog; // subprogram received from the Driver

    forever begin
      // 1. Wait for subprogram from the Driver
      rm_fifo.get(subprog);
      `uvm_info(get_full_name(),
        $sformatf("ISS: Subprogram received — %0d instructions, %0d data positions",
          subprog.instruction_list.size(), subprog.data_addr.size()),
        UVM_LOW)

      // 2. Initialize internal ISS state
      begin
        int reg_file[32];   // Register file (x0..x31)
        int iss_mem[int];   // Data memory (word address)

        for (int i = 0; i < 32; i++) reg_file[i] = 0; // x0 is always zero

        // Populate memory with initial data (converted to word address)
        foreach (subprog.data_addr[i])
          iss_mem[subprog.data_addr[i] >> 2] = subprog.data_list[i];

        // 3. Simulate each instruction in the subprogram
        foreach (subprog.instruction_list[i]) begin
          bit [31:0] inst   = subprog.instruction_list[i];
          bit [6:0]  opcode = inst[6:0];

          // --- LW (I-Type, opcode=0000011) ----------------------------------
          if (opcode == 7'b0000011) begin
            bit [4:0]  rd  = inst[11:7];
            bit [4:0]  rs1 = inst[19:15];
            bit [11:0] imm = inst[31:20];
            int word_addr  = (reg_file[rs1] + $signed(imm)) >> 2;

            if (rd != 0) begin
              reg_file[rd] = iss_mem.exists(word_addr) ? iss_mem[word_addr] : 0;
              `uvm_info(get_full_name(),
                $sformatf("ISS LW: x%0d ← mem_word[%0d] = 0x%0h",
                  rd, word_addr, reg_file[rd]),
                UVM_MEDIUM)
            end

          // --- SW (S-Type, opcode=0100011) ----------------------------------
          end else if (opcode == 7'b0100011) begin
            bit [4:0]  rs2 = inst[24:20];
            bit [4:0]  rs1 = inst[19:15];
            bit [11:0] imm = {inst[31:25], inst[11:7]};
            int word_addr  = (reg_file[rs1] + $signed(imm)) >> 2;
            int byte_addr  = word_addr << 2;

            iss_mem[word_addr] = reg_file[rs2];
            `uvm_info(get_full_name(),
              $sformatf("ISS SW: x%0d (=0x%0h) → mem_byte[%0d] / mem_word[%0d]",
                rs2, reg_file[rs2], byte_addr, word_addr),
              UVM_MEDIUM)

            // Publish prediction to the Scoreboard
            begin
              riscv_small_transaction pred;
              pred = riscv_small_transaction::type_id::create("pred");
              pred.op_is_data_write    = 1;
              pred.op_is_data_read     = 0;
              pred.captured_data_addr  = byte_addr;
              pred.captured_data_wr    = reg_file[rs2];
              // Also load the subprogram for printing in the Scoreboard
              pred.instruction_list    = subprog.instruction_list;
              pred.data_addr           = subprog.data_addr;
              pred.data_list           = subprog.data_list;
              rm2sb_port.write(pred);
            end
          end
          // Other opcodes (NOP, etc.) are ignored by the ISS
        end // foreach instruction

        `uvm_info(get_full_name(), "ISS: Subprogram completed.", UVM_LOW)
      end
    end // forever
  endtask : run_phase

endclass : riscv_small_ref_model

`endif
