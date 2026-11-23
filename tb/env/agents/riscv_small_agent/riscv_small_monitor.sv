`ifndef RISCV_SMALL_MONITOR
`define RISCV_SMALL_MONITOR

// ============================================================================
// riscv_small_monitor
//
// Observes the DUT ports and publishes what it saw -- fetch AND data AND
// retire AND trap -- on the analysis port. It never drives, never judges, never
// decodes and never holds the verdict.
//
// The trap stream (WP-14 §4.2, E6) is the fourth, read through
// riscv_small_trap_if, the probe bound inside the DUT. It exists because the
// instruction that traps is flushed before write-back and NEVER retires: a
// model fed only by the retire stream is blind to exactly the event the trap
// path implements, and a pc discontinuity cannot stand in for it because a jump
// produces the same one. The event carries (pc, instruction word, cause), so
// the reference model can DERIVE the cause from the word and compare it with
// the cause the core took -- publishing only the cause would leave the model
// repeating the DUT's value.
//
// The trap event is sampled on EVERY posedge and is NOT masked with `clk_en`
// (wp-14 D12b): `clk_en` gates the advance of the pipeline, not a trap, and a
// trap_valid held high for the two or three cycles of a retention would publish
// N events for one trap and make the model apply N traps. The RTL contract is
// therefore one cycle per trap, driven from the same signal the probe samples.
//
// THE PUBLICATION ORDER IS THE ARCHITECTURAL ORDER (WP-14b, audit blocker 1).
// Four streams share one analysis port, so the position of an event in the
// stream is a claim about time: the instruction retiring in WB and the beat in
// MA are OLDER than the instruction trapping in ID in the same cycle. The trap
// is therefore sampled first (unmasked) and published LAST, after the commit and
// the data beat of that cycle. Publishing it first made a consumer of the two
// observations apply the trap before the commit, so a CSR read of `mepc`/
// `mcause` retiring in the trap's own cycle was predicted from the POST-trap
// state -- latent until T-60 placed such a read three instructions before the
// trap site.
//
// D13: `mtime` and `hart_id` are read from the pin interface and published with
// every retire and trap event. They are the DUT's stimulus, observed, so the
// model predicts `time`/`timeh` and `mhartid` from what the monitor saw and a
// second source of truth is never created (C-16).
//
// The retire event (G-28) is read through riscv_small_retire_if, the probe bound
// inside the DUT; the interface derives the commit rule, so the monitor only
// reports it. The event carries (pc, instruction word, rd, wdata), which makes
// it self-contained: a consumer never has to look the instruction up in a
// fetched-word table, and a fetch the core flushed is never executed (the probe
// only reports what reached write-back). Since WP-14 it also carries whether
// the instruction writes its destination register (the probe's rd0_wr_en_wb):
// "CSRRW with rd = x0 wrote nothing" and "CSRRW failed to write rd" are the
// same observation without it.
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
// The DATA port is published once per BEAT, not once per cycle and not once per
// access (WP-13 P3, FR-38/G-18; P6b, FR-42/G-22). The access begins at the first
// cycle the enable is presented, it is granted in a cycle in which `data_ready`
// is high, and it ends when the enable goes away or the request changes with no
// grant in between. Each publication carries `captured_data_grant`, so a
// consumer can tell a store the memory granted from one the core abandoned --
// which is exactly the observation FR-38 needs and the level rule could not make.
//
// Since P6b an access whose lane plus width crosses the word boundary is TWO
// word-aligned beats (rtl/misaligned_split.sv), so the publication carries
// `captured_data_beat` / `captured_data_beats`. The beat boundary is the request
// signature: a new signature inside a split access is the second beat. A split
// beat is never granted on its first cycle -- the RTL holds each beat at least
// one cycle before it consumes `data_ready`, so a high level there is the
// previous beat's grant still standing (and `data_rd` still carries the previous
// beat's word). A repeated signature after that publication is the same beat
// still on the bus, not a new access.
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
  virtual riscv_small_trap_if       trap_vif;
  uvm_analysis_port#(riscv_small_transaction) mon2sb_port;
  `uvm_component_utils(riscv_small_monitor)

  bit trace;

  // Addresses of instruction requests the core presented and the memory has
  // not answered yet, oldest first. Depth 1 today (LINE_WORDS = 1).
  bit [31:0] fetch_pending[$];

  int unsigned fetch_count  = 0; // published (address, word) pairs
  int unsigned orphan_count = 0; // responses with nothing outstanding (published with captured_inst_orphan)
  int unsigned retire_count = 0; // published retire (commit) events
  int unsigned trap_count   = 0; // published trap events (wp-14 §4.2)

  // ---- Data-access assembly (WP-13 P3, FR-38/G-18) -------------------------
  // Core clock cycles, 1-based: incremented on every edge the core actually
  // clocks after reset, so a published cycle number is a number a reader can
  // reproduce from a waveform of the DUT's clock.
  int unsigned cycle = 0;

  bit          da_pending     = 0; // a beat is on the bus and not published
  bit          da_is_read     = 0;
  bit          da_is_write    = 0;
  logic [31:0] da_addr        = '0;
  logic [31:0] da_wr          = '0;
  logic [31:0] da_rd          = '0;
  logic [31:0] da_ctrl        = '0;
  logic [3:0]  da_strb        = '0;
  int unsigned da_first_cycle = 0; // the cycle the beat was first presented
  int unsigned da_cycles      = 0; // how many cycles the beat has been presented

  int unsigned data_count       = 0; // published beats
  int unsigned data_withheld    = 0; // beats published without a grant
  int unsigned data_waited      = 0; // beats that stayed on the bus > 1 cycle
  int unsigned data_split_beats = 0; // published beats that belong to a split access
  int unsigned data_split_accesses = 0; // second beats published (one per split access)

  // ---- Beats of a split access (WP-13 P6b, FR-42/G-22) ---------------------
  // The access in progress, when it crosses the word boundary, is two beats.
  // `da_beat` is the index of the beat the da_* fields describe; `da_beats` is
  // how many the access has. `da_beat_done` records that the current split beat
  // has been published while its signature is still on the bus, which is the
  // same beat held one more cycle -- never a new access.
  bit          da_split     = 0;
  int unsigned da_beat      = 0;
  int unsigned da_beats     = 1;
  bit          da_beat_done = 0;

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
    if(!uvm_config_db#(virtual riscv_small_trap_if)::get(this, "", "trap_vif", trap_vif))
      `uvm_fatal("NO_TRAP_VIF",{"virtual interface must be set for: ",get_full_name(),".trap_vif"});
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

  // The request fields the CORE drives. The read data is deliberately not part
  // of it: it is the memory's answer, and it changes between the first cycle of
  // a load and the cycle it is granted -- including it would make one load look
  // like two accesses. It is also what delimits a beat inside a split access:
  // beat 2 has a different address (and strobe/data), so a signature change
  // inside a split is the next beat, and an unchanged signature is the same one.
  function bit da_same_access();
    if (da_is_read != vif.data_rd_en) return 1'b0;
    if (da_is_write != vif.data_wr_en) return 1'b0;
    if (da_addr != vif.data_addr.u_data) return 1'b0;
    if (!da_is_write) return 1'b1;
    return (da_strb == vif.data_wr_strb) && (da_wr == vif.data_wr.u_data);
  endfunction

  // Width (the DUT's data_rd_wr_ctrl) -> byte count. 2'b11 is not a width this
  // core emits; treating it as one byte keeps an unknown encoding from being
  // classified as a split by accident.
  function automatic int unsigned width_bytes(logic [1:0] width);
    case (width)
      2'b00: return 1;
      2'b01: return 2;
      2'b10: return 4;
      default: return 1;
    endcase
  endfunction

  // FR-42/G-22: the access crosses the word boundary when its byte lane plus its
  // width passes the fourth byte -- the same rule rtl/misaligned_split.sv
  // derives from access_size(funct3). SB/LB never cross, SH/LH only at lane 3,
  // SW/LW at every lane but 0.
  function bit da_crosses(logic [31:0] addr, logic [1:0] width);
    return ((addr[1:0] + width_bytes(width)) > 3'd4);
  endfunction

  // Fields as they stand in the cycle being sampled. Called on every cycle of
  // the beat, so the published event describes it at its completion: a load's
  // data is only valid in the cycle the memory grants it (for beat 2 that is the
  // second cycle, never the first, which still carries beat 1's word).
  function void da_capture();
    da_is_read  = vif.data_rd_en;
    da_is_write = vif.data_wr_en;
    da_addr     = vif.data_addr.u_data;
    da_rd       = vif.data_rd.u_data;
    da_wr       = vif.data_wr.u_data;
    da_ctrl     = vif.data_rd_wr_ctrl;
    da_strb     = vif.data_wr_strb;
  endfunction

  // One publication per beat. `granted` says a cycle of the beat coincided with
  // the memory's grant; it is not a verdict. riscv_small_store_grant_checker
  // decides what a write that ended without one means (FR-38 says it is a
  // store the core accepted before the grant).
  function void da_publish(bit granted);
    riscv_small_transaction trans = riscv_small_transaction::type_id::create("trans");

    trans.op_is_data_read       = da_is_read;
    trans.op_is_data_write      = da_is_write;
    trans.captured_data_addr    = da_addr;
    trans.captured_data_rd      = da_rd;
    trans.captured_data_wr      = da_wr;
    trans.captured_data_wr_ctrl = da_ctrl;
    trans.captured_data_wr_strb = da_strb;
    trans.captured_data_grant   = granted;
    trans.captured_data_cycle   = da_first_cycle;
    trans.captured_data_wait    = da_cycles;
    trans.captured_data_beat    = da_beat;
    trans.captured_data_beats   = da_beats;

    data_count++;
    if (da_cycles > 1) data_waited++;
    if (!granted) data_withheld++;
    if (da_beats > 1) data_split_beats++;
    if (da_beats > 1 && da_beat == 2) data_split_accesses++;

    if (trace)
      `uvm_info("DATA_MONITOR", $sformatf("DATA %s: ADDR=0x%0h DATA=0x%0h WIDTH=%0d STRB=0b%04b GRANT=%0d CYCLES=%0d@%0d BEAT=%0d/%0d",
        da_is_write ? "WRITE" : "READ",
        da_addr,
        da_is_write ? da_wr : da_rd,
        da_ctrl,
        da_strb,
        granted, da_cycles, da_first_cycle, da_beat, da_beats), UVM_LOW);
    mon2sb_port.write(trans);
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      // The trap of THIS edge, if any. It is sampled first (unmasked by clk_en,
      // D12b) but PUBLISHED LAST, because of the order of the two observations
      // (WP-14b, audit blocker 1): the instruction retiring in WB is OLDER than
      // the one trapping in ID, so a consumer fed by this port must receive the
      // commit before the trap of the same cycle. The publication order of the
      // analysis port IS the architectural order; see the file header.
      riscv_small_transaction trp;
      @(posedge vif.clk);

      trp = null;
      if (trap_vif.trap_valid) begin
        trap_count++;
        trp = riscv_small_transaction::type_id::create("trap_trans");
        trp.op_is_trap   = 1;
        trp.trap_pc      = trap_vif.trap_pc;
        trp.trap_inst    = trap_vif.trap_inst;
        trp.trap_cause   = trap_vif.trap_cause;
        trp.trap_seq     = trap_count;
        // D13: the straps as they stand next to the event.
        trp.obs_mtime    = vif.mtime;
        trp.obs_hart_id  = vif.hart_id;
        // FR-22/Q-35 (WP-14b): the external request as the MONITOR read it, not
        // as the test configured it. The model predicts an external trap's
        // cause from this (D13's rule), so a DUT that ignores the pin while the
        // monitor sees it cannot pass.
        trp.obs_exception = vif.exception;
        // The event belongs to the cycle being sampled. The counter below only
        // advances after the `clk_en` gate, so at this point the cycle in
        // progress is `cycle + 1` -- the same stamp the retire event published
        // later in this iteration carries.
        trp.obs_cycle    = cycle + 1;
      end

      // R10: clk_en is a clock enable, not a protocol signal. When the core
      // does not clock, it latches neither the request nor the response, so
      // neither handshake happened.
      if (!vif.clk_en) begin
        publish_trap(trp);
        continue;
      end

      if (!vif.rst_n) begin
        // Reset discards the pipeline, and the memory must not present a
        // response while the core is in reset (wp-8 §3.1.1) -- the request the
        // core keeps presenting during reset is answered on the first
        // post-reset edge, so it is pushed by the normal request rule below,
        // not here. Pushing it here too would pair one address with two
        // responses and shift every later pair.
        fetch_pending.delete();
        // A data access the reset cut in half never completed: it is not an
        // access the core accepted, so nothing is published for it.
        da_pending   = 0;
        da_split     = 0;
        da_beat      = 0;
        da_beats     = 1;
        da_beat_done = 0;
        publish_trap(trp);
        continue;
      end

      cycle++;

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

      // Data port: ONE publication per BEAT (WP-13 P3 FR-38/G-18; P6b
      // FR-42/G-22).
      //
      // The flat data port has no per-access completion pulse: a stalled load
      // holds data_rd_en high and the memory's data_ready is a level echo of
      // it, so a level rule (publish once per cycle the enable is high) cannot
      // tell one access held for two cycles from two accesses -- G-32, and E8's
      // scope for the port itself. What it CAN do without a new port is observe
      // the handshake: an access begins at the first cycle the enable is
      // presented, it is granted in a cycle in which data_ready is high, and it
      // ends when the enable goes away or the request changes without one. So
      // the monitor assembles the access and publishes it once, with
      // `captured_data_grant` saying whether a grant cycle happened. That is
      // what makes "the store the core held" one store rather than one per
      // cycle, which the scoreboard's one-prediction-per-store pairing
      // requires; and it is the only way to observe a store the core ABANDONED
      // before the grant, because that access is never granted and so would
      // have no publication at all under a grant-only rule.
      //
      // P6b splits that unit once more. An access whose lane plus width crosses
      // the word boundary is executed as two word-aligned beats, and the beat is
      // what the port carries: beat 1 at the address the core computed, beat 2
      // at (addr & ~3) + 4. The beat boundary is the REQUEST SIGNATURE, so a
      // signature change inside a split access is its second beat.
      //
      // A split beat is never granted on its first cycle. rtl/misaligned_split.sv
      // keeps each beat on the bus for at least one cycle before it consumes
      // data_ready (SPLIT_BEAT1 and SPLIT_BEAT2/SPLIT_BEAT2_GRANT); the port has
      // no falling edge between the two beats, so the high level the monitor
      // samples in beat 2's first cycle is beat 1's grant still standing -- and
      // data_rd still carries beat 1's word there. Publishing it would count the
      // beat twice and publish the wrong load data (measured: 3 publications per
      // crossing store, 99 STRB_WIDTH errors). A non-split access keeps the P3
      // rule exactly: it is one beat, and a grant in its first cycle is its own.
      //
      // Read the grant status with the read path in mind: this core consumes a
      // load's data_ready one stage later (rtl/control.sv:288 checks the WB
      // slot's mux select), so a load's request is already off the bus in the
      // grant cycle and it is published with grant=0. That is a fact about the
      // port, not a verdict, and it is why the FR-38 claim is scoped to writes
      // (riscv_small_store_grant_checker) and why T-53 withholds writes only.
      if (vif.data_rd_en || vif.data_wr_en) begin
        if (da_pending && da_same_access()) begin
          da_cycles++;
          da_capture();
          if (vif.data_ready && (!da_split || (da_cycles > 1))) begin
            da_publish(1'b1);
            da_pending   = 0;
            da_beat_done = da_split; // a split beat may still be on the bus
          end
        end else if (da_beat_done && da_same_access()) begin
          // The split beat was already published and its signature is still on
          // the bus: that is the SAME beat held for one more cycle (the core
          // advances on the next edge), not a new access.
          da_cycles++;
        end else begin
          // A different request. If a beat was still ungranted the core moved
          // on, so it was accepted without the grant: publish it as withdrawn
          // and start the next one.
          if (da_pending) da_publish(1'b0);
          da_pending   = 0;
          da_beat_done = 0;
          if (da_split && (da_beat == 1)) begin
            // The next distinct signature of a split access in progress is its
            // second beat. The monitor reports the beat index it OBSERVED; it
            // does not require the address to be the expected one -- judging
            // the two beats against each other is riscv_small_strb_checker's
            // claim, and a monitor that silently reclassified a wrong second
            // address as a new access would hide it.
            da_beat = 2;
          end else begin
            da_split = da_crosses(vif.data_addr.u_data, vif.data_rd_wr_ctrl[1:0]);
            da_beats = da_split ? 2 : 1;
            da_beat  = 1;
          end
          da_pending     = 1;
          da_first_cycle = cycle;
          da_cycles      = 1;
          da_capture();
          if (vif.data_ready && (!da_split || (da_cycles > 1))) begin
            da_publish(1'b1);
            da_pending   = 0;
            da_beat_done = da_split;
          end
        end
      end else begin
        if (da_pending) begin
          // The request left the bus with data_ready low in every cycle of it:
          // the beat was accepted before the grant.
          da_publish(1'b0);
          da_pending = 0;
        end
        // No access on the bus: the access and its beats are over.
        da_split     = 0;
        da_beat      = 0;
        da_beats     = 1;
        da_beat_done = 0;
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
        ret.retire_wr_en  = retire_vif.rd0_wr_en_wb;
        ret.retire_seq    = retire_count;
        // D13: the straps as they stand next to the event. The model predicts
        // `time`/`timeh` and `mhartid` from THESE, never from configuration.
        ret.obs_mtime     = vif.mtime;
        ret.obs_hart_id   = vif.hart_id;
        // FR-22/Q-35, and the cycle stamp a checker relates to a data beat (D12).
        ret.obs_exception = vif.exception;
        ret.obs_cycle     = cycle;
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
          `uvm_info("RETIRE_MONITOR", $sformatf("RETIRE #%0d pc=0x%08h inst=0x%08h rd=x%0d wr=%0d wdata=0x%08h (mtime=0x%016h hart_id=%0d)",
            retire_count, ret.retire_pc, ret.retire_inst, ret.retire_rd, ret.retire_wr_en, ret.retire_wdata,
            ret.obs_mtime, ret.obs_hart_id), UVM_LOW);
        mon2sb_port.write(ret);
      end

      // The trap of this edge goes LAST: it is the YOUNGEST event of the cycle
      // (decided in ID, while the commit came from WB and the data beat from
      // MA). One publication per event, verbatim -- only the position in the
      // stream is architectural.
      publish_trap(trp);
    end
  endtask

  // One publication for the trap sampled at the top of the iteration, if there
  // was one. Nothing is derived and nothing is filtered here.
  function void publish_trap(riscv_small_transaction trp);
    if (trp == null) return;
    if (trace)
      `uvm_info("TRAP_MONITOR", $sformatf("TRAP #%0d pc=0x%08h inst=0x%08h cause=%0d (mtime=0x%016h hart_id=%0d exception=%0d cycle=%0d)",
        trp.trap_seq, trp.trap_pc, trp.trap_inst, trp.trap_cause, trp.obs_mtime, trp.obs_hart_id,
        trp.obs_exception, trp.obs_cycle), UVM_LOW);
    mon2sb_port.write(trp);
  endfunction

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
      $sformatf("fetch pair: %0d published, %0d request(s) still outstanding at the end of the run, %0d orphan response(s); %0d retire event(s); %0d trap event(s)",
        fetch_count, fetch_pending.size(), orphan_count, retire_count, trap_count),
      UVM_MEDIUM)
    `uvm_info(get_full_name(),
      $sformatf("data port: %0d beat(s) published (%0d of a split access, %0d split access(es)), %0d waited more than one cycle, %0d with a grant cycle, %0d without one, %0d left pending at the end of the run",
        data_count, data_split_beats, data_split_accesses, data_waited, data_count - data_withheld, data_withheld, da_pending),
      UVM_MEDIUM)
  endfunction

endclass : riscv_small_monitor

`endif
