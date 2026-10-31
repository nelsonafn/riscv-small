//------------------------------------------------------------------------------
// Sanity test for riscv_small - runs a pre-built riscv-tests image
//------------------------------------------------------------------------------
// The test owns the configuration and the objection; the sequence owns the
// program item; the driver is the memory BFM; the checker owns the verdict.
//
//   +HEX=<file>        Verilog hex image, required
//   +TOHOST=<hex>      address of the `tohost` symbol, required (from `nm`)
//   +MAX_CYCLES=<n>    cycle budget before the run is declared a timeout
//   +TRACE             print every fetch and every data operation
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : October 2026
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_SANITY_TEST_SV
`define RISCV_SMALL_SANITY_TEST_SV

class riscv_small_sanity_test extends riscv_small_base_test;

  /*
   * Components
   */
  riscv_small_sanity_seq seq;

  /*
   * Sanity configuration: read here, published to the env/checker/monitor.
   */
  virtual riscv_small_interface vif;
  string       hex_file;
  string       image_name;
  int unsigned tohost;
  int unsigned max_cycles = 200000;
  bit          trace;

  /*
   * Register with factory
   */
  `uvm_component_utils(riscv_small_sanity_test)

  /*
   * Constructor
   */
  function new(string name = "riscv_small_sanity_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  /*
   * Build phase: read the plusargs, then publish the configuration.
   *
   * The config_db writes happen after super.build_phase() -- which creates the
   * env -- and before the env/agent/checker build phases run, because UVM
   * builds a parent before its children.
   */
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    begin
      bit got_hex;
      got_hex = $value$plusargs("HEX=%s", hex_file);
      if (!got_hex)
        `uvm_fatal("SANITY", "missing +HEX")
    end

    begin
      bit got_tohost;
      got_tohost = $value$plusargs("TOHOST=%h", tohost);
      if (!got_tohost)
        `uvm_fatal("SANITY", "missing +TOHOST")
    end

    begin
      int got_cycles;
      got_cycles = $value$plusargs("MAX_CYCLES=%d", max_cycles);
    end
    trace = $test$plusargs("TRACE");
    image_name = image_name_of(hex_file);

    if (!uvm_config_db#(virtual riscv_small_interface)::get(this, "", "intf", vif))
      `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})

    uvm_config_db#(bit)::set(this, "*", "sanity_mode", 1'b1);
    uvm_config_db#(int unsigned)::set(this, "*", "tohost", tohost);
    uvm_config_db#(string)::set(this, "*", "image_name", image_name);
    uvm_config_db#(bit)::set(this, "*", "trace", trace);

    seq = riscv_small_sanity_seq::type_id::create("seq");
    seq.hex_file = hex_file;
  endfunction : build_phase

  /*
   * Run phase: start the program, arm the clock-based timeout, wait for the
   * checker's `done`, then end the run. The objection is this test's.
   */
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("SANITY", $sformatf("hex=%s tohost=0x%08h max_cycles=%0d trace=%0b",
                                  hex_file, tohost, max_cycles, trace), UVM_LOW)

    fork
      // (a) cycle budget: report a timeout if the checker has not decided.
      begin
        repeat (max_cycles) @(posedge vif.clk);
        if (!env.sanity_checker.done.is_on())
          env.sanity_checker.report_timeout();
      end
      // (b) the sequence sends the program; the checker decides.
      begin
        seq.start(env.riscv_small_agnt.sequencer);
        env.sanity_checker.done.wait_on();
      end
    join_any
    disable fork;

    phase.drop_objection(this);
  endtask : run_phase

  /*
   * Basename without the directory and the .hex suffix: the verdict line names
   * the image, never the absolute path.
   */
  function automatic string image_name_of(string path);
    int    slash = 0;
    string base;
    for (int i = 0; i < path.len(); i++) begin
      if (path.getc(i) == "/") slash = i + 1;
    end
    base = path.substr(slash, path.len() - 1);
    if (base.len() > 4 && base.substr(base.len() - 4, base.len() - 1) == ".hex")
      base = base.substr(0, base.len() - 5);
    return base;
  endfunction

endclass : riscv_small_sanity_test

`endif
