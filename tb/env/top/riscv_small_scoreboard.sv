`ifndef RISCV_SMALL_SCOREBOARD
`define RISCV_SMALL_SCOREBOARD

// ============================================================================
// riscv_small_scoreboard
//
// UVM Scoreboard: compares transactions predicted by the Reference Model (ISS)
// with the actual transactions observed by the Monitor on the DUT.
//
//   rm_fifo   → STORE prediction transactions (from Ref Model)
//   mon_fifo  → STORE observation transactions (from Monitor/DUT)
//
// For each STORE observed by the Monitor, the Scoreboard retrieves the next 
// prediction from the RM queue and compares the address + data.
//
// Author: Nelson Alves nelsonafn@gmail.com
// ============================================================================
class riscv_small_scoreboard extends uvm_scoreboard;
  
  `uvm_component_utils(riscv_small_scoreboard)

  // ---- Input Ports ---------------------------------------------------------
  uvm_analysis_export #(riscv_small_transaction) sb_export_mon; // from Monitor
  uvm_analysis_export #(riscv_small_transaction) sb_export_rm;  // from Ref Model

  // ---- Internal FIFOs ------------------------------------------------------
  uvm_tlm_analysis_fifo #(riscv_small_transaction) mon_fifo;
  uvm_tlm_analysis_fifo #(riscv_small_transaction) rm_fifo;

  // ---- Result Counters -----------------------------------------------------
  int unsigned pass_count = 0;
  int unsigned fail_count = 0;

  // ---- Constructor ---------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build phase ---------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon_fifo    = new("mon_fifo", this);
    rm_fifo     = new("rm_fifo",  this);
    sb_export_mon = new("sb_export_mon", this);
    sb_export_rm  = new("sb_export_rm",  this);
  endfunction

  // ---- Connect phase -------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    sb_export_mon.connect(mon_fifo.analysis_export);
    sb_export_rm.connect(rm_fifo.analysis_export);
  endfunction

  // Prediction map: byte_addr → expected data (populated by Ref Model)
  int expected_stores[int];

  // ---- Run phase: comparison -----------------------------------------------
  task run_phase(uvm_phase phase);
    riscv_small_transaction mon_trans; // DUT observation (Monitor)
    riscv_small_transaction exp_trans; // ISS prediction (Ref Model)
    int exp_count = 0;
    int mon_count = 0;

    forever begin
      // 1. Wait for next data write observation on the DUT
      mon_fifo.get(mon_trans);
      if (!mon_trans.op_is_data_write) continue;
      mon_count++;

      // 2. Obtain the next prediction from the Ref Model (blocks until arrival)
      rm_fifo.get(exp_trans);
      exp_count++;

      // ---- Print subprogram for the first item of each sequence ------------
      if (mon_count == 1) print_subprogram(exp_trans);

      // ---- Compare address and data ----------------------------------------
      if (mon_trans.captured_data_addr == exp_trans.captured_data_addr &&
          mon_trans.captured_data_wr   == exp_trans.captured_data_wr) begin

        pass_count++;
        `uvm_info(get_full_name(),
          $sformatf("[PASS #%0d] SW %0d correct: addr=0x%0h data=0x%0h",
            pass_count, mon_count,
            mon_trans.captured_data_addr,
            mon_trans.captured_data_wr),
          UVM_LOW)

      end else begin

        fail_count++;
        `uvm_error(get_full_name(),
          $sformatf("[FAIL #%0d] SW %0d wrong:\n  DUT: addr=0x%0h data=0x%0h\n  EXP: addr=0x%0h data=0x%0h",
            fail_count, mon_count,
            mon_trans.captured_data_addr, mon_trans.captured_data_wr,
            exp_trans.captured_data_addr, exp_trans.captured_data_wr))

      end
    end
  endtask : run_phase

  // ---- Report phase: final summary -----------------------------------------
  function void report_phase(uvm_phase phase);
    `uvm_info(get_full_name(),
      $sformatf("\n========================================\n  SCOREBOARD FINAL REPORT\n  PASS : %0d\n  FAIL : %0d\n========================================",
        pass_count, fail_count),
      UVM_NONE)
    if (fail_count > 0)
      `uvm_error(get_full_name(), "SIMULATION ENDED WITH FAILS!")
    else
      `uvm_info(get_full_name(), "SIMULATION PASSED ALL CHECKS!", UVM_NONE)
  endfunction

  // ---- Helper function: print subprogram ---------------------------------
  function void print_subprogram(riscv_small_transaction t);
    string msg;
    msg = "\n  --- Subprogram associated with the prediction ---";
    msg = {msg, $sformatf("\n  Instructions (%0d):", t.instruction_list.size())};
    foreach (t.instruction_list[i])
      msg = {msg, $sformatf("\n    [%0d] 0x%08h", i, t.instruction_list[i])};
    msg = {msg, $sformatf("\n  Initial data (%0d):", t.data_addr.size())};
    foreach (t.data_addr[i])
      msg = {msg, $sformatf("\n    mem_word[%0d] = 0x%0h", t.data_addr[i], t.data_list[i])};
    `uvm_info(get_full_name(), msg, UVM_HIGH)
  endfunction

endclass : riscv_small_scoreboard

`endif
