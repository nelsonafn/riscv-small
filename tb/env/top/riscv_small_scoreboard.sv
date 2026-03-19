`ifndef RISCV_SMALL_SCOREBOARD
`define RISCV_SMALL_SCOREBOARD

// ============================================================================
// riscv_small_scoreboard
//
// Scoreboard UVM: compara as transações previstas pelo Reference Model (ISS)
// com as transações reais observadas pelo Monitor na DUT.
//
//   rm_fifo   → transações de previsão de STORE (vindas do Ref Model)
//   mon_fifo  → transações de observação  de STORE (vindas do Monitor/DUT)
//
// Para cada STORE observado pelo Monitor, o Scoreboard retira a próxima
// previsão da fila do RM e compara endereço + dado.
//
// Author: Nelson Alves nelsonafn@gmail.com
// ============================================================================
class riscv_small_scoreboard extends uvm_scoreboard;
  
  `uvm_component_utils(riscv_small_scoreboard)

  // ---- Portos de entrada ---------------------------------------------------
  uvm_analysis_export #(riscv_small_transaction) sb_export_mon; // do Monitor
  uvm_analysis_export #(riscv_small_transaction) sb_export_rm;  // do Ref Model

  // ---- FIFOs internas ------------------------------------------------------
  uvm_tlm_analysis_fifo #(riscv_small_transaction) mon_fifo;
  uvm_tlm_analysis_fifo #(riscv_small_transaction) rm_fifo;

  // ---- Counters de resultado -----------------------------------------------
  int unsigned pass_count = 0;
  int unsigned fail_count = 0;

  // ---- Construtor ----------------------------------------------------------
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

  // Mapa de previsões: byte_addr → dado esperado (preenchido pelo Ref Model)
  int expected_stores[int];

  // ---- Run phase: comparação -----------------------------------------------
  task run_phase(uvm_phase phase);
    riscv_small_transaction mon_trans; // observação da DUT (Monitor)
    riscv_small_transaction exp_trans; // previsão do ISS   (Ref Model)
    int exp_count = 0;
    int mon_count = 0;

    forever begin
      // 1. Aguardar próxima observação de escrita de dados na DUT
      mon_fifo.get(mon_trans);
      if (!mon_trans.op_is_data_write) continue;
      mon_count++;

      // 2. Obter a próxima previsão do Ref Model (bloqueia até chegar)
      rm_fifo.get(exp_trans);
      exp_count++;

      // ---- Imprimir o subprograma para o primeiro item de cada sequência ----
      if (mon_count == 1) print_subprogram(exp_trans);

      // ---- Comparar endereço e dado ----------------------------------------
      if (mon_trans.captured_data_addr == exp_trans.captured_data_addr &&
          mon_trans.captured_data_wr   == exp_trans.captured_data_wr) begin

        pass_count++;
        `uvm_info(get_full_name(),
          $sformatf("[PASS #%0d] SW %0d correto: addr=0x%0h dado=0x%0h",
            pass_count, mon_count,
            mon_trans.captured_data_addr,
            mon_trans.captured_data_wr),
          UVM_LOW)

      end else begin

        fail_count++;
        `uvm_error(get_full_name(),
          $sformatf("[FAIL #%0d] SW %0d errado:\n  DUT: addr=0x%0h dado=0x%0h\n  EXP: addr=0x%0h dado=0x%0h",
            fail_count, mon_count,
            mon_trans.captured_data_addr, mon_trans.captured_data_wr,
            exp_trans.captured_data_addr, exp_trans.captured_data_wr))

      end
    end
  endtask : run_phase

  // ---- Report phase: resumo final ------------------------------------------
  function void report_phase(uvm_phase phase);
    `uvm_info(get_full_name(),
      $sformatf("\n========================================\n  SCOREBOARD FINAL REPORT\n  PASS : %0d\n  FAIL : %0d\n========================================",
        pass_count, fail_count),
      UVM_NONE)
    if (fail_count > 0)
      `uvm_error(get_full_name(), "SIMULAÇÃO ENCERROU COM FALHAS!")
    else
      `uvm_info(get_full_name(), "SIMULAÇÃO PASSOU EM TODOS OS CHECKS!", UVM_NONE)
  endfunction

  // ---- Função auxiliar: print do subprograma ------------------------------
  function void print_subprogram(riscv_small_transaction t);
    string msg;
    msg = "\n  --- Subprograma associado à previsão ---";
    msg = {msg, $sformatf("\n  Instruções (%0d):", t.instruction_list.size())};
    foreach (t.instruction_list[i])
      msg = {msg, $sformatf("\n    [%0d] 0x%08h", i, t.instruction_list[i])};
    msg = {msg, $sformatf("\n  Dados iniciais (%0d):", t.data_addr.size())};
    foreach (t.data_addr[i])
      msg = {msg, $sformatf("\n    mem_word[%0d] = 0x%0h", t.data_addr[i], t.data_list[i])};
    `uvm_info(get_full_name(), msg, UVM_HIGH)
  endfunction

endclass : riscv_small_scoreboard

`endif
