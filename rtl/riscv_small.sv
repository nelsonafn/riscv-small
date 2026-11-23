/*******************************************************************************
 * Copyright 2020 Nelson Alves Ferreira Neto
 * All Rights Reserved Worldwide
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 
 * 1. Redistributions of source code must retain the above copyright notice, 
 * this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice, 
 * this list of conditions and the following disclaimer in the documentation 
 * and/or other materials provided with the distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 * POSSIBILITY OF SUCH DAMAGE.
 ******************************************************************************/
/*
 * Package: riscv_small
 *
 * Description: This is the top level of the riscv-small. Thi processor core is 
 * 5 stage cpu that implements the RV32I.
 *
 * Maintainer: Nelson Alves <nelsonafn@gmail.com>
 *
 * History:
 * January 07, 2021 at 22:29 - Created by Nelson Alves <nelsonafn@gmail.com>
 */
 
module riscv_small 
import riscv_definitions_pkg::*;
#(
    /* Reset vector: the address the first fetch after reset presents on
     * inst_addr (FR-41, Q-33). A build-time input, not a CSR. */
    parameter dataBus_t RESET_VECTOR = 32'h8000_0000,
    /* FR-37: the extension set misa advertises is the CONFIGURATION's, never a
     * literal (D11). This build executes I only, so A, M and C default to 0;
     * a build that implements FR-35/FR-43/FR-44 passes them as 1. */
    parameter bit ENABLE_A = 1'b0,
    parameter bit ENABLE_M = 1'b0,
    parameter bit ENABLE_C = 1'b0
)(
    input clk,    //[in] Clock
    input clk_en, //[in] Clock Enable
    input rst_n,  //[in] Asynchronous reset active low
    input logic [3:0] exception, //[in] exception
    input logic [63:0] mtime, //[in] Machine timer, view of time/timeh (FR-49)
    input logic [3:0] hart_id, //[in] Hart identifier, read as mhartid (FR-32)
    // Instruction Memory controls
    input logic inst_ready, //[in] Indicates that data instruction ready
    input instruction_u inst_data, //[in] Data from instruction memory
    output dataBus_t inst_addr,//[out] Address of next instruction
    output logic inst_rd_en, //[out] Instruction memory read enable 
    // Data Memory controls
    input logic data_ready, //[in] Indicates that data is ready
    input dataBus_u data_rd, //[in] Data from data_memory
    output logic data_rd_en_ma, //[out] Data memory read enable to be used with data_rd_wr_ctrl 
	output logic data_wr_en_ma, //[out] Data memory write enable to be used with data_rd_wr_ctrl
    output dataBus_u data_wr, //[out] Data to data_memory
    output dataBus_u data_addr,//[out] Address of next data
    output logic [1:0] data_rd_wr_ctrl, //[out] 2'b00 = 8bits, 2'b01 = 16bits, 2'b10 = 32bits,
    output logic [3:0] data_wr_strb //[out] Byte write strobe of data_wr, one bit per lane
);

    logic if_id_clk_en;
    // Communication with the instruction memory
    logic if_id_flush; // Insert NOP
    // Communication instruction decoder
    instruction_u inst_id;// Registered instruction to be decode
    dataBus_t pc_id;  // PC of current instruction to decode
    logic valid_id; //[out] Instruction valid from IF
    // Next PC control
    dataBus_t jump_addr;// Jump address
    nextPCType_e pc_sel; // PC source selector

    logic cond_jump; // Used to indicate a conditional branch have been decode
    logic jalr; // Used to indicate a JALR have been decode (rs1 is a source)

	logic id_ex_clk_en; // Clock Enable
	//logic rd0_wr_en_;    //[in] Reg register (rd) write enable from Write Back stage
	dataBus_u rd0_data; //[in] Reg destination data
	logic id_ex_flush; // Insert NOP
	logic rd0_wr_en_ex;//[out] Reg destination (rd) write enable to pipeline
	aluSrc1_e alu_src1_ex; //[out] ALU source one mux selection (possible values PC/RS1)
	aluSrc2_e alu_src2_ex; //[out] ALU source two mux selection (possible values RS2/IMM) 
	dataBus_u pc_ex; //[out] PC value to EX	
	instruction_u inst_ex; //[out] Instruction word in EX
	logic valid_ex; //[out] Instruction valid in EX
	dataBus_u rs1_ex; //[out] Reg source one (rs1) data
	dataBus_u rs2_ex; //[out] Reg source two (rs2) data
	dataBus_u imm_ex; //[out] Immediate value
	logic data_rd_en_ex; //[out] Data memory read enable (wb_mux_sel) to be used with funct3 
	logic data_wr_en_ex; //[out] Data memory write enable to be used together with funct3
	aluOpType_e alu_op_ex; //[out] Opcode for alu operation ( composed by funct3ITypeALU_e)
	logic branch_taken;  //[out] Indicates that a branch should be taken to the control 
	funct3ITypeLOAD_e funct3_ex; //[out] funct3 LOAD
	regAddr_t rd0_addr_ex;  //[out] Reg destination (rd) addr
	regAddr_t rs1_addr_ex; //[out] Reg source one (rs1) addr
	regAddr_t rs2_addr_ex;  //[out] Reg source two (rs2) addr

    logic ex_ma_clk_en; //[in] Clock Enable
    ctrlAluSrc1_e alu_src1; //[in] ALU mux1 sel (PC/RS1/RD MA forward [alu_ma]/ RD WB rd0_data)
	ctrlAluSrc2_e alu_src2; //[in] ALU mux2 sel (RS2/IMM/RD MA forward [alu_ma]/ RD WB rd0_data)
    ctrlAluSrc2_e storage_src;//[in] rs2 mux2 sel (RS2/RD MA forward [alu_ma]/ RD WB rd0_data) //TODO:TBR

    logic ex_ma_flush; // Insert NOP
    ctrlCJmpSrc_e jmp_src1;//[out] JUMP mux1 sel (from RD_: EX alu_ex, MA alu_ma, WB rd0_data)
    ctrlCJmpSrc_e jmp_src2;//[out] JUMP mux2 sel (from RD_: EX alu_ex, MA alu_ma, WB rd0_data)
    dataBus_u alu_ex; //[out] ALU result from execution not registered to jump forward (ex)
    dataBus_u alu_ma; //[out] ALU result to memory access (ma)
    dataBus_u pc_ma; //[out] PC value to memory access (ma)
    instruction_u inst_ma; //[out] Instruction word in memory access (ma)
    logic valid_ma; //[out] Instruction valid in memory access (ma)
    
    dataBus_u rs2_ma; //[out] Reg source two (rs2) data
	logic rd0_wr_en_ma;//[out] Reg destination (rd) write enable to pipeline to memory access
	regAddr_t rd0_addr_ma; //[out] Reg destination (rd) addr to memory access (ma)

    logic ma_wb_clk_en;    
    funct3ITypeLOAD_e rd_wr_ctrl; //[in] funct3 LOAD from execution (ex)
    dataBus_u alu_wb; //[out] ALU result to write back (wb)
    dataBus_u pc_wb; //[out] PC value to write back (wb)
    instruction_u inst_wb; //[out] Instruction word in write back (wb)
    logic valid_wb; //[out] Instruction valid in write back (wb)
	logic rd0_wr_en_wb;//[out] Reg destination (rd) write enable to pipeline to write back
    logic wb_mux_sel_wb; //[out] Data memory read enable (wb_mux_sel) 
    dataBus_u ld_data_wb; //[out] Data from load_extension
	regAddr_t rd0_addr_wb; //[out] Reg destination (rd) addr to memory access (ma)

    dataBus_u rd0_data_wb; //[out] Reg destination (rd) data from write back (wb)

    dataBus_u rs2_raw_ma; // Store operand before the lane, source of the second beat (ma)
    logic [3:0] data_wr_strb_ma; // Byte write strobe of the beat-1 lanes (ma)
    logic split_stall; // A misaligned access holds MA for its second beat (FR-42)
    logic ld_split_en; // This cycle completes a split load (FR-42)
    dataBus_u ld_split_word; // Loaded word assembled from both beats, aligned (FR-42)

    /* WP-14 (FR-22..FR-25, FR-29, FR-32, FR-37, FR-47, FR-49..FR-52): the trap
     * observation probe binds to these four signals (wp-14 §4.2). They are
     * driven by the trap entry in ID: one cycle per trap, with the PC and the
     * instruction word of the instruction that trapped. */
    logic     trap_valid; // A trap was taken this cycle
    dataBus_t trap_pc;    // PC of the instruction that trapped
    dataBus_t trap_inst;  // Instruction word that trapped
    logic [3:0] trap_cause; // Trap cause number

    /* Zicsr interface between ID, EX and the CSR file (FR-47, FR-50). */
    csrOpType_e csr_op_ex;   // Operation of the instruction in EX
    logic       csr_valid_ex; // A legal Zicsr instruction is in EX
    logic       csr_write_ex; // That instruction writes the CSR
    logic       csr_we;       // The file must write this cycle
    logic [11:0] csr_addr;    // Address of the instruction in EX
    dataBus_t   csr_rdata;    // Value read from that address
    dataBus_u   csr_rdata_u;  // Same value on the dataBus_u the ALU consumes
    dataBus_u   csr_wdata;    // Source operand of the write, forwarded in EX
    dataBus_t   mtvec_base;   // Trap vector, mtvec.BASE (FR-29)
    trapCause_e trap_cause_id; // Synchronous cause decided in ID
    logic       ctrl_trap_valid; // Trap event from control
    trapCause_e ctrl_trap_cause; // Cause selected by control's priority

    /* FR-37: the extension set of this build, composed from the parameters
     * above by the same function the testbench's model uses (D11). */
    localparam dataBus_t MISA_VALUE = misa_value(ENABLE_A, ENABLE_M, ENABLE_C);

    assign data_rd_wr_ctrl = access_size(rd_wr_ctrl);

    assign csr_addr     = inst_ex.csr_type.csr;
    assign csr_we       = csr_valid_ex && csr_write_ex;
    assign csr_rdata_u.u_data = csr_rdata;
    assign trap_pc      = pc_id;
    assign trap_inst    = inst_id.memory_w;
    assign trap_cause   = ctrl_trap_cause;
    assign trap_valid   = ctrl_trap_valid;


    
    instruction_fetch #(
        .RESET_VECTOR (RESET_VECTOR)// Reset vector, FR-41 (Q-33)
    ) u_instruction_fetch (
        .clk          (clk), // Clock
        .clk_en       (if_id_clk_en),// Clock Enable
        .rst_n        (rst_n),// Asynchronous reset active low
        // Communication with the instruction memory
        .inst_data    (inst_data),// Data from instruction memory
        .flush        (if_id_flush),// Insert NOP
        .inst_addr    (inst_addr),// Address of next instruction
        // Communication instruction decoder
        .inst_id      (inst_id),// Registered instruction to be decode
        .pc_id        (pc_id),// PC of current instruction to decode
        .valid_id     (valid_id),//[out] Instruction valid from IF
        // Next PC control
        .jump_addr    (jump_addr),// Jump address
        .trap_addr    (mtvec_base),// Exception/interruption address, mtvec.BASE (FR-29)
        .pc_sel       (pc_sel)// PC source selector
    );

    instruction_decode u_instruction_decode (
        .clk              (clk),// Clock
	    .clk_en           (id_ex_clk_en),// Clock Enable
	    .clk_en_wb        (clk_en),//[in] Clock Enable of the register file write back
	    .rst_n            (rst_n),// Asynchronous reset active low
	    .inst             (inst_id),// Instruction from IF
	    .pc               (pc_id),// PC value from IF
	    .valid_id         (valid_id),//[in] Instruction valid from IF
        // JUMP mux1 sel (from RD_: EX alu_ex, MA alu_ma, WB rd0_data (rd0_data_wb))
        .rd0_data_ex      (alu_ex),//[in] Reg destination data forward from EX
        .rd0_data_ma      (alu_ma),//[in] Reg destination data forward from MA
        .rd0_data_wb      (rd0_data_wb),//[in] Reg destination data
	    .rd0_wr_en        (rd0_wr_en_wb),//[in] Reg destination (rd) write enable from Write Back stage
        .rd0_addr_wb      (rd0_addr_wb),//[in] Reg destination (rd) address from Write Back stage
	    .jmp_src1         (jmp_src1),//[in] JUMP forward mux1 sel (EX alu_ex/MA alu_ma/WB rd0_data)
	    .jmp_src2         (jmp_src2),//[in] JUMP forward mux2 sel (EX alu_ex/MA alu_ma/WB rd0_data)
	    .flush            (id_ex_flush),// Insert NOP
	    .rd0_wr_en_ex     (rd0_wr_en_ex),//[out] Reg destination (rd) write enable to pipeline
	    .alu_src1_ex      (alu_src1_ex),//[out] ALU source one mux selection (possible values PC/RS1)
	    .alu_src2_ex      (alu_src2_ex),//[out] ALU source two mux selection (possible values RS2/IMM) 
	    .pc_ex            (pc_ex),//[out] PC value to EX	
	    .inst_ex          (inst_ex),//[out] Instruction word to EX
	    .valid_ex         (valid_ex),//[out] Instruction valid in EX
	    .rs1_ex           (rs1_ex),//[out] Reg source one (rs1) data
	    .rs2_ex           (rs2_ex),//[out] Reg source two (rs2) data
	    .imm_ex           (imm_ex),//[out] Immediate value
	    .data_rd_en_ex    (data_rd_en_ex),//[out] Data memory read enable (wb_mux_sel) to be used with funct3 
	    .data_wr_en_ex    (data_wr_en_ex),//[out] Data memory write enable to be used together with funct3
	    .alu_op_ex        (alu_op_ex),//[out] Opcode for alu operation ( composed by funct3ITypeALU_e)
	    .branch_taken     (branch_taken),//[out] Indicates that a branch should be taken to the control 
	    .jump_addr        (jump_addr),//[out] Jump address
        .cond_jump        (cond_jump),// Used to indicate a conditional branch have been decode
        .jalr             (jalr),// Used to indicate a JALR have been decode
	    .funct3_ex        (funct3_ex),//[out] funct3 LOAD
	    .rd0_addr_ex      (rd0_addr_ex),//[out] Reg destination (rd) addr
	    .rs1_addr_ex      (rs1_addr_ex),//[out] Reg source one (rs1) addr
        .rs2_addr_ex      (rs2_addr_ex),//[out] Reg source two (rs2) addr
        .csr_op_ex        (csr_op_ex),//[out] Zicsr operation of the instruction in EX
        .csr_valid_ex     (csr_valid_ex),//[out] A legal Zicsr instruction is in EX
        .csr_write_ex     (csr_write_ex),//[out] That instruction writes the CSR
        .trap_cause_id    (trap_cause_id)//[out] Synchronous trap cause decided in ID
    );

    execution u_exection (
        .clk              (clk),//[in] Clock
        .clk_en           (ex_ma_clk_en),//[in] Clock Enable
        .rst_n            (rst_n),//[in] Asynchronous reset active low
        .alu_op           (alu_op_ex),//[in] Opcode for alu operation ( composed by funct3ITypeALU_e)
        .alu_src1         (alu_src1),//[in] ALU mux1 sel (PC/RS1/RD MA forward [alu_ma]/ RD WB rd0_data)
        .alu_src2         (alu_src2),//[in] ALU mux2 sel (RS2/IMM/RD MA forward [alu_ma]/ RD WB rd0_data)
        .storage_src      (storage_src),//[in] rs2 mux2 sel (RS2/RD MA forward [alu_ma]/ RD WB rd0_data) //TODO:TBR
        .pc               (pc_ex),//[in] PC value to EX	
        .inst             (inst_ex),//[in] Instruction word from (id)
        .valid            (valid_ex),//[in] Instruction valid from (id)
        .rs1              (rs1_ex),//[in] Reg source one (rs1) data
        .rs2              (rs2_ex),//[in] Reg source two (rs2) data
        .imm              (imm_ex),//[in] Immediate value
        .rd0_data         (rd0_data_wb),//[in] Reg destination (rd) data from write back (wb) forward
        .csr_rdata        (csr_rdata_u),//[in] Value read from the CSR addressed in EX (FR-47)
        .rd0_wr_en        (rd0_wr_en_ex),//[out] Reg destination (rd) write enable to pipeline from (id)
        .data_rd_en       (data_rd_en_ex),//[out] Data memory read enable (wb_mux_sel) to be used with funct3 
        .data_wr_en       (data_wr_en_ex),//[out] Data memory write enable to be used together with funct3
        .funct3           (funct3_ex),//[out] funct3 LOAD from instruction decode (id)
        .rd0_addr         (rd0_addr_ex),//[out] Reg destination (rd) addr from instruction decode (id)
        .flush            (ex_ma_flush),// Insert NOP
        .alu_ex           (alu_ex), //[out] ALU result from execution not registered to jump forward (ex)
        .alu_ma           (alu_ma),//[out] ALU result to memory access (ma)
        .csr_wdata        (csr_wdata),//[out] Zicsr source operand, forwarded (FR-47)
        .pc_ma            (pc_ma),//[out] PC value to memory access (ma)
        .inst_ma          (inst_ma),//[out] Instruction word to memory access (ma)
        .valid_ma         (valid_ma),//[out] Instruction valid in memory access (ma)
        .rs2_ma           (rs2_ma), //[out] Reg source two (rs2) data to data memory
        .rs2_raw_ma       (rs2_raw_ma), //[out] Reg source two (rs2) data before the store lane (ma)
        .data_wr_strb_ma  (data_wr_strb_ma), //[out] Byte write strobe to data memory
        .rd0_wr_en_ma     (rd0_wr_en_ma),//[out] Reg destination (rd) write enable to pipeline to memory access
        .data_rd_en_ma    (data_rd_en_ma),//[out] Data memory read enable (wb_mux_sel) to be used with funct3 
        .data_wr_en_ma    (data_wr_en_ma),//[out] Data memory write enable to be used together with funct3
        .funct3_ma        (rd_wr_ctrl),//[out] funct3 LOAD to memory access (ma)
        .rd0_addr_ma      (rd0_addr_ma)//[out] Reg destination (rd) addr to memory access (ma)
    );

    memory_access u_memory_access (
        .clk              (clk),//[in] Clock
        .clk_en           (ma_wb_clk_en),//[in] Clock Enable
        .rst_n            (rst_n),//[in] Asynchronous reset active low
        .alu_result       (alu_ma),//[in] ALU result to from (ex)
        .pc               (pc_ma),//[in] PC value from (ex)
        .inst             (inst_ma),//[in] Instruction word from (ex)
        .valid            (valid_ma),//[in] Instruction valid from (ex)
        .data             (data_rd),//[in] Data from data_memory
        .split_word       (ld_split_word),//[in] Loaded word assembled from both beats, aligned
        .split_ld_en      (ld_split_en),//[in] This cycle completes a split load
        .rd0_wr_en        (rd0_wr_en_ma),//[in] Reg destination (rd) write enable from (ex)
        .data_rd_en       (data_rd_en_ma),//[in] Data memory read enable (wb_mux_sel) to be used with funct3  
        .rd_wr_ctrl       (rd_wr_ctrl),//[in] funct3 LOAD from execution (ex)
        .rd0_addr         (rd0_addr_ma),//[in] Reg destination (rd) addr from execution (ex)
        .alu_wb           (alu_wb),//[out] ALU result to write back (wb)
        .pc_wb            (pc_wb),//[out] PC value to write back (wb)
        .inst_wb          (inst_wb),//[out] Instruction word to write back (wb)
        .valid_wb         (valid_wb),//[out] Instruction valid in write back (wb)
        .rd0_wr_en_wb     (rd0_wr_en_wb),//[out] Reg destination (rd) write enable to pipeline to write back
        .wb_mux_sel_wb    (wb_mux_sel_wb),//[out] Data memory read enable (wb_mux_sel) 
        .ld_data_wb       (ld_data_wb),//[out] Data from load_extension
        .rd0_addr_wb      (rd0_addr_wb) //[out] Reg destination (rd) addr to memory access (ma)
    );

    //Write Back mux
    assign rd0_data_wb = wb_mux_sel_wb? ld_data_wb : alu_wb;

    /* FR-42/G-22: the data port is driven beat by beat. With no crossing access
     * this is the EX/MA register unchanged (address, lane data and strobe), so
     * every non-misaligned access behaves exactly as before. */
    misaligned_split u_misaligned_split (
        .clk             (clk),//[in] Clock
        .clk_en          (clk_en),//[in] Clock Enable
        .rst_n           (rst_n),//[in] Asynchronous reset active low
        .addr_ma         (alu_ma),//[in] Effective address in memory access (ma)
        .funct3_ma       (rd_wr_ctrl),//[in] Access width, load or store funct3 (ma)
        .data_rd_en_ma   (data_rd_en_ma),//[in] Data memory read enable (ma)
        .data_wr_en_ma   (data_wr_en_ma),//[in] Data memory write enable (ma)
        .store_data_ma   (rs2_raw_ma),//[in] Store operand in memory access, before the lane (ma)
        .store_lane_ma   (rs2_ma),//[in] Store operand placed in the beat-1 lanes (ma)
        .store_strb_ma   (data_wr_strb_ma),//[in] Beat-1 byte write strobe (ma)
        .data_rd         (data_rd),//[in] Data from data_memory
        .data_ready      (data_ready),//[in] Indicates that data is ready
        .data_addr       (data_addr),//[out] Address of the beat on the data port
        .data_wr         (data_wr),//[out] Store data of the beat
        .data_wr_strb    (data_wr_strb),//[out] Byte write strobe of the beat
        .split_stall     (split_stall),//[out] Hold the pipeline while a split beat is outstanding
        .ld_split_en     (ld_split_en),//[out] This cycle completes a split load
        .ld_split_word   (ld_split_word)//[out] Loaded word assembled from both beats, aligned
    );

    /* FR-50: the machine-mode CSR file. It is read in EX (the address comes
     * from the instruction EX holds) and written on the same edge, so an
     * instruction that traps in ID never reaches it (wp-14 D1/D2). */
    csr_file u_csr_file (
        .clk          (clk),//[in] Clock
        .clk_en       (clk_en),//[in] Clock Enable
        .rst_n        (rst_n),//[in] Asynchronous reset active low
        .csr_addr     (csr_addr),//[in] CSR address of the instruction in EX
        .csr_rdata    (csr_rdata),//[out] Value read from that address
        .csr_we       (csr_we),//[in] Write the addressed CSR this cycle
        .csr_wdata    (csr_wdata.u_data),//[in] Source operand of the write
        .csr_op       (csr_op_ex),//[in] Zicsr operation (funct3)
        .trap_we      (ctrl_trap_valid),//[in] A trap is taken this cycle
        .trap_pc      (trap_pc),//[in] PC of the trapping instruction
        .trap_cause   (ctrl_trap_cause),//[in] Cause the trap carries
        .mtime        (mtime),//[in] Machine timer (FR-49)
        .hart_id      (hart_id),//[in] Hart identifier, read as mhartid (FR-32)
        .misa_val     (MISA_VALUE),//[in] Configuration-derived misa (FR-37)
        .retire_valid (valid_wb && ma_wb_clk_en),//[in] An instruction retires this cycle
        .valid_ma     (valid_ma),//[in] A valid instruction in MA (older than EX)
        .valid_wb     (valid_wb),//[in] A valid instruction in WB (older than EX)
        .mtvec_base   (mtvec_base)//[out] Trap vector, mtvec.BASE (FR-29)
    );

    control u_control (
        .clk              (clk),//[in] Clock
        .clk_en           (clk_en),//[in] Clock Enable
        .rst_n            (rst_n),//[in] Asynchronous reset active low
        .rs1_addr_id      (inst_id.r_type.rs1),//[in] Reg source one (rs1) addr
	    .rs2_addr_id      (inst_id.r_type.rs2),//[in] Reg source two (rs2) addr
        .rs1_addr_ex      (rs1_addr_ex),//[in] Reg source one (rs1) addr
        .rs2_addr_ex      (rs2_addr_ex),//[in] Reg source two (rs2) addr
        .rd0_addr_ex      (rd0_addr_ex),//[in] Reg destination (rd) addr
        .rd0_addr_ma      (rd0_addr_ma),//[in] Reg destination (rd) addr
        .rd0_addr_wb      (rd0_addr_wb),//[in] Reg destination (rd) addr
        .rd0_wr_en_ex     (rd0_wr_en_ex),//[in] Reg destination (rd) write enable to pipeline
        .rd0_wr_en_ma     (rd0_wr_en_ma),//[in] Reg destination (rd) write enable to pipeline
        .rd0_wr_en_wb     (rd0_wr_en_wb),//[in] Reg destination (rd) write enable to pipeline
        .data_rd_en_ex    (data_rd_en_ex),//[in] Data memory read enable (wb_mux_sel) to be used with funct3
        .data_rd_en_ma    (data_rd_en_ma),//[in] Data memory read enable (wb_mux_sel) to be used with funct3
        .data_wr_en_ma    (data_wr_en_ma),//[in] Data memory write enable to be used with funct3
        .data_wr_en_ex    (data_wr_en_ex),//[in] Data memory write enable to be used with funct3
        .split_stall      (split_stall),//[in] A misaligned access holds MA for its second beat
        .mux_sel_rd_wb    (wb_mux_sel_wb),//[in] Data memory read enable (wb_mux_sel) 
        .cond_jump        (cond_jump),//Used to indicate a conditional branch have been decoded
        .jalr             (jalr),//Used to indicate a JALR have been decoded (rs1 is a source)
        .branch_taken     (branch_taken),//[in] Indicates that a branch should be taken to the control  
        .exception        (exception),//[in] External trap cause (FR-22)
        .trap_cause_id    (trap_cause_id),//[in] Internal synchronous cause decided in ID
        .valid_id         (valid_id),//[in] The ID slot holds a real instruction
        .inst_ready       (inst_ready),//[in] Indicates that instruction from memory is available
        .data_ready       (data_ready),//[in] Indicates that data from memory is available
        .alu_src1_ex      (alu_src1_ex),//[in] ALU source one mux selection (possible values PC/RS1) (id)
        .alu_src2_ex      (alu_src2_ex),//[in] ALU source two mux selection (possible values RS2/IMM) (id)
        .alu_src1         (alu_src1),//[out] ALU mux1 sel (PC/RS1/RD MA forward [alu_ma]/ RD WB rd_data)
        .alu_src2         (alu_src2),//[out] ALU mux2 sel (RS2/IMM/RD MA forward [alu_ma]/ RD WB rd_data)
        .storage_src      (storage_src),//[out] rs2 mux2 sel (RS2/RD MA forward [alu_ma]/ RD WB rd0_data) //TODO:TBR
        .jmp_src1         (jmp_src1),//[out] JUMP mux1 sel (from RD_: EX alu_ex, MA alu_ma, WB rd0_data)
        .jmp_src2         (jmp_src2),//[out] JUMP mux2 sel (from RD_: EX alu_ex, MA alu_ma, WB rd0_data)
        .pc_sel           (pc_sel),//[out] PC source selector
        .trap_valid       (ctrl_trap_valid),//[out] A trap is taken this cycle
        .trap_cause       (ctrl_trap_cause),//[out] Cause of the trap being taken
        .inst_rd_en       (inst_rd_en),//[out] Instruction memory read enable
        .if_id_clk_en     (if_id_clk_en),// Run/Pause IF_ID
        .id_ex_clk_en     (id_ex_clk_en),// Run/Pause ID_EX
        .ex_ma_clk_en     (ex_ma_clk_en),// Run/Pause EX_MA
        .ma_wb_clk_en     (ma_wb_clk_en),// Run/Pause MA_WB
        .if_id_flush      (if_id_flush),// Insert NOP in IF_ID
        .id_ex_flush      (id_ex_flush),// Insert NOP in ID_EX
        .ex_ma_flush      (ex_ma_flush)// Insert NOP in EX_MA
    );
endmodule: riscv_small
