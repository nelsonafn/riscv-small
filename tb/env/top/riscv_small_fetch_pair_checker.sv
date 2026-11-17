`ifndef RISCV_SMALL_FETCH_PAIR_CHECKER
`define RISCV_SMALL_FETCH_PAIR_CHECKER

// ============================================================================
// riscv_small_fetch_pair_checker
//
// G-32 checker: every fetch the MONITOR publishes must carry the instruction
// word the program placed at that address. The pair is (captured_inst_addr,
// captured_inst_data); the oracle is the riscv_small_program_image handed in
// by configuration, never the driver and never a transaction stream.
//
// A fetch whose address is in the image but whose word is not is
// UVM_ERROR [FETCH_PAIR], naming the address, the observed word and the
// expected one. A fetch of an address outside the image (the core running past
// the end of the program while the run drains) is counted and reported, not
// judged: the image cannot say what that address holds.
//
// The protocol guard (wp-8 §3.1.7, R11) is here for the same reason the pair is:
// the MONITOR publishes an instruction response that had no request outstanding
// with `captured_inst_orphan` set, and this checker turns that observation into
// UVM_ERROR [FETCH_ORPHAN]. The monitor counts and reports; it never raises, so
// the observation component and the verdict component stay separate. The orphan
// response is not a fetch pair -- the address pin is not the pair of that word
// -- so it is not compared against the image.
//
// A request still pending at the end of the run is NOT an error here: the
// testbench stops answering when the program item completes, so the last
// request is legitimately in flight when the phase ends. The monitor reports
// that count; the checker leaves it alone.
//
// It is a subscriber on the monitor, like riscv_small_strb_checker, so it is
// built in BOTH agent modes and never stalls an image run: there is no FIFO
// and no blocking get(). Without a configured image it only counts, and says
// so in report_phase, so an inert checker is visible in the log.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : November 2026
// ============================================================================
class riscv_small_fetch_pair_checker extends uvm_subscriber #(riscv_small_transaction);
  `uvm_component_utils(riscv_small_fetch_pair_checker)

  // Oracle: the program as configuration. Null means "no image in this test".
  riscv_small_program_image image;

  int unsigned fetch_count    = 0;  // fetch events published by the monitor
  int unsigned orphan_count   = 0;  // responses with no request outstanding
  int unsigned pair_count     = 0;  // fetches whose address the image knows
  int unsigned mismatch_count = 0;  // ... whose word disagreed with the image
  int unsigned unmapped_count = 0;  // fetches of addresses outside the image

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(riscv_small_program_image)::get(this, "", "program_image", image))
      image = null;
  endfunction

  function void write(riscv_small_transaction t);
    bit [31:0] expected;

    if (!t.op_is_inst) return;

    // R11: the monitor saw the memory ready with a word while no request was
    // outstanding. It published the observation; the judgement is ours.
    if (t.captured_inst_orphan) begin
      orphan_count++;
      `uvm_error("FETCH_ORPHAN",
        $sformatf("[FETCH_ORPHAN #%0d] instruction response accepted with no request outstanding: addr=0x%0h word=0x%08h",
          orphan_count, t.captured_inst_addr, t.captured_inst_data))
      return;
    end

    fetch_count++;

    if (image == null) return;

    if (!image.lookup_inst(t.captured_inst_addr, expected)) begin
      // First few only: a runaway PC would otherwise bury the log under one
      // line per fetch.
      if (unmapped_count < 4)
        `uvm_info("FETCH_PAIR",
          $sformatf("fetch of 0x%0h is outside the program image (%0d word(s)); not compared",
            t.captured_inst_addr, image.inst_size()),
          UVM_MEDIUM)
      unmapped_count++;
      return;
    end

    pair_count++;
    if (expected !== t.captured_inst_data[31:0]) begin
      mismatch_count++;
      `uvm_error("FETCH_PAIR",
        $sformatf("[FETCH_PAIR #%0d] fetch pair mismatch at pc=0x%0h: observed word=0x%08h expected word=0x%08h",
          mismatch_count, t.captured_inst_addr, t.captured_inst_data, expected))
    end
  endfunction: write

  function void report_phase(uvm_phase phase);
    if (image == null)
      `uvm_info(get_full_name(),
        $sformatf("G-32 fetch pair: %0d fetch(es) counted, %0d orphan response(s), NONE compared (no program image configured)",
          fetch_count, orphan_count),
        UVM_LOW)
    else
      `uvm_info(get_full_name(),
        $sformatf("G-32 fetch pair: %0d fetch(es), %0d orphan response(s), %0d compared, %0d mismatch(es), %0d outside the image, image=%0d word(s)",
          fetch_count, orphan_count, pair_count, mismatch_count, unmapped_count, image.inst_size()),
        UVM_LOW)
  endfunction: report_phase

endclass: riscv_small_fetch_pair_checker

`endif
