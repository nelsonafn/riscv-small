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
 * Package: instruction_decode
 *
 * Description: This module is responsible for decode the instruction and reads 
 * the register bank. The jump decision can be in this stage.
 *
 * Maintainer: Nelson Alves <nelsonafn@gmail.com>
 *
 * History:
 * January 03, 2021 at 22:02 - Created by Nelson Alves <nelsonafn@gmail.com>
 */

 import riscv_definitions::*; // import package into $unit space
	
module instruction_decode (
	input clk,    // Clock
	input clk_en, // Clock Enable
	input rst_n,  // Asynchronous reset active low
	input instruction_u inst, // Instruction from IF
	input dataBus_u pc,   // PC value from IF
	input logic rd0_wr_en,    //[in] Reg register (rd) write enable from Write Back stage
	input dataBus_u rd0_data, //[in] Reg destination data
	input logic flush, // Insert NOP
	output logic rd0_wr_en_ex,//[out] Reg destination (rd) write enable to pipeline
	output aluSrc1_e alu_src1_ex, //[out] ALU source one mux selection (possible values PC/RS1)
	output aluSrc2_e alu_src2_ex, //[out] ALU source two mux selection (possible values RS2/IMM) 
	output dataBus_u pc_ex, //[out] PC value to EX	
	output dataBus_u rs1_ex, //[out] Reg source one (rs1) data
	output dataBus_u rs2_ex, //[out] Reg source two (rs2) data
	output dataBus_u imm_ex, //[out] Immediate value
	output logic data_rd_en_ex, //[out] Data memory read enable (wb_mux_sel) to be used with funct3 
	output logic data_wr_en_ex, //[out] Data memory write enable to be used together with funct3
	output aluOpType_e alu_op_ex, //[out] Opcode for alu operation ( composed by funct3ITypeALU_e)
	output logic branch_taken,  //[out] Indicates that a branch should be taken to the control 
	output dataBus_u jump_addr, //[out] Jump address
	output funct3ITypeLOAD_e funct3_ex, //[out] funct3 LOAD
	output regAddr_t rd0_addr_ex,  //[out] Reg destination (rd) addr
	output regAddr_t rs1_addr_ex, //[out] Reg source one (rs1) addr
	output regAddr_t rs2_addr_ex  //[out] Reg source two (rs2) addr
);
	
	/*
	 * Signals from proc_decode to jump_decision
	 */
	aluSrc1_e base_addr_sel;// Indicates the branch base address source (rs1 or pc)
	logic cond_jump; // Used to indicate a conditional branch have been decoded
	logic uncond_jump; // Used to indicate an unconditional branch have been decoded

	/*
	 * Signals that should be registered to be used in execute stage. 
	 */
	aluSrc1_e alu_src1; // ALU source one mux selection (possible values PC/RS1)
	aluSrc2_e alu_src2; // ALU source two mux selection (possible values RS2/IMM)
	dataBus_u imm; // Immediate value 
	logic data_rd_en; // Data memory read enable to be used together with funct3
	logic data_wr_en; // Data memory write enable to be used together with funct3
	aluOpType_e alu_op;  // Opcode for alu operation (always be composed by funct3ITypeALU_e)
	dataBus_u rs1, rs2;
    logic rd0_wr_en_2pipe; //

	/*
	 * Register signals to be used in execute stage. 
	 */
	always_ff @(posedge clk or negedge rst_n) begin: proc_id_ex
		if (!rst_n || flush) begin: proc_id_ex_rst
			data_rd_en_ex <= '0;
			data_wr_en_ex <= '0;
			alu_src1_ex <= RS1;
			alu_src2_ex <= RS2;
			alu_op_ex <= ALU_ADD;
			pc_ex <= '0;
			rs1_ex <= '0;
			rs2_ex <= '0;
			imm_ex <= '0;
			rd0_addr_ex <= '0;
			rs1_addr_ex <= '0;
			rs2_addr_ex <= '0;
			rd0_wr_en_ex <= '0;
			funct3_ex <= LB;
		end: proc_id_ex_rst
		else if (clk_en) begin
			data_rd_en_ex <= data_rd_en;
			data_wr_en_ex <= data_wr_en;
			alu_src1_ex <= alu_src1;
			alu_src2_ex <= alu_src2;
			alu_op_ex <= alu_op;
			pc_ex <= pc;
			rs1_ex <= rs1;
			rs2_ex <= rs2;
			imm_ex <= imm;
			rd0_addr_ex <= inst.r_type.rd;
			rs1_addr_ex <= inst.r_type.rs1;
			rs2_addr_ex <= inst.r_type.rs2;
			rd0_wr_en_ex <= rd0_wr_en_2pipe;
			funct3_ex <= inst.i_type_load.funct3;
		end        
	end: proc_id_ex


	/*
	 * Jump Decision file instantiation
	 */
	jump_decision u_jump_decision (
	    .rs1           (rs1), //[in] Reg source one data 
	    .rs2           (rs2), //[in] Reg source two data 
	    .imm           (imm), //[in] Immediate value 
	    .pc            (pc),  //[in] PC value of the current instruction 
	    .funct3        (inst.b_type.funct3), //[in] Indicates which condition branch should be taken 
	    .cond_jump     (cond_jump),   //[in] Used to indicate a conditional branch have been decoded
	    .uncond_jump   (uncond_jump), //[in] Used to indicate an unconditional branch have been decoded
	    .base_addr_sel (base_addr_sel),//[in] Indicates the branch base address source (rs1 or pc) 
	    .jump_addr     (jump_addr),    //[out] Jump address 
	    .branch_taken  (branch_taken) //[out] Indicates that a branch should be taken 
	);

	/*
	 * Registration File instantiation
	 */
	reg_file u_reg_file (
		.clk         (clk),    //[in] Clock
		.clk_en      (clk_en), //[in] Clock Enable
		.rst_n       (rst_n),  //[in] Asynchronous reset active low
		.rs1_addr    (inst.r_type.rs1), //[in] Reg source one address
		.rs2_addr    (inst.r_type.rs2), //[in] Reg source two address
		.rd0_addr     (inst.r_type.rd),  //[in] Reg destination address
		.rd0_wr_en    (rd0_wr_en), //[in] Reg destination write enable
		.rd0_data     (rd0_data),  //[in] Reg destination data
		.rs1         (rs1), //[out] Reg source one data 
		.rs2         (rs2) //[out] Reg source two data 
	);

	/*
	 * Immediate generation
	 */
	always_comb begin: proc_imm_gen
		case (inst.i_type.opcode) inside
			JALR, LOAD_C, ALUI_C, ECBK_C: begin //I-type
				imm.s_data = inst.i_type.imm0;
			end
			STORE_C: begin //S-type
				imm.s_data = signed'({inst.s_type.imm1, inst.s_type.imm0});
			end
			BRCH_C: begin //B-type
				imm.s_data = signed'({inst.b_type.imm4, inst.b_type.imm3, inst.b_type.imm2, 
										inst.b_type.imm1, 1'b0});
			end
			LUI, AUIPC: begin //U-type
				imm.s_data = signed'({inst.u_type.imm1, 12'b0});
			end
			JAL: begin //J-type
				imm.s_data = signed'({inst.j_type.imm4, inst.j_type.imm3, inst.j_type.imm2, 
										inst.j_type.imm1, 1'b0});
			end
			default: begin
				imm.s_data = '0;
			end    
		endcase
	end: proc_imm_gen

	/*
	 * Instruction decoder
	 */
	always_comb begin: proc_decode
		uncond_jump = '0;
		cond_jump = '0;
		rd0_wr_en_2pipe = '0;
		base_addr_sel = PC;
		alu_src1 = RS1; 
		alu_src2 = RS2; 
		data_rd_en = '0;
		data_wr_en = '0; 
		alu_op = ALU_ADD;
		case  (inst.r_type.opcode) 
		LUI: begin
			//bypass src2 (funct7 and funct3 is undefined)
			alu_op = ALU_BPS2;
			alu_src2 = IMM;
		end
        AUIPC: begin
			//add+4 (funct7 and funct3 is undefined)
			alu_op = ALU_ADD;
			alu_src1 = PC;
			alu_src2 = IMM;
		end
		JAL: begin
			uncond_jump = '1;
			rd0_wr_en_2pipe = '1;
			base_addr_sel = PC;
			//add+4 (funct7 and funct3 is undefined)
			alu_op = ALU_ADD4; 
			alu_src1 = PC;
		end
		// Branch are calculated and decided independent of ALU in a specific unit
		JALR: begin
			uncond_jump = '1;
			rd0_wr_en_2pipe = '1;
			base_addr_sel = RS1;
			//add+4 (funct7 and funct3 is undefined)
			alu_op = ALU_ADD4;
			alu_src1 = PC;
		end
		// Branch are calculated and decided independent of ALU in a specific unit
		BRCH_C:begin
			cond_jump = '1;
			base_addr_sel = PC;
		end
		LOAD_C: begin
			//add+4 (funct7 is undefined, funct3 have other use)
			alu_op = ALU_ADD;
			alu_src1 = RS1;
			alu_src2 = IMM;

			/*
			 * funct3 should be used in WB stage to define Load type (LW=32, LH=16bit signal extended, 
			 * LB=8bit signal extended, LHU=16bit zero extended and , LBU=8bit zero extended).
			 * funct3[1:0] defines how many bytes should be read ('b00=8bit 'b01=16bits '11=32bits).
			 * funct3[2] defines if zero or signal extended ('b0=signal extended 'b1= zero extended).
			 */
			data_rd_en = '1;
		end
        STORE_C: begin
			//bypass src2 (funct7 is undefined, funct3 have other use)
			alu_op = ALU_BPS2; 
			alu_src2 = RS2;

			/*
			 * funct3 should be used in WB stage to define STORE type (SW=32, SH=16bit, SB=8bit).
			 * funct3[1:0] defines how many bytes should be write ('b00=8bit 'b01=16bits '11=32bits).
			 */
			data_wr_en = '1;
		end 
        ALUI_C: begin
			// funct7[5],funct3 or 1'b0,funct3 (don't have SUBI, SRAI uses funct7). See ISA spec.
			// In this special case, this instruction can be interpreted as R-Type to get funct7[5]
			if (inst.i_type_alu.funct3 == SRLI_SRAI) begin
				alu_op = aluOpType_e'({inst.r_type.funct7[5], inst.r_type.funct3});
			end
			//In other case it is always zero. See ISA spec.
			else begin
				alu_op = aluOpType_e'({1'b0, inst.r_type.funct3});
			end
			alu_src1 = RS1;
			alu_src2 = IMM;
		end
        ALU_C: begin
			//funct7[0],funct3 (SUB and SRA uses funct7)
			alu_op = aluOpType_e'({inst.r_type.funct7[5], inst.r_type.funct3});
			alu_src1 = RS1; 
			alu_src2 = RS2; 
		end
        FENCE: begin
			//TODO:
		end
        ECBK_C: begin
			//TODO:
		end
		endcase
	end: proc_decode


        



endmodule: instruction_decode