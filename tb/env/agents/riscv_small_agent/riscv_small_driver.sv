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
//
// `data_ready_delay` (config_db, default 0) is how many clock edges the data
// port withholds the grant after an access is first presented (WP-13 P3,
// FR-38/G-18). At 0 the answer goes out on the first edge, byte-identically to
// before the option existed; the delay is the TEST's stimulus, never the BFM's
// opinion.
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

  // ---- Data-port protocol (WP-13 P3, FR-38/G-18) ---------------------------
  // How many clock edges the BFM withholds `data_ready` after an access is
  // first presented. Configuration, default 0 = answer on the first edge, the
  // behaviour the 47 tests before T-53 were written against.
  int unsigned data_ready_delay;

  int unsigned data_wait;       // edges the current access has been withheld
  bit          data_inflight;   // an access is on the bus and not yet answered
  bit          data_answered;   // the access on the bus already has its answer
  bit          data_sig_read;   // what identifies the access on the bus
  bit          data_sig_write;
  logic [31:0] data_sig_addr;
  logic [31:0] data_sig_wr;
  logic [3:0]  data_sig_strb;

  // ---- Platform straps (WP-14, D13) ----------------------------------------
  // `mtime` and `hart_id` are DUT inputs the CSR file reads as `time`/`timeh`
  // (FR-49) and `mhartid` (FR-32). The VALUE is born in the test (config_db,
  // default 0 = the platform's silent timer and hart 0); this BFM only drives
  // it, exactly as it drives `data_ready_delay`. The monitor observes the same
  // interface wire, so the reference model learns the value from the
  // observation and never from here (C-16, wp-14 D13).
  //
  // `exception[3:0]` is the same kind of input and travels the same way
  // (WP-14b, FR-22/Q-35): the sequence schedules a request against a program
  // address (the item's exception_addr/exception_cause, see raise_exception),
  // this BFM asserts it for one core cycle, and the monitor observes it.
  bit [63:0] mtime_stim;
  bit [3:0]  hart_id_stim;

  function bit data_same_access();
    if (data_sig_read != vif.data_rd_en)   return 1'b0;
    if (data_sig_write != vif.data_wr_en)  return 1'b0;
    if (data_sig_addr != vif.data_addr.u_data) return 1'b0;
    if (!data_sig_write) return 1'b1;
    return (data_sig_strb == vif.data_wr_strb) && (data_sig_wr == vif.data_wr.u_data);
  endfunction

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
    // WP-14 D13: the platform straps. Absent, they are 0 -- the value the
    // interface already holds, so a run that never sets them is unchanged.
    if (!uvm_config_db#(bit [63:0])::get(this, "", "mtime", mtime_stim))
      mtime_stim = '0;
    if (!uvm_config_db#(bit [3:0])::get(this, "", "hart_id", hart_id_stim))
      hart_id_stim = '0;
    // WP-13 P3: the grant delay is the test's decision. Absent, it is 0 and the
    // directed memory answers exactly as it did before this option existed.
    if (!uvm_config_db#(int unsigned)::get(this, "", "data_ready_delay", data_ready_delay))
      data_ready_delay = 0;
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

  // One data access, one answer: read the word the item declared, or apply the
  // DUT's byte strobes to the declared word, then raise the grant for exactly
  // one cycle. `found` is about the program's declared addresses, not about the
  // protocol: an address the item did not declare is answered with a warning and
  // no grant, exactly as before WP-13.
  task automatic answer_data_access();
    bit found = 0;
    foreach (req.data_addr[i]) begin
      if (req.data_addr[i] == vif.data_addr.u_data) begin
        if (vif.data_rd_en) begin
          vif.data_rd.u_data <= #INPUT_DELAY req.data_list[i];
          `uvm_info("DFETCH_DRV", $sformatf("ADDR='h%0h DATA='h%0h", vif.data_addr.u_data, req.data_list[i]), UVM_LOW);
        end else begin
          logic [31:0] stored;
          stored = apply_strobes(req.data_list[i],
                                 vif.data_wr.u_data,
                                 vif.data_wr_strb,
                                 vif.data_addr.u_data);
          // Byte-addressed aliasing: the core presents a BYTE address, so
          // a store at 0x411 and the read-back at 0x410 name the same
          // memory word. The item declares one entry per byte address a
          // program names, so the write is mirrored into every declared
          // entry of that word -- otherwise a load after a store returns
          // the pre-store value and no store/load pair could be checked.
          // A real memory applies the strobes to the word; this is that
          // word, seen through the addresses the item declared.
          foreach (req.data_addr[j])
            if ((req.data_addr[j] >> 2) == (vif.data_addr.u_data >> 2))
              req.data_list[j] = stored;
          `uvm_info("DSTORE_DRV", $sformatf("ADDR='h%0h DATA='h%0h STRB=0b%04b WORD='h%0h", vif.data_addr.u_data, vif.data_wr.u_data, vif.data_wr_strb, stored), UVM_LOW);
        end
        vif.data_ready <= #INPUT_DELAY 1;
        found = 1;
        break;
      end
    end
    if (!found) begin
      `uvm_warning("DATA_OOR_DRV", $sformatf("ADDR_OUT_OF_RANGE: ADDR='h%0h, DATA_ADDRs=%s, DATA_VECTOR=%s, R/W=%s", vif.data_addr.u_data, to_hex_list(req.data_addr), to_hex_list(req.data_list), vif.data_rd_en ? "READ" : "WRITE"));
    end
  endtask

  virtual task run_phase(uvm_phase phase);
    reset();
    // WP-14 D13: the platform straps, on the first clock edge (see drive_straps).
    drive_straps();

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
              // FR-22/Q-35: the platform's synchronous trap request, if the
              // sequence scheduled one against this address. The BFM obeys the
              // schedule; it does not decide when a trap is meaningful.
              foreach (req.exception_addr[k])
                if (req.exception_addr[k] == vif.inst_addr)
                  raise_exception(req.exception_cause[k]);
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
      //
      // WP-13 P3 (FR-38/G-18): the grant is a per-ACCESS decision, not a
      // per-cycle echo. `data_ready_delay` is how many clock edges the BFM
      // withholds the grant after an access is first presented; at 0 the answer
      // goes out on that first edge, which is the behaviour every test written
      // before T-53 relies on. The delay belongs to the test (config_db), never
      // to the BFM: this driver only obeys it.
      //
      // An access is answered ONCE. A store the core holds until the grant
      // stays on the bus for as many cycles as the wait takes, and answering it
      // again would write the memory twice for one store. The signature of the
      // access on the bus is what distinguishes "the same store, still waiting"
      // from "the next store": the request fields the core drives, not the read
      // data the memory answers with.
      forever begin : data_mem_thread
        @(posedge vif.clk);
        vif.data_ready <= #INPUT_DELAY 0; // Default

        // No access on the bus: nothing is waiting, and the next presentation
        // is a new access.
        if (!(vif.data_rd_en || vif.data_wr_en)) begin
          data_inflight = 0;
          data_answered = 0;
          data_wait     = 0;
          continue;
        end

        // The access on the bus already carries its answer. This is the cycle
        // after the grant went out; the core advances on the next edge, so
        // answering it again is a second store for one.
        if (data_answered && data_same_access()) continue;

        // The same access, still withheld: answer when the delay has elapsed.
        if (data_inflight && data_same_access()) begin
          if (data_wait >= data_ready_delay) begin
            answer_data_access();
            data_inflight = 0;
            data_answered = 1;
          end else begin
            data_wait++;
          end
          continue;
        end

        // A new access: remember what identifies it, then answer now when no
        // delay applies to it.
        data_inflight  = 1;
        data_answered  = 0;
        data_wait      = 0;
        data_sig_read  = vif.data_rd_en;
        data_sig_write = vif.data_wr_en;
        data_sig_addr  = vif.data_addr.u_data;
        data_sig_wr    = vif.data_wr.u_data;
        data_sig_strb  = vif.data_wr_strb;
        // The delay is the STORE contract (FR-38) and nothing else. A read
        // keeps the historical answer on its first edge: the core evaluates
        // its data_ready stall one cycle after the load left MA
        // (rtl/control.sv:288 reads the WB slot's mux select), so a read grant
        // this memory withholds is lost before the core can use it -- that is
        // a separate defect (FR-21's wait state), reported and not claimed
        // here, and withholding a read would turn T-53 into a timeout instead
        // of an FR-38 verdict.
        if (data_ready_delay == 0 || !vif.data_wr_en) begin
          answer_data_access();
          data_inflight = 0;
          data_answered = 1;
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

  // WP-14 D13: the straps are level inputs, not part of a handshake. They are
  // driven on the first clock edge and never change during the run, so the
  // value the test configured is the value the whole run sees.
  //
  // Why the first edge and not time 0: the interface initialises both to zero
  // (the value a PASSIVE agent -- no driver -- must present), and a write at
  // time 0 would race that initialisation. One edge settles it, and the core is
  // still in reset then, so nothing can read the value early.
  task drive_straps();
    @(posedge vif.clk);
    vif.mtime   = mtime_stim;
    vif.hart_id = hart_id_stim;
    // FR-22/Q-35: no external trap request is standing at reset. The interface
    // initialises the same value (a passive agent has no driver to do it), so a
    // run without a schedule sees a defined zero on the pin -- never an X.
    vif.exception = 4'b0000;
  endtask

  // ---------------------------------------------------------------------------
  // FR-22/Q-35 (WP-14b): the external trap request
  //
  // `exception[3:0]` is a level input: the code present in a cycle is the reason
  // the platform is asking for. The sequence schedules it against an
  // INSTRUCTION ADDRESS (the item's exception_addr/exception_cause), so the
  // program's shape decides where the trap lands and this BFM only times it.
  //
  // The timing is the pipeline's, not a guess: the instruction memory answers a
  // request one edge after the address is presented, and IF/ID registers that
  // word (with `pc_id` = that address) on the following edge. So the cycle
  // after this BFM answers the fetch of the named address is the cycle in which
  // that instruction occupies ID -- the cycle a request must stand in to trap
  // it. Exactly ONE cycle, because a request left high would trap again on the
  // first instruction the handler runs.
  //
  // A mis-timed request is not silent: an early trap reports the wrong PC in
  // `mepc` and a late one lets the instruction execute, and both are values the
  // program reads back and the scoreboard compares.
  //
  // The drive is NON-BLOCKING on purpose: the monitor samples `trap_valid` and
  // `exception` in the same posedge that ends the request's cycle, and a
  // blocking de-assert there would race the observation -- measured on T-61,
  // where the trap was taken with cause 5 and published with exception = 0.
  // ---------------------------------------------------------------------------
  task automatic raise_exception(int unsigned cause);
    fork
      begin
        @(posedge vif.clk);       // the named instruction is now in ID
        vif.exception <= cause[3:0];
        @(posedge vif.clk);       // one core cycle later
        vif.exception <= 4'b0000;
      end
    join_none
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
