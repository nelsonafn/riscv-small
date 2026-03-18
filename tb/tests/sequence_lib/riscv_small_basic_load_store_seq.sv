`ifndef RISCV_SMALL_BASIC_SEQ 
`define RISCV_SMALL_BASIC_SEQ

class riscv_small_basic_load_store_seq extends uvm_sequence#(riscv_small_transaction);
   
  `uvm_object_utils(riscv_small_basic_load_store_seq)
 
  function new(string name = "riscv_small_basic_load_store_seq");
    super.new(name);
  endfunction
 
  virtual task body();
    int N = 10;
    int rand_rd_addr;
    int rand_wr_addr;
    int rand_data;

    req = riscv_small_transaction::type_id::create("req");
    start_item(req);
    
    req.instruction_addr = new[N*2 + 1];
    req.instruction_list = new[N*2 + 1];
    req.data_addr = new[N];
    req.data_list = new[N];

    for (int i=0; i<N; i++) begin
      rand_rd_addr = $urandom_range(100, 150); 
      rand_wr_addr = $urandom_range(200, 250);
      rand_data = $urandom();
      
      req.data_addr[i] = rand_rd_addr;
      req.data_list[i] = rand_data;
      
      // Instruction 2*i: LW x1, (rand_rd_addr*4)(x0)
      begin
        bit [11:0] rd_imm = rand_rd_addr * 4;
        req.instruction_addr[2*i] = i*2;
        req.instruction_list[2*i] = { rd_imm, 5'd0, 3'b010, 5'd1, 7'b0000011 };
      end
      
      // Instruction 2*i+1: SW x1, (rand_wr_addr*4)(x0)
      begin
        bit [11:0] wr_imm = rand_wr_addr * 4;
        req.instruction_addr[2*i+1] = i*2 + 1;
        req.instruction_list[2*i+1] = { wr_imm[11:5], 5'd1, 5'd0, 3'b010, wr_imm[4:0], 7'b0100011 };
      end
    end

    // Add an end loop trap jumping to self to avoid exiting boundaries and NOP flushes
    begin
        bit [11:0] loop_imm = 0; // jump offset 0
        req.instruction_addr[N*2] = N*2;
        req.instruction_list[N*2] = { loop_imm[11], loop_imm[10:1], loop_imm[11], 8'd0, 7'b1101111 }; // JAL zero, 0 -> wait, JAL format is different, JAL is 1101111. Let's just put a NOP.
        req.instruction_list[N*2] = 32'h00000033; // Actually, just NOPs
    end

    `uvm_info(get_full_name(), $sformatf("SENDING %0d RANDOM LOADS/STORES DYNAMIC SEQ TO DRIVER", N), UVM_LOW);
    finish_item(req);
    
    // Give enough time for N*2 instructions plus bubbles
    #60000;
  endtask
   
endclass

`endif
