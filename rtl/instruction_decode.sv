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
	input dataBus_u pc; // PC value from IF
	input logic rd_wr_en_wb, // Destination register (rd) write enable from Write Back stage
	output logic rd_wr_en_ex, // Destination register (rd) write enable 
	output aluSrc1_e alu_src1_ex, // ALU source one mux selection (possible values PC/RS1)
	output aluSrc2_e alu_src2_ex, // ALU source two mux selection (possible values RS2/IMM)
	output dataBus_u imm_ex, // Immediate value 
	output logic data_rd_en_ex, // Data memory read enable to be used together with funct3 and wb_mux_sel
	output logic data_wr_en_ex, // Data memory write enable to be used together with funct3
	output aluOpType_e alu_op_ex, // Opcode for alu operation (always be composed by funct3ITypeALU_e)
	input dataBus_u pc_ex; // PC value to EX
);
	
	logic rd_wr_en; // Destination register (rd) write enable 
	aluSrc1_e alu_src1; // ALU source one mux selection (possible values PC/RS1)
	aluSrc2_e alu_src2; // ALU source two mux selection (possible values RS2/IMM)
	dataBus_u imm; // Immediate value 
	logic data_rd_en; // Data memory read enable to be used together with funct3
	logic data_wr_en; // Data memory write enable to be used together with funct3
	aluOpType_e alu_op;  // Opcode for alu operation (always be composed by funct3ITypeALU_e)

	always_ff @(posedge clk or negedge rst_n) begin: proc_id_ex
		if (!rst_n) begin: proc_id_ex_rst
			proc_id_ex <= '0
		end: proc_id_ex_rst
		else if (clk_en) begin
			proc_id_ex <= 
		end        
	end: proc_id_ex

	/*
	 * Jump Decision file instantiation
	 */
	jump_decision u_jump_decision (
    	.clk              (clk), // Clock input
	    .clk_en           (clk_en), // Clock Enable input
	    .rst_n            (rst_n), // Asynchronous reset active low input
	    .rs1              (rs1), // Reg source one data input
	    .rs2              (rs2), // Reg source two data input
	    .imm              (imm), // Immediate value input
	    .pc               (pc), // PC value of the current instruction input
	    .funct3           (inst.b_type.funct3), // Indicates in which condition branch should be taken input
	    .cond_jump        (cond_jump), // Used to indicate a conditional branch have been decoded
	    .uncond_jump      (uncond_jump), // Used to indicate an unconditional branch have been decoded
	    .base_addr_sel    (base_addr_sel), // Indicates the branch base address source (rs1 or pc) 
	    .jump_addr        (jump_addr), // Jump address output
	    .branch_taken     (branch_taken), // Indicates that a branch should be taken output
	    .equal            (equal), // Indicates rs1 is equal to rs2 output
	    .less_u           (less_u), // Indicates unsigned rs1 is less then unsigned rs2 output
		.less_s           (less_s) // Indicates rs1 is less then rs2 output
	);

	/*
	 * Registration File instantiation
	 */
	reg_file u_reg_file (
		.clk         (clk), // Clock input
		.clk_en      (clk_en), // Clock Enable input
		.rst_n       (rst_n), // Asynchronous reset active low input
		.rs1_addr    (rs1_addr), // Reg source one address input
		.rs2_addr    (rs2_addr), // Reg source two address input
		.rd_addr     (rd_addr), // Reg destination address input
		.rd_wr_en    (rd_wr_en_wb), // Reg destination write enable input
		.rd_data     (rd_data), // Reg destination data input
		.rs1         (rs1), // Reg source one data output
		.rs2         (rs2), // Reg source two data output
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
			default: begin
				imm.s_data = '0
			end    
		endcase
	end: imm_gen

	/*
	 * Instruction decoder
	 */
	always_comb begin: proc_decode
		uncond_jump = '0;
		cond_jump = '0;
		rd_wr_en = '0;
		base_addr_sel = PC;
		alu_src1 = RS1; 
		alu_src2 = RS2; 
		data_rd_en = '0;
		data_wr_en = '0; 
		alu_op = ADD;
		case  (inst.r_type.opcode) 
		LUI: begin
			//bypass src2 (funct7 and funct3 is undefined)
			alu_op = BPS2;
			alu_src2 = IMM;
		end
        AUIPC: begin
			//add+4 (funct7 and funct3 is undefined)
			alu_op = ADD;
			alu_src1 = PC;
			alu_src2 = IMM;
		end
		JAL: begin
			uncond_jump = '1;
			rd_wr_en = '1
			base_addr_sel = PC;
			//add+4 (funct7 and funct3 is undefined)
			alu_op = ADD4; 
			alu_src1 = PC;
		end
		// Branch are calculated and decided independent of ALU in a specific unit
		JALR: begin
			uncond_jump = '1;
			rd_wr_en = '1;
			base_addr_sel = RS1;
			//add+4 (funct7 and funct3 is undefined)
			alu_op = ADD4;
			alu_src1 = PC;
		end
		// Branch are calculated and decided independent of ALU in a specific unit
		BRCH_C:begin
			cond_jump = '1;
			base_addr_sel = PC;
		end
		LOAD_C: begin
			//add+4 (funct7 is undefined, funct3 have other use)
			alu_op = ADD;
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
			alu_op = BPS2; 
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
				alu_op = {inst.r_type.funct7[5], inst.r_type.funct3};
			end
			//In other case it is always zero. See ISA spec.
			else begin
				alu_op = {1'b0, inst.r_type.funct3};
			end
			alu_src1 = RS1;
			alu_src2 = IMM;
		end
        ALU_C: begin
			//funct7[0],funct3 (SUB and SRA uses funct7)
			alu_op = {inst.r_type.funct7[5], inst.r_type.funct3};
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
	end: decode


        



endmodule: instruction_decode