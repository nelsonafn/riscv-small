//------------------------------------------------------------------------------
// Base test class for riscv_small
//------------------------------------------------------------------------------
// This UVM test serves as the base for all riscv_small tests, defining common 
// features like the colored report server.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : April 2024
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_BASE_TEST_SV
`define RISCV_SMALL_BASE_TEST_SV

class riscv_small_base_test extends uvm_test;

  /*
   * Components
   */
  riscv_small_environment env;
   
  /*
   * Register with factory
   */
  `uvm_component_utils(riscv_small_base_test)
     
  /*
   * Constructor
   */
  function new(string name = "riscv_small_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  /*
   * Build phase: instantiate components and replace report server
   */
  function void build_phase(uvm_phase phase);
    colored_report_server my_server;
    super.build_phase(phase);

    // Set the colored report server
    my_server = new("my_server");
    uvm_report_server::set_server(my_server);
    `uvm_info("BASE_TEST", "Colored Report Server set.", UVM_LOW)
    
    // Instantiate environment
    env = riscv_small_environment::type_id::create("env", this);
    `uvm_info("BASE_TEST", "Environment instantiated.", UVM_LOW)
  endfunction : build_phase

  /*
   * Directed tests end when the program's last instruction RETIRES, not when
   * the last fetch is answered: the pipeline holds four more instructions and
   * dropping the objection with them in flight would lose the last commits and
   * the last store predictions. Waits on the retire checker's `done`, bounded
   * by clock edges; the timeout is the test's, the verdict is the checker's.
   * A test with no program image has nothing to drain and returns at once.
   */
  task automatic wait_program_drain(int unsigned max_cycles = 2000);
    riscv_small_retire_checker rc;
    int unsigned waited;

    rc = env.retire_checker;
    if (rc == null || rc.image == null || rc.image.inst_size() == 0) return;

    waited = 0;
    while (!rc.done && waited < max_cycles) begin
      @(posedge env.riscv_small_agnt.monitor.vif.clk);
      waited++;
    end

    if (!rc.done)
      `uvm_error("DRAIN_TIMEOUT",
        $sformatf("%0d of %0d instruction(s) retired within %0d clock cycle(s); %0d commit(s) seen",
          rc.checked_count, rc.image.inst_size(), max_cycles, rc.retire_count))
    else
      `uvm_info("DRAIN_DONE",
        $sformatf("program drained after %0d extra clock cycle(s): %0d commit(s) for %0d instruction(s)",
          waited, rc.retire_count, rc.image.inst_size()),
        UVM_LOW)
  endtask : wait_program_drain

endclass : riscv_small_base_test

`endif
