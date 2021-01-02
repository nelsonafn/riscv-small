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
 * Package: jump_decision
 *
 * This module is responsible for compare sources data (rs1 and rs2), calculate 
 * the branch address and take the decision regarding the branch should be taken.
 *
 * Maintainer: Nelson Alves <nelsonafn@gmail.com>
 * Revision : $Revision$
 *
 * History:
 * $Log$ 
 */

 import riscv_definitions::*; // import package into $unit space

module jump_decision (
	input clk,    // Clock
	input clk_en, // Clock Enable
	input rst_n,  // Asynchronous reset active low 123
	input dataBus_u rs1, // Reg source one data
	input dataBus_u rs2, // Reg source two data
	input dataBus_u imm, // Generated immediate value
	input dataBus_u pc,  // PC value of the current instruction
	input funct3BType_e funct3, // Indicates in which condition branch should be taken
	input logic cbranch_decoded, // Used to indicate a conditional branch have been decoded
	input logic ubranch_decoded, // Used to indicate an unconditional branch have been decoded
	input branchBaseSrcType_e base_addr_sel, // Indicates the branch base address source (rs1 or pc)
	output dataBus_u jump_address, // Jump address
	output logic branch_taken,  // Indicates that a branch should be taken
	output logic equal,
	output logic less_u,
	output logic less_s
);
	/* 
     * Used for the mux for base address
     */
	dataBus_u base_addr;

	/* 
     * Make the comparison of rs1 and rs2
     */
	always_comb begin: comp
		if (rs1 == rs2) begin
			equal = 1'b1;
		end
		else begin
			equal = 1'b0;
		end

		// Unsigned comparison 
		if (rs1.u_data < rs2.u_data) begin
			less_u = 1'b1;
		end
		else begin
			less_u = 1'b0;
		end

		// Signed comparison 
		if (rs1.s_data < rs2.s_data) begin
			less_s = 1'b1;
		end
		else begin
			less_s = 1'b0;
		end
		
	end: comp

	/* 
     * Calculate the address of the branch.
	 * It uses only the less 20 significative bits of the immediate since J-type 
	 * and B-type immediate is maximum 20 bit long.
     */
	always_comb begin: addr_calc
		case (base_addr_sel)
			PC: begin
				base_addr = pc;
			end
			RS1:begin
				base_addr = rs1;
			end
			default: begin
				base_addr = pc;
			end
		endcase

		jump_address = base_addr + imm[20:0];
	end: addr_calc

	/* 
     * Make the decision about take or not the branch
     */
	always_comb begin: decision
		branch_taken = 1'b0;
		if (cbranch_decoded) begin
			case (funct3)
				BEQ: begin
					if (equal) begin
						branch_taken = 1'b1;
					end
				end    
				BNE: begin
					if (!equal) begin
						branch_taken = 1'b1;
					end
				end    
				// rs1 is less than rs2 using signed comparison
				BLT: begin 
					if (less_s) begin
						branch_taken = 1'b1;
					end
				end    
				// rs1 is greater than or equal to rs2 using signed comparison
				BGE: begin 
					if (!less_s) begin
						branch_taken = 1'b1;
					end
				end    
				// rs1 is less than rs2 using unsigned comparison
				BLTU: begin
					if (less_u) begin
						branch_taken = 1'b1;
					end
				end    
				// rs1 is greater than or equal to rs2 using unsigned comparison
				BGEU: begin 
					if (!less_u) begin
						branch_taken = 1'b1;
					end
				end 
				default: begin
					branch_taken = 1'b0;
				end
			endcase
		end 
		else if (ubranch_decoded) begin
			branch_taken = 1'b1;
		end
   
	end: decision


endmodule: jump_decision