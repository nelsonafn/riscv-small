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
 
module riscv_small (
    input clk,    //[in] Clock
    input clk_en, //[in] Clock Enable
    input rst_n,  //[in] Asynchronous reset active low
    input logic exception, //[in] exception
    // Instruction Memory controls
    input logic inst_ready, //[in] Indicates that data instruction ready
    input instruction_u inst_data, //[in] Data from instruction memory
    output dataBus_u inst_addr,//[out] Address of next instruction
    output logic inst_rd_en, //[out] Instruction memory read enable 
    // Data Memory controls
    input logic data_ready, //[in] Indicates that data is ready
    input dataBus_u data_rd, //[in] Data from data_memory
    output logic data_rd_en_ma, //[out] Data memory read enable to be used with data_rd_wr_ctrl 
	output logic data_wr_en_ma, //[out] Data memory write enable to be used with data_rd_wr_ctrl
    output dataBus_u data_wr, //[out] Data to data_memory
    output logic [1:0] data_rd_wr_ctrl //[out] 2'b00 = 8bits, 2'b01 = 16bits, 2'b10 = 32bits,
);

    logic if_id_clk_en;
    // Communication with the instruction memory
    logic if_id_flush; // Insert NOP
    // Communication instruction decoder
    instruction_u inst_id;// Registered instruction to be decode
    dataBus_u pc_id;  // PC of current instruction to decode
    // Next PC control
    dataBus_u jump_addr;// Jump address
    dataBus_u trap_addr;// Exception/interruption address
    nextPCType_e pc_sel; // PC source selector

	logic id_ex_clk_en; // Clock Enable
	//logic rd0_wr_en_;    //[in] Reg register (rd) write enable from Write Back stage
	dataBus_u rd0_data; //[in] Reg destination data
	logic id_ex_flush; // Insert NOP
	logic rd0_wr_en_ex;//[out] Reg destination (rd) write enable to pipeline
	aluSrc1_e alu_src1_ex; //[out] ALU source one mux selection (possible values PC/RS1)
	aluSrc2_e alu_src2_ex; //[out] ALU source two mux selection (possible values RS2/IMM) 
	dataBus_u pc_ex; //[out] PC value to EX	
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
    ctrlAluSrc2_e storage_src;//[in] rs2 mux2 sel (RS2/RD MA forward [alu_ma]/ RD WB rd0_data)

    logic ex_ma_flush; // Insert NOP
    dataBus_u alu_ma; //[out] ALU result to memory access (ma)
    dataBus_u rs2_ma; //[out] Reg source two (rs2) data
	logic rd0_wr_en_ma;//[out] Reg destination (rd) write enable to pipeline to memory access
	regAddr_t rd0_addr_ma; //[out] Reg destination (rd) addr to memory access (ma)

    logic ma_wb_clk_en;    
    funct3ITypeLOAD_e rd_wr_ctrl; //[in] funct3 LOAD from execution (ex)
    dataBus_u alu_wb; //[out] ALU result to write back (wb)
	logic rd0_wr_en_wb;//[out] Reg destination (rd) write enable to pipeline to write back
    logic wb_mux_sel_wb; //[out] Data memory read enable (wb_mux_sel) 
    dataBus_u ld_data_wb; //[out] Data from load_extension
	regAddr_t rd0_addr_wb; //[out] Reg destination (rd) addr to memory access (ma)

    dataBus_u rd0_data_wb; //[out] Reg destination (rd) data from write back (wb)


    assign data_rd_wr_ctrl = logic'(rd_wr_ctrl);
    
    instruction_fetch u_instruction_fetch (
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
        // Next PC control
        .jump_addr    (jump_addr),// Jump address
        .trap_addr    (trap_addr),// Exception/interruption address
        .pc_sel       (pc_sel)// PC source selector
    );

    instruction_decode u_instruction_decode (
        .clk              (clk),// Clock
	    .clk_en           (id_ex_clk_en),// Clock Enable
	    .rst_n            (rst_n),// Asynchronous reset active low
	    .inst             (inst_id),// Instruction from IF
	    .pc               (pc_id),// PC value from IF
	    .rd0_wr_en        (rd0_wr_en_wb),//[in] Reg destination (rd) write enable from Write Back stage
        .rd0_addr_wb      (rd0_addr_wb),//[in] Reg destination (rd) address from Write Back stage
	    .rd0_data         (rd0_data_wb),//[in] Reg destination data
	    .flush            (id_ex_flush),// Insert NOP
	    .rd0_wr_en_ex     (rd0_wr_en_ex),//[out] Reg destination (rd) write enable to pipeline
	    .alu_src1_ex      (alu_src1_ex),//[out] ALU source one mux selection (possible values PC/RS1)
	    .alu_src2_ex      (alu_src2_ex),//[out] ALU source two mux selection (possible values RS2/IMM) 
	    .pc_ex            (pc_ex),//[out] PC value to EX	
	    .rs1_ex           (rs1_ex),//[out] Reg source one (rs1) data
	    .rs2_ex           (rs2_ex),//[out] Reg source two (rs2) data
	    .imm_ex           (imm_ex),//[out] Immediate value
	    .data_rd_en_ex    (data_rd_en_ex),//[out] Data memory read enable (wb_mux_sel) to be used with funct3 
	    .data_wr_en_ex    (data_wr_en_ex),//[out] Data memory write enable to be used together with funct3
	    .alu_op_ex        (alu_op_ex),//[out] Opcode for alu operation ( composed by funct3ITypeALU_e)
	    .branch_taken     (branch_taken),//[out] Indicates that a branch should be taken to the control 
	    .jump_addr        (jump_addr),//[out] Jump address
	    .funct3_ex        (funct3_ex),//[out] funct3 LOAD
	    .rd0_addr_ex      (rd0_addr_ex),//[out] Reg destination (rd) addr
	    .rs1_addr_ex      (rs1_addr_ex),//[out] Reg source one (rs1) addr
        .rs2_addr_ex      (rs2_addr_ex)//[out] Reg source two (rs2) addr
    );

    execution u_exection (
        .clk              (clk),//[in] Clock
        .clk_en           (ex_ma_clk_en),//[in] Clock Enable
        .rst_n            (rst_n),//[in] Asynchronous reset active low
        .alu_op           (alu_op_ex),//[in] Opcode for alu operation ( composed by funct3ITypeALU_e)
        .alu_src1         (alu_src1),//[in] ALU mux1 sel (PC/RS1/RD MA forward [alu_ma]/ RD WB rd0_data)
        .alu_src2         (alu_src2),//[in] ALU mux2 sel (RS2/IMM/RD MA forward [alu_ma]/ RD WB rd0_data)
        .storage_src      (storage_src),//[in] rs2 mux2 sel (RS2/RD MA forward [alu_ma]/ RD WB rd0_data)
        .pc               (pc_ex),//[in] PC value to EX	
        .rs1              (rs1_ex),//[in] Reg source one (rs1) data
        .rs2              (rs2_ex),//[in] Reg source two (rs2) data
        .imm              (imm_ex),//[in] Immediate value
        .rd0_data         (rd0_data_wb),//[in] Reg destination (rd) data from write back (wb) forward
        .rd0_wr_en        (rd0_wr_en_ex),//[out] Reg destination (rd) write enable to pipeline from (id)
        .data_rd_en       (data_rd_en_ex),//[out] Data memory read enable (wb_mux_sel) to be used with funct3 
        .data_wr_en       (data_wr_en_ex),//[out] Data memory write enable to be used together with funct3
        .funct3           (funct3_ex),//[out] funct3 LOAD from instruction decode (id)
        .rd0_addr         (rd0_addr_ex),//[out] Reg destination (rd) addr from instruction decode (id)
        .flush            (ex_ma_flush),// Insert NOP
        .alu_ma           (alu_ma),//[out] ALU result to memory access (ma)
        .rs2_ma           (data_wr), //[out] Reg source two (rs2) data to data memory
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
        .data             (data_rd),//[in] Data from data_memory
        .rd0_wr_en        (rd0_wr_en_ma),//[in] Reg destination (rd) write enable from (ex)
        .data_rd_en       (data_rd_en_ma),//[in] Data memory read enable (wb_mux_sel) to be used with funct3  
        .rd_wr_ctrl       (rd_wr_ctrl),//[in] funct3 LOAD from execution (ex)
        .rd0_addr         (rd0_addr_ma),//[in] Reg destination (rd) addr from execution (ex)
        .alu_wb           (alu_wb),//[out] ALU result to write back (wb)
        .rd0_wr_en_wb     (rd0_wr_en_wb),//[out] Reg destination (rd) write enable to pipeline to write back
        .wb_mux_sel_wb    (wb_mux_sel_wb),//[out] Data memory read enable (wb_mux_sel) 
        .ld_data_wb       (ld_data_wb),//[out] Data from load_extension
        .rd0_addr_wb      (rd0_addr_wb) //[out] Reg destination (rd) addr to memory access (ma)
    );

    //Write Back mux
    assign rd0_data_wb = wb_mux_sel_wb? ld_data_wb : alu_wb;


    control u_control (
        .clk              (clk),//[in] Clock
        .clk_en           (clk_en),//[in] Clock Enable
        .rst_n            (rst_n),//[in] Asynchronous reset active low
        .rs1_addr_ex      (rs1_addr_ex),//[in] Reg source one (rs1) addr
        .rs2_addr_ex      (rs2_addr_ex),//[in] Reg source two (rs2) addr
        .rd0_addr_ma      (rd0_addr_ma),//[in] Reg destination (rd) addr
        .rd0_addr_wb      (rd0_addr_wb),//[in] Reg destination (rd) addr
        .rd0_wr_en_ma     (rd0_wr_en_ma),//[in] Reg destination (rd) write enable to pipeline
        .rd0_wr_en_wb     (rd0_wr_en_wb),//[in] Reg destination (rd) write enable to pipeline
        .data_rd_en_ma    (data_rd_en_ma),//[in] Data memory read enable (wb_mux_sel) to be used with funct3
        .data_wr_en_ex    (data_wr_en_ex),  //[in] Data memory write enable to be used with funct3
        .branch_taken     (branch_taken),//[in] Indicates that a branch should be taken to the control  
        .exception        (exception),//[in] Exception trigger
        .pc_ex            (pc_ex),//[in] PC value to EX
        .inst_ready       (inst_ready),//[in] Indicates that instruction from memory is available
        .data_ready       (data_ready),//[in] Indicates that data from memory is available
        .alu_src1_ex      (alu_src1_ex),//[in] ALU source one mux selection (possible values PC/RS1) (id)
        .alu_src2_ex      (alu_src2_ex),//[in] ALU source two mux selection (possible values RS2/IMM) (id)
        .alu_src1         (alu_src1),//[out] ALU mux1 sel (PC/RS1/RD MA forward [alu_ma]/ RD WB rd_data)
        .alu_src2         (alu_src2),//[out] ALU mux2 sel (RS2/IMM/RD MA forward [alu_ma]/ RD WB rd_data)
        .storage_src      (storage_src),//[out] rs2 mux2 sel (RS2/RD MA forward [alu_ma]/ RD WB rd0_data)
        .pc_sel           (pc_sel),//[out] PC source selector
        .trap_addr        (trap_addr),//[out] Trap Addr
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