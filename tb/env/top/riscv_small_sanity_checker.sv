`ifndef RISCV_SMALL_SANITY_CHECKER
`define RISCV_SMALL_SANITY_CHECKER

// ============================================================================
// riscv_small_sanity_checker
//
// Verdict for the image/ISA path. It subscribes to the MONITOR (never to the
// driver) and decides from what the DUT actually did:
//
//   data write to `tohost` == 1        -> SANITY: PASS
//   data write to `tohost` == n<<1|1   -> SANITY: FAIL testnum=n, uvm_error
//   no such write before +MAX_CYCLES    -> SANITY: TIMEOUT, uvm_error
//
// Every verdict prints the last events (fetch and data) and triggers `done`;
// the test owns the objection and waits for that event. The checker never
// drives a pin and never loads an image.
//
// Author: Nelson Alves nelsonafn@gmail.com
// ============================================================================
class riscv_small_sanity_checker extends uvm_component;

  `uvm_component_utils(riscv_small_sanity_checker)

  // ---- Input port: monitor events ------------------------------------------
  uvm_analysis_export #(riscv_small_transaction) checker_export;
  uvm_tlm_analysis_fifo #(riscv_small_transaction) mon_fifo;

  // ---- Verdict handshake ---------------------------------------------------
  uvm_event done;

  // ---- Configuration -------------------------------------------------------
  int unsigned tohost;
  string       image_name = "unknown";

  // ---- History: the last events, so a fail/timeout shows where the DUT was --
  localparam int HISTORY_DEPTH = 64;
  localparam int HISTORY_PRINT = 16;
  riscv_small_transaction history[$];
  logic [31:0] last_pc;
  bit          finished;

  // ---- Constructor ---------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build phase ---------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon_fifo       = new("mon_fifo", this);
    checker_export = new("checker_export", this);
    done           = new("done");

    if (!uvm_config_db#(int unsigned)::get(this, "", "tohost", tohost))
      `uvm_fatal("SANITY", "sanity checker without tohost")
    if (!uvm_config_db#(string)::get(this, "", "image_name", image_name))
      image_name = "unknown";
  endfunction

  // ---- Connect phase -------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    checker_export.connect(mon_fifo.analysis_export);
  endfunction

  // ---- Run phase: consume observed events, decide on the tohost store ------
  virtual task run_phase(uvm_phase phase);
    riscv_small_transaction tr;
    forever begin
      mon_fifo.get(tr);
      record(tr);
      if (tr.op_is_inst) begin
        last_pc = tr.captured_inst_addr;
        continue;
      end
      if (tr.op_is_data_write && tr.captured_data_addr == tohost && !finished)
        verdict(tr.captured_data_wr);
    end
  endtask

  // ---- History -------------------------------------------------------------
  function void record(riscv_small_transaction tr);
    history.push_back(tr);
    while (history.size() > HISTORY_DEPTH)
      void'(history.pop_front());
  endfunction

  function void print_history(int n);
    int count;
    int start;
    count = (history.size() < n) ? history.size() : n;
    start = history.size() - count;
    for (int i = start; i < history.size(); i++) begin
      riscv_small_transaction h = history[i];
      if (h.op_is_inst)
        $display("SANITY: HISTORY IFETCH pc=0x%08h inst=0x%08h",
                 h.captured_inst_addr, h.captured_inst_data);
      else if (h.op_is_data_write)
        $display("SANITY: HISTORY DWRITE addr=0x%08h data=0x%08h",
                 h.captured_data_addr, h.captured_data_wr);
      else
        $display("SANITY: HISTORY DREAD  addr=0x%08h data=0x%08h",
                 h.captured_data_addr, h.captured_data_rd);
    end
  endfunction

  // ---- Verdicts ------------------------------------------------------------
  function void verdict(logic [31:0] value);
    finished = 1;
    if (value == 1) begin
      $display("SANITY: PASS image=%s", image_name);
    end else begin
      $display("SANITY: FAIL testnum=%0d value=0x%08h", value >> 1, value);
      // A failing image must fail the UVM run, not only the log grep.
      `uvm_error("SANITY", $sformatf("image %s failed at testnum %0d (value=0x%08h, tohost=0x%08h)",
                                     image_name, value >> 1, value, tohost))
    end
    print_history(HISTORY_PRINT);
    done.trigger();
  endfunction

  function void report_timeout();
    if (finished) return;
    finished = 1;
    $display("SANITY: TIMEOUT pc=0x%08h", last_pc);
    print_history(HISTORY_PRINT);
    `uvm_error("SANITY", $sformatf("timeout waiting for tohost=0x%08h", tohost))
    done.trigger();
  endfunction

endclass : riscv_small_sanity_checker

`endif
