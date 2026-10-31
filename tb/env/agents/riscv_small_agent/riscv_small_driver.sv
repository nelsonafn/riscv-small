`ifndef RISCV_SMALL_DRIVER
`define RISCV_SMALL_DRIVER

// ============================================================================
// riscv_small_driver
//
// Memory BFM for the instruction and data ports. Two modes:
//
//   directed  the sequence item carries instruction_addr/instruction_list and
//             data_addr/data_list; the driver answers those addresses and ends
//             the item when the last instruction is fetched.
//   sanity    the sequence item carries the program image (program_addr/
//             program_data). The driver loads it into its memory, completes the
//             item and then answers every fetch/data access until the phase
//             ends.
//
// The driver never reads a plusarg, never decodes the pass/fail address, never
// decides PASS/FAIL, never raises a report error and never feeds the reference
// model. The verdict belongs to the checker (sanity) or the scoreboard
// (directed).
// ============================================================================
class riscv_small_driver extends uvm_driver #(riscv_small_transaction);

  virtual riscv_small_interface.drv_mp vif;
  `uvm_component_utils(riscv_small_driver)

  logic [31:0] inst_mem [int];
  logic [31:0] data_mem [int];
  localparam OUTPUT_DELAY = 2;
  localparam INPUT_DELAY = 1;
  localparam NOP = 32'h00000033;

  // ---------------------------------------------------------------------------
  // Image memory model (riscv_small_sanity_test)
  //
  // mem_mode is 0 unless the test publishes sanity_mode=1, so the directed
  // memory behaviour below is untouched. The model is word-granular: a store
  // writes the whole word, so LB/LH/LBU/LHU/SB/SH are NOT modelled. That is the
  // documented limit until FR-11/G-22 add byte strobes to the DUT
  // (`data_rd_wr_ctrl` is effectively one bit today).
  // ---------------------------------------------------------------------------
  bit          mem_mode;
  bit          trace;
  logic [31:0] mem [0:65535];   // 64K words = 256 KiB of image space

  bit warned_imem_range;
  bit warned_dmem_range;

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual riscv_small_interface)::get(this, "", "intf", vif))
      `uvm_fatal("NO_VIF",{"virtual interface must be set for: ",get_full_name(),".vif"});

    if (!uvm_config_db#(bit)::get(this, "", "sanity_mode", mem_mode))
      mem_mode = 0;
    if (!uvm_config_db#(bit)::get(this, "", "trace", trace))
      trace = 0;
  endfunction

  // TODO: Move to fv_utils_pkg package
  // Function to convert an array of integers to a hex-formatted string
  function automatic string to_hex_list(ref int vec[]);
    string s = "'h{";
    foreach (vec[i]) 
        s = {s, $sformatf("%0h%s", vec[i], (i == vec.size()-1) ? "" : ",")};
    return {s,"}"};
  endfunction

  virtual task run_phase(uvm_phase phase);
    reset();

    // The image path receives the pre-built program from the sequence and then
    // runs the memory responder; the directed path below is only reached when
    // sanity_mode was never published.
    if (mem_mode) begin
      run_image_mode();
      return;
    end

    // 1. Get initial test sequence transaction
    seq_item_port.get_next_item(req);
    req.print();
    // foreach (req.instruction_addr[i]) begin
    //   inst_mem[req.instruction_addr[i]] = req.instruction_list[i];
    // end
    // foreach (req.data_addr[i]) begin
    //   data_mem[req.data_addr[i]] = req.data_list[i];
    // end

    // Set PC=0 immediately before starting the main loop 
    // so that the first clock edge captures LW0 correctly.
    // if (inst_mem.exists(0)) begin
    //   vif.inst_data.memory_w <= inst_mem[0];
    // end

    // 2. Play memory behavior
    fork
      // Thread 1: Instruction
      forever begin : inst_mem_thread
        @(posedge vif.clk);
        vif.inst_ready <= #OUTPUT_DELAY 0; // Default
        if (vif.inst_rd_en) begin
          bit found = 0;
          foreach (req.instruction_addr[i]) begin
            if (req.instruction_addr[i] == vif.inst_addr) begin
              vif.inst_data.memory_w <= #OUTPUT_DELAY req.instruction_list[i];
              vif.inst_ready <= #OUTPUT_DELAY 1;
              `uvm_info("IFETCH_DRV", $sformatf("READ_INST: PC='h%0h INST='h%0h", vif.inst_addr, req.instruction_list[i]), UVM_LOW);
              found = 1;
              break;
            end
          end
          if (!found) begin
            vif.inst_data.memory_w <= #OUTPUT_DELAY NOP;
            `uvm_warning("IADDR_OOR_DRV", $sformatf("INST_OUT_OF_RANGE: PC='h%0h, INST_ADDREs=%s, INST_VECTOR=%s", vif.inst_addr, to_hex_list(req.instruction_addr), to_hex_list(req.instruction_list)));
          end
        end
      end
      // Thread 2: Data
      forever begin : data_mem_thread
        @(posedge vif.clk);
        vif.data_ready <= #INPUT_DELAY 0; // Default
        if (vif.data_rd_en || vif.data_wr_en) begin
          bit found = 0;
          foreach (req.data_addr[i]) begin
            if (req.data_addr[i] == vif.data_addr.u_data) begin
              if (vif.data_rd_en) begin
                vif.data_rd.u_data <= #INPUT_DELAY req.data_list[i];
                `uvm_info("DFETCH_DRV", $sformatf("ADDR='h%0h DATA='h%0h", vif.data_addr.u_data, req.data_list[i]), UVM_LOW);
              end else begin
                req.data_list[i] = vif.data_wr.u_data;
                `uvm_info("DSTORE_DRV", $sformatf("ADDR='h%0h DATA='h%0h", vif.data_addr.u_data, vif.data_wr.u_data), UVM_LOW);
              end
              vif.data_ready <= #INPUT_DELAY 1;
              found = 1;
              break;
            end
          end
          if (!found) begin
            `uvm_warning("DATA_OOR_DRV", $sformatf("ADDR_OUT_OF_RANGE: ADDR='h%0h, DATA_ADDRs=%s, DATA_VECTOR=%s, R/W=%s", vif.data_addr.u_data, to_hex_list(req.data_addr), to_hex_list(req.data_list), vif.data_rd_en ? "READ" : "WRITE"));
          end
        end
      end

      // Thread 3: Termination Detector
      begin : end_detector
        int last_addr = req.instruction_addr[req.instruction_addr.size()-1];
        `uvm_info("DRIVER", $sformatf("Waiting for last instruction address: 'h%0h, size: %d", last_addr, req.instruction_addr.size()), UVM_LOW)
        
        // Synchronously poll on the clock edge instead of wait() to avoid simulator evaluation issues
        forever begin
          @(posedge vif.clk);
          if (vif.inst_rd_en && (vif.inst_addr == last_addr)) break;
        end
        
        `uvm_info("DRIVER", "Last instruction fetch detected, waiting for pipeline to drain...", UVM_LOW)
        `uvm_info("DRIVER", "Subprogram completion detected!", UVM_LOW)
      end
    join_any // Exits as soon as the Termination Detector (Thread 3) finishes

    // 3. Cleanup and item completion
    disable fork; // Kills the 'forever' memory threads
    seq_item_port.item_done();
    `uvm_info("DRIVER", "Sequence item finished and released", UVM_LOW)
    //reset();
  endtask

  task reset();
    vif.inst_ready <= #OUTPUT_DELAY 0;
    vif.inst_data.memory_w <= #OUTPUT_DELAY 'bx;
    vif.data_ready <= #INPUT_DELAY 0;
    vif.data_rd.u_data <= #INPUT_DELAY 'bx;
  endtask

  // ---------------------------------------------------------------------------
  // Image path: the program item is the whole memory image. It is loaded once,
  // the item is completed, and the responder below answers the ports until the
  // phase ends. The verdict is the checker's, never this BFM's.
  // ---------------------------------------------------------------------------
  task run_image_mode();
    seq_item_port.get_next_item(req);
    foreach (mem[i]) mem[i] = '0;
    foreach (req.program_addr[i])
      mem[req.program_addr[i] >> 2] = req.program_data[i];
    `uvm_info("PROGRAM_DRV", $sformatf("loaded %0d program words", req.program_addr.size()), UVM_LOW)
    seq_item_port.item_done();
    run_memory_responder();
  endtask

  task run_memory_responder();
    logic [31:0] word;
    int unsigned idx;
    int unsigned cycles;

    cycles = 0;
    warned_imem_range = 0;
    warned_dmem_range = 0;

    forever begin
      @(posedge vif.clk);
      if (!vif.rst_n) continue;
      cycles++;

      // --- instruction port: identical protocol to the directed driver ------
      vif.inst_ready <= #OUTPUT_DELAY 0;
      if (vif.inst_rd_en) begin
        idx = vif.inst_addr >> 2;
        if (idx <= 32'h0000_FFFF) begin
          word = mem[idx];
        end else begin
          word = NOP;
          // Once, not per fetch: a runaway PC outside the image would otherwise
          // bury the log under one warning per cycle.
          if (!warned_imem_range) begin
            warned_imem_range = 1;
            `uvm_warning("IMEM_RANGE", $sformatf("INST_OUT_OF_RANGE: PC='h%0h (mem is 0x0..0x3ffff); further out-of-range fetches are silent", vif.inst_addr))
          end
        end
        vif.inst_data.memory_w <= #OUTPUT_DELAY word;
        vif.inst_ready <= #OUTPUT_DELAY 1;
        if (trace)
          $display("TRACE[%0d] IFETCH pc=0x%08h inst=0x%08h", cycles, vif.inst_addr, word);
      end

      // --- data port --------------------------------------------------------
      vif.data_ready <= #INPUT_DELAY 0;
      if (vif.data_rd_en) begin
        idx = vif.data_addr.u_data >> 2;
        if (idx <= 32'h0000_FFFF) begin
          word = mem[idx];
        end else begin
          word = '0;
          if (!warned_dmem_range) begin
            warned_dmem_range = 1;
            `uvm_warning("DMEM_RANGE", $sformatf("ADDR_OUT_OF_RANGE: ADDR='h%0h (mem is 0x0..0x3ffff); further out-of-range data accesses are silent", vif.data_addr.u_data))
          end
        end
        vif.data_rd.u_data <= #INPUT_DELAY word;
        vif.data_ready <= #INPUT_DELAY 1;
        if (trace)
          $display("TRACE[%0d] DREAD  addr=0x%08h data=0x%08h", cycles, vif.data_addr.u_data, word);
      end else if (vif.data_wr_en) begin
        idx = vif.data_addr.u_data >> 2;
        // Word-granular on purpose: the DUT exposes no byte strobes yet
        // (FR-11/G-22). SB/SH therefore write the whole word here and are
        // measured as failures elsewhere, not silently emulated.
        if (idx <= 32'h0000_FFFF) begin
          mem[idx] = vif.data_wr.u_data;
        end else begin
          if (!warned_dmem_range) begin
            warned_dmem_range = 1;
            `uvm_warning("DMEM_RANGE", $sformatf("ADDR_OUT_OF_RANGE: ADDR='h%0h (mem is 0x0..0x3ffff); further out-of-range data accesses are silent", vif.data_addr.u_data))
          end
        end
        vif.data_ready <= #INPUT_DELAY 1;
        if (trace)
          $display("TRACE[%0d] DWRITE addr=0x%08h data=0x%08h", cycles, vif.data_addr.u_data, vif.data_wr.u_data);
      end
    end
  endtask

endclass : riscv_small_driver

`endif
