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

	
module instruction_decode 
import riscv_definitions_pkg::*;
(
	input clk,    // Clock
	input clk_en, // Clock Enable
	input logic clk_en_wb, //[in] Clock Enable of the register file write back
	input rst_n,  // Asynchronous reset active low
	input instruction_u inst, // Instruction from IF
	input dataBus_t pc,   // PC value from IF
	input logic valid_id, //[in] Instruction valid from IF (0 when the fetch is flushed)
    // JUMP mux1 sel (from RD_: EX alu_ex, MA alu_ma, WB rd0_data (rd0_data_wb))
    input dataBus_t rd0_data_ex,//[in] Reg destination data forward from EX
    input dataBus_t rd0_data_ma,//[in] Reg destination data forward from MA
    input dataBus_t rd0_data_wb,//[in] Reg destination data from WB
	input logic rd0_wr_en,    //[in] Reg destination (rd) write enable from Write Back stage
	input regAddr_t rd0_addr_wb, //[in] Reg destination (rd) address from Write Back stage
	input ctrlCJmpSrc_e jmp_src1,//[out] JUMP forward mux1 sel (from RD_: EX alu_ex, MA alu_ma, WB rd0_data)
    input ctrlCJmpSrc_e jmp_src2,//[out] JUMP forward mux2 sel (from RD_: EX alu_ex, MA alu_ma, WB rd0_data)
	input logic flush, // Insert NOP
	output logic rd0_wr_en_ex,//[out] Reg destination (rd) write enable to pipeline
	output aluSrc1_e alu_src1_ex, //[out] ALU source one mux selection (possible values PC/RS1)
	output aluSrc2_e alu_src2_ex, //[out] ALU source two mux selection (possible values RS2/IMM) 
	output dataBus_t pc_ex, //[out] PC value to EX	
	output instruction_u inst_ex, //[out] Instruction word to EX
	output logic valid_ex, //[out] Instruction valid in EX (cleared by flush)
	output dataBus_t rs1_ex, //[out] Reg source one (rs1) data
	output dataBus_t rs2_ex, //[out] Reg source two (rs2) data
	output dataBus_t imm_ex, //[out] Immediate value
	output logic data_rd_en_ex, //[out] Data memory read enable (wb_mux_sel) to be used with funct3 
	output logic data_wr_en_ex, //[out] Data memory write enable to be used together with funct3
	output aluOpType_e alu_op_ex, //[out] Opcode for alu operation ( composed by funct3ITypeALU_e)
	output logic branch_taken,  //[out] Indicates that a branch should be taken to the control 
	output dataBus_t jump_addr, //[out] Jump address
    output logic cond_jump, // Used to indicate a conditional branch have been decoded
	output logic jalr, // Used to indicate a JALR have been decoded (its target reads rs1)
	output funct3ITypeLOAD_e funct3_ex, //[out] funct3 LOAD
	output regAddr_t rd0_addr_ex,  //[out] Reg destination (rd) addr
	output regAddr_t rs1_addr_ex, //[out] Reg source one (rs1) addr
	output regAddr_t rs2_addr_ex,  //[out] Reg source two (rs2) addr
	output csrOpType_e csr_op_ex, //[out] Zicsr operation of the instruction in EX (FR-47)
	output logic csr_valid_ex, //[out] A legal Zicsr instruction is in EX
	output logic csr_write_ex, //[out] The Zicsr instruction writes the CSR
	output trapCause_e trap_cause_id //[out] Synchronous trap cause decided in ID
);
	
	/*
	 * Signals from proc_decode to jump_decision
	 */
	aluSrc1_e base_addr_sel;// Indicates the branch base address source (rs1 or pc)
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
	dataBus_t rs1, rs2, rs1_jump, rs2_jump;
    logic rd0_wr_en_2pipe; //

	/*
	 * Zicsr decode (FR-47, FR-50). The legality is decided HERE, in ID, from
	 * the address and the encoding alone: the instruction that writes a CSR is
	 * either flushed before it reaches EX or it writes, never both (wp-14 D1).
	 */
	csrOpType_e csr_op;  // operation of the instruction in ID
	logic csr_valid;     // a legal Zicsr access
	logic csr_write;     // that access writes the CSR
	logic legal;         // the encoding is in the implemented subset (FR-24)

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
			inst_ex <= '0;
			valid_ex <= '0;
			rs1_ex <= '0;
			rs2_ex <= '0;
			imm_ex <= '0;
			rd0_addr_ex <= '0;
			rs1_addr_ex <= '0;
			rs2_addr_ex <= '0;
			rd0_wr_en_ex <= '0;
			funct3_ex <= LB;
			csr_op_ex <= CSRRW;
			csr_valid_ex <= '0;
			csr_write_ex <= '0;
		end: proc_id_ex_rst
		else if (clk_en) begin
			data_rd_en_ex <= data_rd_en;
			data_wr_en_ex <= data_wr_en;
			alu_src1_ex <= alu_src1;
			alu_src2_ex <= alu_src2;
			alu_op_ex <= alu_op;
			pc_ex <= pc;
			inst_ex <= inst;
			valid_ex <= valid_id && !flush;
			imm_ex <= imm;
			rd0_addr_ex <= inst.r_type.rd;
			rs1_addr_ex <= inst.r_type.rs1;
			rs2_addr_ex <= inst.r_type.rs2;
			rd0_wr_en_ex <= rd0_wr_en_2pipe;
			funct3_ex <= inst.i_type_load.funct3;
			rs1_ex <= rs1;
			rs2_ex <= rs2;
			csr_op_ex <= csr_op;
			csr_valid_ex <= csr_valid;
			csr_write_ex <= csr_write;
		end        
	end: proc_id_ex

	/*
	 * Jump Decision mux
	 */
	always_comb begin: proc_jump_forward_mux
		rs1_jump = rs1;
		rs2_jump = rs2;
        //JUMP mux1 sel (from RD_: EX alu_ex, MA alu_ma, WB rd0_data)
		case (jmp_src1)
			RD_ID: begin
				rs1_jump = rs1;
			end
			//Do forward from write back
			RD_EX: begin 
                rs1_jump = rd0_data_ex;
			end
			//Do forward from memory access
			RD_MA: begin 
                rs1_jump = rd0_data_ma;
			end
			//Do forward from write back
			RD_WB: begin 
                rs1_jump = rd0_data_wb;
			end
		endcase
        //JUMP mux2 sel (from RD_: EX alu_ex, MA alu_ma, WB rd0_data)
		case (jmp_src2)
			RD_ID: begin
                rs2_jump = rs2;
			end
			//Do forward from write back
			RD_EX: begin 
                rs2_jump = rd0_data_ex;
			end
			//Do forward from memory access
			RD_MA: begin 
                rs2_jump = rd0_data_ma;
			end
			//Do forward from write back
			RD_WB: begin 
                rs2_jump = rd0_data_wb;
			end
		endcase
	end: proc_jump_forward_mux
	/*
	 * Jump Decision file instantiation
	 */
	jump_decision u_jump_decision (
	    .rs1           (rs1_jump), //[in] Reg source one data 
	    .rs2           (rs2_jump), //[in] Reg source two data 
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
	 *
	 * The register file uses its own clock enable (clk_en_wb), not the ID/EX
	 * stage enable: a load-use hazard clears clk_en, and gating the write back
	 * with it would drop the write of a younger instruction that WB is already
	 * holding (G-19). During the bubble WB holds a completed instruction;
	 * rewriting the same register on the next cycle is idempotent, so the
	 * global clock enable is safe here. rd0_wr_en still qualifies the write.
	 */
	reg_file u_reg_file (
		.clk         (clk),    //[in] Clock
		.clk_en      (clk_en_wb), //[in] Clock Enable from write back
		.rst_n       (rst_n),  //[in] Asynchronous reset active low
		.rs1_addr    (inst.r_type.rs1), //[in] Reg source one address
		.rs2_addr    (inst.r_type.rs2), //[in] Reg source two address
		.rd0_addr     (rd0_addr_wb),  //[in] Reg destination address from write back
		.rd0_wr_en    (rd0_wr_en), //[in] Reg destination write enable
		.rd0_data     (rd0_data_wb),  //[in] Reg destination data
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
	 * Instruction legality and the synchronous trap cause (FR-24, FR-25,
	 * FR-47, FR-50). One truth table, read from the encoding:
	 *   - an opcode outside the implemented subset of doc/spec.md §4.1 traps;
	 *   - a reserved funct3/funct7 of an implemented instruction traps;
	 *   - ECALL/EBREAK carry their causes; MRET/WFI stay legal no-operations
	 *     (FR-45/FR-46) so they retire like every other machine-mode no-op;
	 *   - an absent CSR address, a write to a read-only address (csr[11:10] =
	 *     2'b11) and the reserved SYSTEM encodings trap with cause 2.
	 * The write test is on the ENCODING -- CSRRW/CSRRWI always write, the
	 * set/clear forms write when their source field is not x0/0 -- which is
	 * what FR-50 states and what keeps the decision in ID, before any effect.
	 */
	always_comb begin: proc_legality
		legal = 1'b1;
		csr_op = CSRRW;
		csr_valid = 1'b0;
		csr_write = 1'b0;
		trap_cause_id = TRAP_NONE;

		case (inst.r_type.opcode)
		LUI, AUIPC, JAL, FENCE: begin
			// Always legal in this build.
		end
		JALR: begin
			if (inst.i_type.funct3 != 3'b000) legal = 1'b0;
		end
		BRCH_C: begin
			case (inst.b_type.funct3)
				3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111: ;
				default: legal = 1'b0;
			endcase
		end
		LOAD_C: begin
			case (inst.i_type_load.funct3)
				3'b000, 3'b001, 3'b010, 3'b100, 3'b101: ;
				default: legal = 1'b0;
			endcase
		end
		STORE_C: begin
			case (inst.s_type.funct3)
				3'b000, 3'b001, 3'b010: ;
				default: legal = 1'b0;
			endcase
		end
		ALUI_C: begin
			// The shifts are the arm with a funct7 field in RV32.
			case (inst.i_type_alu.funct3)
				3'b001: if (inst.r_type.funct7 != 7'b0000000) legal = 1'b0;
				3'b101: if ((inst.r_type.funct7 != 7'b0000000) &&
				            (inst.r_type.funct7 != 7'b0100000)) legal = 1'b0;
				default: ;
			endcase
		end
		ALU_C: begin
			case (inst.r_type.funct3)
				3'b000, 3'b101: if ((inst.r_type.funct7 != 7'b0000000) &&
				                   (inst.r_type.funct7 != 7'b0100000)) legal = 1'b0;
				default: if (inst.r_type.funct7 != 7'b0000000) legal = 1'b0;
			endcase
		end
		ECBK_C: begin
			case (inst.csr_type.funct3)
				3'b000: begin
					case (inst.csr_type.csr)
						12'h000: trap_cause_id = TRAP_ECALL_M;      // ECALL, FR-25
						12'h001: trap_cause_id = TRAP_BREAKPOINT;   // EBREAK FR-25
						12'h302, 12'h105: ; // MRET/WFI: legal no-operation
						default: legal = 1'b0;
					endcase
				end
				3'b100: legal = 1'b0; // no Zicsr operation uses funct3 100
				default: begin
					csr_op = csrOpType_e'(inst.csr_type.funct3);
					if (!csr_implemented(inst.csr_type.csr)) begin
						legal = 1'b0; // FR-50: absent address
					end else begin
						csr_valid = 1'b1;
						csr_write = ((inst.csr_type.funct3 == 3'b001) ||
						             (inst.csr_type.funct3 == 3'b101))
						            ? 1'b1 : (inst.csr_type.rs1 != '0);
						// FR-50: a write to a read-only address traps.
						if (csr_write && csr_read_only(inst.csr_type.csr)) legal = 1'b0;
					end
				end
			endcase
		end
		default: legal = 1'b0;
		endcase

		if (!legal) begin
			trap_cause_id = TRAP_ILLEGAL_INSTRUCTION;
			csr_valid = 1'b0;
			csr_write = 1'b0;
		end
	end: proc_legality

	/*
	 * Instruction decoder
	 */
	always_comb begin: proc_decode
		uncond_jump = '0;
		cond_jump = '0;
		jalr = '0;
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
			rd0_wr_en_2pipe = '1;
		end
        AUIPC: begin
			//add+4 (funct7 and funct3 is undefined)
			alu_op = ALU_ADD;
			alu_src1 = PC;
			alu_src2 = IMM;
			rd0_wr_en_2pipe = '1;
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
			jalr = '1;
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
			rd0_wr_en_2pipe = '1;
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
			alu_op = ALU_ADD; 
			alu_src1 = RS1;
			alu_src2 = IMM;

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
			rd0_wr_en_2pipe = '1;
		end
        ALU_C: begin
			//funct7[0],funct3 (SUB and SRA uses funct7)
			alu_op = aluOpType_e'({inst.r_type.funct7[5], inst.r_type.funct3});
			alu_src1 = RS1; 
			alu_src2 = RS2; 
			rd0_wr_en_2pipe = '1;
		end
        FENCE: begin
			//TODO:
		end
        ECBK_C: begin
			/* Zicsr (FR-47): the CSR is read and written in EX, so the
			 * destination write enable is the architectural one -- an
			 * instruction with rd = x0 writes nothing (D4). ECALL, EBREAK,
			 * MRET, WFI and the illegal encodings are decided in proc_legality
			 * and never reach this arm with csr_valid set. */
			if (csr_valid) begin
				alu_op = CSR_PASS;
				alu_src1 = RS1;
				alu_src2 = IMM;
				rd0_wr_en_2pipe = (inst.csr_type.rd != '0);
			end
		end
		endcase
	end: proc_decode


        



endmodule: instruction_decode
