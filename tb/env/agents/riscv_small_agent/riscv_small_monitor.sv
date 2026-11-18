`ifndef RISCV_SMALL_MONITOR
`define RISCV_SMALL_MONITOR

// ============================================================================
// riscv_small_monitor
//
// Observes the DUT ports and publishes what it saw -- fetch AND data AND
// retire -- on the analysis port. It never drives, never judges, never decodes
// and never holds the verdict.
//
// The retire event (G-28) is read through riscv_small_retire_if, the probe bound
// inside the DUT; the interface derives the commit rule, so the monitor only
// reports it. The event carries (pc, instruction word, rd, wdata), which makes
// it self-contained: a consumer never has to look the instruction up in a
// fetched-word table, and a fetch the core flushed is never executed (the probe
// only reports what reached write-back).
//
// The fetch pair is formed by the outstanding-request rule of wp-8 §3.1.3
// (R1/R4/R10) and §3.1.7, not by sampling two pins in the same cycle:
//
//   request  accepted (req_valid && req_ready) : push its address
//   response accepted (rsp_valid && rsp_ready) : pop the front, publish
//                                                (address, word)
//
// Today the flat port is LINE_WORDS = 1 and the memory answers with a 2 ns
// output delay, so the response to the request presented in cycle n is
// captured by the core at edge n+2 while the address pin has already moved on
// to n+1: sampling both pins at one edge published (A_t, word(A_t-1)) -- G-32.
// The queue is written as a queue and not as a one-cycle delay so that an
// I-cache (F-10) makes it N beats per line without a rewrite; the same rule
// also covers a wait state, which is E8's test to add, not this WP's.
//
// Two protocol guards accompany it (R11): a response with nothing outstanding
// is an orphan. The monitor does not raise it -- it publishes the response with
// `captured_inst_orphan` set and counts it, and riscv_small_fetch_pair_checker
// turns that observation into the protocol error. The monitor observes, the
// checker judges. The pending count at the end of the run is reported, not
// raised, for the same reason it always was: the testbench stops answering when
// the program item completes, so the last request is legitimately still in
// flight when the phase ends -- FETCH_LOST would be an artefact of the run
// ending, not of the DUT.
//
// `trace` (+TRACE) prints one line per event. It is off by default because one
// sanity image is thousands of fetches and the `SANITY:` verdict must stay
// readable in the same log.
//
// `retire_log_fd` (+RETIRE_LOG=<file>, WP-9 P2) writes the canonical commit
// trace: one line per retired instruction, in retire order, no header and no
// cut at `tohost` (the comparator cuts, not the testbench). It is a publication
// of what the monitor already observed -- it compares nothing, judges nothing
// and does not know that Spike exists. Off by default: without the plusarg the
// handle stays 0, so there is no file I/O and no new log line.
// ============================================================================
class riscv_small_monitor extends uvm_monitor;
  virtual riscv_small_interface.mon_mp vif;
  virtual riscv_small_retire_if     retire_vif;
  uvm_analysis_port#(riscv_small_transaction) mon2sb_port;
  `uvm_component_utils(riscv_small_monitor)

  bit trace;

  // Addresses of instruction requests the core presented and the memory has
  // not answered yet, oldest first. Depth 1 today (LINE_WORDS = 1).
  bit [31:0] fetch_pending[$];

  int unsigned fetch_count  = 0; // published (address, word) pairs
  int unsigned orphan_count = 0; // responses with nothing outstanding (published with captured_inst_orphan)
  int unsigned retire_count = 0; // published retire (commit) events

  // Commit-trace dump (+RETIRE_LOG=<file>, WP-9 P2). The line is
  //   `0x<pc:08x> <x<rd>|-> <0x<value>|-> 0x<inst:08x>`
  // and `rd`/`value` are `-` when the instruction writes no register AND when
  // the destination is x0 -- both producers suppress that write (measured:
  // Spike prints no `xN` for rd = x0), so normalising both sides to `-` is what
  // keeps the comparison from failing on a register the core never had.
  string retire_log_path = "";
  int    retire_log_fd   = 0;     // 0 = the dump is off; $fopen's failure value

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual riscv_small_interface)::get(this, "", "intf", vif))
      `uvm_fatal("NO_VIF",{"virtual interface must be set for: ",get_full_name(),".vif"});
    if(!uvm_config_db#(virtual riscv_small_retire_if)::get(this, "", "retire_vif", retire_vif))
      `uvm_fatal("NO_RETIRE_VIF",{"virtual interface must be set for: ",get_full_name(),".retire_vif"});
    if (!uvm_config_db#(bit)::get(this, "", "trace", trace))
      trace = 0;

    // +RETIRE_LOG=<file> turns the commit dump on. Absent (every target but the
    // trace ones), nothing is opened and nothing is printed: the run is
    // byte-identical to the run before the option existed.
    retire_log_path = "";
    if ($value$plusargs("RETIRE_LOG=%s", retire_log_path) && retire_log_path != "") begin
      retire_log_fd = $fopen(retire_log_path, "w");
      if (retire_log_fd == 0)
        `uvm_fatal("RETIRE_LOG", $sformatf("cannot open retire log '%s' for writing", retire_log_path))
      `uvm_info("RETIRE_LOG", $sformatf("commit trace dump enabled: %s", retire_log_path), UVM_LOW)
    end

    mon2sb_port = new("mon2sb_port", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk);

      // R10: clk_en is a clock enable, not a protocol signal. When the core
      // does not clock, it latches neither the request nor the response, so
      // neither handshake happened.
      if (!vif.clk_en) continue;

      if (!vif.rst_n) begin
        // Reset discards the pipeline, and the memory must not present a
        // response while the core is in reset (wp-8 §3.1.1) -- the request the
        // core keeps presenting during reset is answered on the first
        // post-reset edge, so it is pushed by the normal request rule below,
        // not here. Pushing it here too would pair one address with two
        // responses and shift every later pair.
        fetch_pending.delete();
        continue;
      end

      // Response accepted (R4): the word on the bus now belongs to the oldest
      // outstanding request. Pop before pushing, so a request offered and
      // answered on the same edge cannot be paired with itself.
      if (vif.inst_ready) begin
        if (fetch_pending.size() == 0) begin
          // Observation, not a verdict: publish the response with the status
          // flag and let the checker decide. The address pin is whatever the
          // core presents now, so it is shown for the log but it is NOT the
          // pair of the word "inst_data" carries.
          riscv_small_transaction orphan = riscv_small_transaction::type_id::create("orphan_trans");
          orphan_count++;
          orphan.op_is_inst           = 1;
          orphan.captured_inst_orphan = 1;
          orphan.captured_inst_addr   = vif.inst_addr;
          orphan.captured_inst_data   = vif.inst_data.memory_w;
          if (trace)
            `uvm_info("FETCH_MONITOR", $sformatf("READ_INST_ORPHAN: no request outstanding, ADDR_PIN=0x%0h INST=0x%0h",
              orphan.captured_inst_addr, orphan.captured_inst_data), UVM_LOW);
          mon2sb_port.write(orphan);
        end else begin
          riscv_small_transaction trans = riscv_small_transaction::type_id::create("inst_trans");
          trans.op_is_inst = 1;
          trans.captured_inst_addr = fetch_pending.pop_front();
          trans.captured_inst_data = vif.inst_data.memory_w;
          fetch_count++;
          if (trace)
            `uvm_info("FETCH_MONITOR", $sformatf("READ_INST: PC=0x%0h INST=0x%0h", trans.captured_inst_addr, trans.captured_inst_data), UVM_LOW);
          mon2sb_port.write(trans);
        end
      end

      // Request accepted (R1): the address pin is the one the core will pair
      // with the response that is still to come.
      if (vif.inst_rd_en) fetch_pending.push_back(vif.inst_addr);

      // Capture every data transaction. NOTE (wp-8 §1): this is level, not
      // handshake, and it stays that way in this WP. The flat data port has no
      // per-access completion pulse: a stalled load holds data_rd_en high and
      // the driver's data_ready is a level echo of it, so neither a level rule
      // nor a queue can tell one access with a two-cycle enable from two
      // accesses. Fixing it needs the req/rsp form of the data port, which is
      // E8's scope (G-18) -- reported, not guessed.
      if(vif.data_rd_en || vif.data_wr_en) begin
        riscv_small_transaction trans = riscv_small_transaction::type_id::create("trans");
        trans.op_is_data_read = vif.data_rd_en;
        trans.op_is_data_write = vif.data_wr_en;
        trans.captured_data_addr = vif.data_addr.u_data;
        trans.captured_data_rd = vif.data_rd.u_data;
        trans.captured_data_wr = vif.data_wr.u_data;
        trans.captured_data_wr_ctrl = vif.data_rd_wr_ctrl;
        trans.captured_data_wr_strb = vif.data_wr_strb;

        if (trace)
          `uvm_info("DATA_MONITOR", $sformatf("DATA %s: ADDR=0x%0h DATA=0x%0h WIDTH=%0d STRB=0b%04b",
            trans.op_is_data_write ? "WRITE" : "READ",
            trans.captured_data_addr,
            trans.op_is_data_write ? trans.captured_data_wr : trans.captured_data_rd,
            trans.captured_data_wr_ctrl,
            trans.captured_data_wr_strb), UVM_LOW);
        mon2sb_port.write(trans);
      end

      // Retire (commit) event (G-28). The probe derives retire_valid; the
      // monitor publishes it verbatim with the instruction the pipeline
      // carried, so nothing downstream has to pair a fetch with a commit.
      if (retire_vif.retire_valid) begin
        riscv_small_transaction ret = riscv_small_transaction::type_id::create("retire_trans");
        retire_count++;
        ret.op_is_retire  = 1;
        ret.retire_pc     = retire_vif.retire_pc;
        ret.retire_inst   = retire_vif.retire_inst;
        ret.retire_rd     = retire_vif.retire_rd;
        ret.retire_wdata  = retire_vif.retire_wdata;
        ret.retire_seq    = retire_count;
        if (retire_log_fd != 0) begin
          // One line per commit, in retire order, from the observation above:
          // no comparison, no verdict. `x0` is suppressed on this side exactly
          // as the reference suppresses it.
          if (retire_vif.rd0_wr_en_wb && (retire_vif.retire_rd != 0))
            $fdisplay(retire_log_fd, "0x%08x x%0d 0x%08x 0x%08x",
              ret.retire_pc, ret.retire_rd, ret.retire_wdata, ret.retire_inst);
          else
            $fdisplay(retire_log_fd, "0x%08x - - 0x%08x",
              ret.retire_pc, ret.retire_inst);
        end
        if (trace)
          `uvm_info("RETIRE_MONITOR", $sformatf("RETIRE #%0d pc=0x%08h inst=0x%08h rd=x%0d wdata=0x%08h",
            retire_count, ret.retire_pc, ret.retire_inst, ret.retire_rd, ret.retire_wdata), UVM_LOW);
        mon2sb_port.write(ret);
      end
    end
  endtask

  function void report_phase(uvm_phase phase);
    // The run is over, so the dump is complete: close it once. The counter and
    // the path are reported only when the dump was on, so the default run keeps
    // its exact log.
    if (retire_log_fd != 0) begin
      $fclose(retire_log_fd);
      retire_log_fd = 0;
      `uvm_info("RETIRE_LOG",
        $sformatf("%0d commit line(s) written to %s", retire_count, retire_log_path), UVM_MEDIUM)
    end
    `uvm_info(get_full_name(),
      $sformatf("fetch pair: %0d published, %0d request(s) still outstanding at the end of the run, %0d orphan response(s); %0d retire event(s)",
        fetch_count, fetch_pending.size(), orphan_count, retire_count),
      UVM_MEDIUM)
  endfunction

endclass : riscv_small_monitor

`endif
