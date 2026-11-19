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
//             ends. Addresses are absolute (the image lives at RESET_VECTOR);
//             `mem` is indexed from `mem_base`, so the model stays 0-based.
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
  // memory behaviour below is untouched. The model applies the DUT's byte
  // strobes: `data_wr_strb[b]` selects the byte lanes of `data_wr` that the core
  // drives, so SB/SH/SW write exactly the bytes the contract names and the
  // memory never shifts or justifies (FR-11, Q-28).
  // ---------------------------------------------------------------------------
  bit          mem_mode;
  bit          trace;
  logic [31:0] mem [0:65535];   // 64K words = 256 KiB of image space

  // The address of `mem[0]`. It is the value the testbench top published from
  // the DUT's elaborated RESET_VECTOR (FR-41, Q-33) -- the same configuration
  // key the reset checker compares against, never a second copy of the spec's
  // default. Every image-mode access is indexed relative to it, so the memory
  // model stays 0-based while the core addresses the program absolutely.
  logic [31:0] mem_base;
  localparam logic [31:0] MEM_WORDS = 32'h0000_FFFF;

  bit warned_imem_range;
  bit warned_dmem_range;
  bit warned_zero_strb;
  bit warned_iaddr_oor;   // directed path: first fetch outside the program only
  bit program_entered;    // directed path: a program address has been answered

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
    // The image base is configuration, and it must exist: without it an
    // absolute address has no index, and guessing 0 is the defect this WP
    // removes. The top owns the single source (`duv.RESET_VECTOR`).
    if (!uvm_config_db#(bit [31:0])::get(this, "", "reset_vector", mem_base))
      `uvm_fatal("NO_MEM_BASE",
        "no reset_vector was published by the testbench top: the memory BFM cannot index an absolute address")
  endfunction

  // TODO: Move to fv_utils_pkg package
  // Function to convert an array of integers to a hex-formatted string
  function automatic string to_hex_list(ref int vec[]);
    string s = "'h{";
    foreach (vec[i]) 
        s = {s, $sformatf("%0h%s", vec[i], (i == vec.size()-1) ? "" : ",")};
    return {s,"}"};
  endfunction

  // Apply the DUT's byte strobes to one word. This is the memory's job and the
  // only thing the driver does with `data_wr_strb`: it neither judges the
  // pattern nor derives it. A zero strobe with `data_wr_en` writes nothing --
  // the grant still completes -- and is logged once, not per access.
  function automatic logic [31:0] apply_strobes(logic [31:0] word,
                                                logic [31:0] data,
                                                logic [3:0]  strb,
                                                logic [31:0] addr);
    if (strb == 4'b0000) begin
      if (!warned_zero_strb) begin
        warned_zero_strb = 1;
        `uvm_info("STRB_ZERO_DRV", $sformatf("STRB_ZERO: data_wr_en with data_wr_strb=4'b0000 at addr='h%0h; no byte written, further zero-strobe writes are silent", addr), UVM_LOW)
      end
      return word;
    end
    for (int b = 0; b < 4; b++)
      if (strb[b]) word[8*b +: 8] = data[8*b +: 8];
    return word;
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

    // Once per run, not per cycle: a core that runs away (the reset-vector
    // mutant fetches 0x0, 0x4, 0x8, ...) would otherwise bury the log under one
    // warning per fetch and hide the checker's verdict.
    warned_iaddr_oor = 0;
    program_entered  = 0;

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
        // wp-8 §3.1.1: the target must not present rsp_valid while the core is
        // in reset. Answering a reset-time request leaves a response on the bus
        // that the core latches on the first post-reset edge *and* again one
        // cycle later, executing the reset PC twice -- the retire observation
        // found it (an extra commit at pc=0). The request presented while reset
        // is low is answered on the first post-reset edge, which is the
        // one-cycle latency the core's pc_fetch/pc_id pairing expects.
        if (!vif.rst_n) continue;
        if (vif.inst_rd_en) begin
          bit found = 0;
          foreach (req.instruction_addr[i]) begin
            if (req.instruction_addr[i] == vif.inst_addr) begin
              vif.inst_data.memory_w <= #OUTPUT_DELAY req.instruction_list[i];
              vif.inst_ready <= #OUTPUT_DELAY 1;
              program_entered = 1;
              `uvm_info("IFETCH_DRV", $sformatf("READ_INST: PC='h%0h INST='h%0h", vif.inst_addr, req.instruction_list[i]), UVM_LOW);
              found = 1;
              break;
            end
          end
          if (!found) begin
            // An address outside the program is answered with a NOP. Before the
            // program has been entered the handshake is completed too: a core
            // that resets elsewhere never presents a program address at all, so
            // writing the word without raising `inst_ready` stalls it forever,
            // the monitor never publishes the fetch and no checker can judge the
            // address -- a stalled BFM turns "the core fetched the wrong
            // address" into a timeout, which is not the claim (T-50's mutant).
            //
            // Once the program has started, the same address is the pipeline
            // tail and keeps its historical behaviour: the fetch is not
            // answered, the core freezes and the item completes. Completing it
            // there as well (the image path does, because its memory covers
            // every address) publishes four extra pairs past the image and costs
            // T-06/T-46 their asserted `fetch - commit == |skip_pc|` count form
            // (riscv_small_retire_checker.sv:235) -- measured, not assumed. The
            // warning is emitted once; it names the whole program so the log
            // stays diagnosable.
            vif.inst_data.memory_w <= #OUTPUT_DELAY NOP;
            if (!program_entered) vif.inst_ready <= #OUTPUT_DELAY 1;
            if (!warned_iaddr_oor) begin
              warned_iaddr_oor = 1;
              `uvm_warning("IADDR_OOR_DRV", $sformatf("INST_OUT_OF_RANGE: PC='h%0h, INST_ADDRs=%s, INST_VECTOR=%s; further out-of-range fetches are silent", vif.inst_addr, to_hex_list(req.instruction_addr), to_hex_list(req.instruction_list)));
            end
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
                req.data_list[i] = apply_strobes(req.data_list[i],
                                                  vif.data_wr.u_data,
                                                  vif.data_wr_strb,
                                                  vif.data_addr.u_data);
                `uvm_info("DSTORE_DRV", $sformatf("ADDR='h%0h DATA='h%0h STRB=0b%04b", vif.data_addr.u_data, vif.data_wr.u_data, vif.data_wr_strb), UVM_LOW);
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
          // A request presented while reset is low is not a program fetch: `pc`
          // resets to RESET_VECTOR, so during reset the pins can already present
          // the program's last address. Completing the item there would stop the
          // BFM before it ever answered the first fetch (measured on T-50: the
          // item ended at 15 ns and no fetch pair was published).
          if (!vif.rst_n) continue;
          if (vif.inst_rd_en && (vif.inst_addr == last_addr)) break;
        end

        // The request presented in the cycle that just ended is the program's
        // last one: its response goes out on the next cycle, and the core
        // captures it one edge after that. Wait for that response, then stop
        // answering -- a BFM that leaves rsp_valid high with the stale last
        // word lets the core fetch and retire instructions past the program.
        @(posedge vif.clk);
        vif.inst_ready <= #OUTPUT_DELAY 0;

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
    // The sequence emits absolute addresses (it lays the program out at
    // RESET_VECTOR); `mem` is indexed from `mem_base`, which is that address.
    foreach (req.program_addr[i])
      mem[(req.program_addr[i] - mem_base) >> 2] = req.program_data[i];
    `uvm_info("PROGRAM_DRV", $sformatf("loaded %0d program words at base 0x%08h", req.program_addr.size(), mem_base), UVM_LOW)
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
    warned_zero_strb = 0;

    forever begin
      @(posedge vif.clk);
      if (!vif.rst_n) continue;
      cycles++;

      // --- instruction port: identical protocol to the directed driver ------
      vif.inst_ready <= #OUTPUT_DELAY 0;
      if (vif.inst_rd_en) begin
        // Absolute address -> image index. Anything below the base wraps to a
        // huge unsigned index and takes the out-of-range branch below.
        idx = (vif.inst_addr - mem_base) >> 2;
        if (idx <= MEM_WORDS) begin
          word = mem[idx];
        end else begin
          word = NOP;
          // Once, not per fetch: a runaway PC outside the image would otherwise
          // bury the log under one warning per cycle.
          if (!warned_imem_range) begin
            warned_imem_range = 1;
            `uvm_warning("IMEM_RANGE", $sformatf("INST_OUT_OF_RANGE: PC='h%0h (mem is 0x%08h..0x%08h); further out-of-range fetches are silent",
              vif.inst_addr, mem_base, mem_base + (MEM_WORDS << 2)))
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
        idx = (vif.data_addr.u_data - mem_base) >> 2;
        if (idx <= MEM_WORDS) begin
          word = mem[idx];
        end else begin
          word = '0;
          if (!warned_dmem_range) begin
            warned_dmem_range = 1;
            `uvm_warning("DMEM_RANGE", $sformatf("ADDR_OUT_OF_RANGE: ADDR='h%0h (mem is 0x%08h..0x%08h); further out-of-range data accesses are silent",
              vif.data_addr.u_data, mem_base, mem_base + (MEM_WORDS << 2)))
          end
        end
        vif.data_rd.u_data <= #INPUT_DELAY word;
        vif.data_ready <= #INPUT_DELAY 1;
        if (trace)
          $display("TRACE[%0d] DREAD  addr=0x%08h data=0x%08h", cycles, vif.data_addr.u_data, word);
      end else if (vif.data_wr_en) begin
        idx = (vif.data_addr.u_data - mem_base) >> 2;
        // Byte strobes are the DUT's contract: only the lanes it drives change,
        // so a byte or halfword store is a read-modify-write here exactly as it
        // is in a real memory (FR-11, Q-28).
        if (idx <= MEM_WORDS) begin
          mem[idx] = apply_strobes(mem[idx],
                                   vif.data_wr.u_data,
                                   vif.data_wr_strb,
                                   vif.data_addr.u_data);
        end else begin
          if (!warned_dmem_range) begin
            warned_dmem_range = 1;
            `uvm_warning("DMEM_RANGE", $sformatf("ADDR_OUT_OF_RANGE: ADDR='h%0h (mem is 0x%08h..0x%08h); further out-of-range data accesses are silent",
              vif.data_addr.u_data, mem_base, mem_base + (MEM_WORDS << 2)))
          end
        end
        vif.data_ready <= #INPUT_DELAY 1;
        if (trace)
          $display("TRACE[%0d] DWRITE addr=0x%08h data=0x%08h strb=0b%04b", cycles, vif.data_addr.u_data, vif.data_wr.u_data, vif.data_wr_strb);
      end
    end
  endtask

endclass : riscv_small_driver

`endif
