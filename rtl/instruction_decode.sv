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
	input instruction_u inst,
	input logic rd_wr_en_wb,
	output logic rd_wr_en,
);
	
	dataBus_u imm;

	jump_decision u_jump_decision (
    	.clk              (clk), // Clock
	    .clk_en           (clk_en), // Clock Enable
	    .rst_n            (rst_n), // Asynchronous reset active low 123
	    .rs1              (rs1), // Reg source one data
	    .rs2              (rs2), // Reg source two data
	    .imm              (imm), // Generated immediate value
	    .pc               (pc), // PC value of the current instruction
	    .funct3           (funct3), // Indicates in which condition branch should be taken
	    .cond_jump        (cond_jump), // Used to indicate a conditional branch have been decoded
	    .uncond_jump      (uncond_jump), // Used to indicate an unconditional branch have been decoded
	    .base_addr_sel    (base_addr_sel), // Indicates the branch base address source (rs1 or pc)
	    .jump_addr        (jump_addr), // Jump address
	    .branch_taken     (branch_taken), // Indicates that a branch should be taken
	    .equal            (equal), // Indicates rs1 is equal to rs2
	    .less_u           (less_u), // Indicates unsigned rs1 is less then unsigned rs2
		.less_s           (less_s) // Indicates rs1 is less then rs2
	);

	reg_file u_reg_file (
		.clk         (clk), // Clock
		.clk_en      (clk_en), // Clock Enable
		.rst_n       (rst_n), // Asynchronous reset active low
		.rs1_addr    (rs1_addr),
		.rs2_addr    (rs2_addr),
		.rd_addr     (rd_addr),
		.rd_wr_en    (rd_wr_en_wb),
		.rd_data     (rd_data),
		.rs1         (rs1),
		.rs2         (rs2),
	);

	always_comb begin: imm_gen
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

	always_comb begin: decode
		uncond_jump = '0;
		cond_jump = '0;
		rd_wr_en = '0;
		base_addr_sel = PC;
		case  (inst.i_type.opcode) 
		LUI: begin

		end
        AUIPC: begin

		end
		JAL: begin
			uncond_jump = '1;
			rd_wr_en = '1
			base_addr_sel = PC;
		end
		JALR: begin
			uncond_jump = '1;
			rd_wr_en = '1
			base_addr_sel = RS1;
		end
		BRCH_C:begin
			cond_jump = '1;
			base_addr_sel = PC;
		end
		LOAD_C: begin

		end
        STORE_C: begin

		end 
        ALUI_C: begin

		end
        ALU_C: begin

		end
        FENCE: begin

		end
        ECBK_C: begin

		end
		endcase
	end: decode


        



endmodule: instruction_decode