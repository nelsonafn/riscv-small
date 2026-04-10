`ifndef RISCV_SMALL_DRIVER
`define RISCV_SMALL_DRIVER

class riscv_small_driver extends uvm_driver #(riscv_small_transaction);

  virtual riscv_small_interface.drv_mp vif;
  `uvm_component_utils(riscv_small_driver)
  uvm_analysis_port#(riscv_small_transaction) drv2rm_port;

  logic [31:0] inst_mem [int];
  logic [31:0] data_mem [int];
  localparam OUTPUT_DELAY = 2;
  localparam INPUT_DELAY = 1;
  localparam NOP = 32'h00000033;
  


  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual riscv_small_interface)::get(this, "", "intf", vif))
      `uvm_fatal("NO_VIF",{"virtual interface must be set for: ",get_full_name(),".vif"});
    drv2rm_port = new("drv2rm_port", this);
  endfunction

  // TODO: Move to fv_utils_pkg package
  // Function to convert an array of integers to a hex-formatted string
  function automatic string to_hex_list(ref int vec[]);
    string s = "'h{";
    foreach (vec[i]) 
        s = {s, $sformatf("%0h%s", vec[i], (i == vec.size()-1) ? "" : ",")};
    return {s,"}"};
  endfunction

  virtual task run_phase(uvm_phase phase);
    reset();

    // 1. Get initial test sequence transaction
    seq_item_port.get_next_item(req);
    req.print();
    // foreach (req.instruction_addr[i]) begin
    //   inst_mem[req.instruction_addr[i]] = req.instruction_list[i];
    // end
    // foreach (req.data_addr[i]) begin
    //   data_mem[req.data_addr[i]] = req.data_list[i];
    // end
    
    // Broadcast the full sequence item containing the subprogram
    drv2rm_port.write(req);
    `uvm_info("DRIVER", "Sequence item sent to the ref model", UVM_LOW)

    // Set PC=0 immediately before starting the main loop 
    // so that the first clock edge captures LW0 correctly.
    // if (inst_mem.exists(0)) begin
    //   vif.inst_data.memory_w <= inst_mem[0];
    // end

    seq_item_port.item_done();

    // 2. Play memory behavior
    fork
      // Thread 1: Instruction
      forever begin : inst_mem_thread
        @(posedge vif.clk);
        vif.inst_ready <= #OUTPUT_DELAY 0; // Default
        if (vif.inst_rd_en) begin
          bit found = 0;
          foreach (req.instruction_addr[i]) begin
            if (req.instruction_addr[i] == vif.inst_addr) begin
              vif.inst_data.memory_w <= #OUTPUT_DELAY req.instruction_list[i];
              vif.inst_ready <= #OUTPUT_DELAY 1;
              `uvm_info("IFETCH_DRV", $sformatf("READ_INST: PC='h%0h INST='h%0h", vif.inst_addr, req.instruction_list[i]), UVM_LOW);
              found = 1;
              break;
            end
          end
          if (!found) begin
            vif.inst_data.memory_w <= #OUTPUT_DELAY NOP;
            `uvm_warning("IADDR_OOR_DRV", $sformatf("INST_OUT_OF_RANGE: PC='h%0h, INST_ADDREs=%s, INST_VECTOR=%s", vif.inst_addr, to_hex_list(req.instruction_addr), to_hex_list(req.instruction_list)));
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
                req.data_list[i] = vif.data_wr.u_data;
                `uvm_info("DSTORE_DRV", $sformatf("ADDR='h%0h DATA='h%0h", vif.data_addr.u_data, vif.data_wr.u_data), UVM_LOW);
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

      // Thread 3: Termination Detector (Example: Wait for PC to reach its limit)
      begin : end_detector
        // Define what "finishing" means for your testbench
        // Example: Wait for a HALT signal or for the PC to reach a final value
        wait(vif.inst_addr == req.instruction_addr[req.instruction_addr.size()-1]);
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

endclass : riscv_small_driver

`endif
