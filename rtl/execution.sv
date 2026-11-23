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
 * Package: execution
 *
 * Description: This is the module that encompasses the execution stage.
 *
 * Maintainer: Nelson Alves <nelsonafn@gmail.com>
 *
 * History:
 * January 12, 2021 at 21:34 - Created by Nelson Alves <nelsonafn@gmail.com>
 */

 
module execution 
import riscv_definitions_pkg::*;
(
    input clk,    //[in] Clock
    input clk_en, //[in] Clock Enable
    input rst_n,  //[in] Asynchronous reset active low
    input aluOpType_e alu_op, //[in] Opcode for alu operation ( composed by funct3ITypeALU_e)
    input ctrlAluSrc1_e alu_src1, //[in] ALU mux1 sel (PC/RS1/RD MA forward [alu_ma]/ RD WB rd0_data)
	input ctrlAluSrc2_e alu_src2, //[in] ALU mux2 sel (RS2/IMM/RD MA forward [alu_ma]/ RD WB rd0_data)
    input ctrlAluSrc2_e storage_src,//[in] rs2 mux2 sel (RS2/RD MA forward [alu_ma]/ RD WB rd0_data) TODO:TBR
    input dataBus_u pc, //[in] PC value to EX	
    input instruction_u inst, //[in] Instruction word from decode (id)
    input logic valid, //[in] Instruction valid from decode (id)
	input dataBus_u rs1, //[in] Reg source one (rs1) data
	input dataBus_u rs2, //[in] Reg source two (rs2) data
	input dataBus_u imm, //[in] Immediate value
    input dataBus_u rd0_data, //[in] Reg destination (rd) data from write back (wb) forward
    input dataBus_u csr_rdata, //[in] Value read from the CSR addressed in EX (FR-47)
    input logic rd0_wr_en,//[out] Reg destination (rd) write enable to pipeline from (id)
    input logic data_rd_en, //[out] Data memory read enable (wb_mux_sel) to be used with funct3 
	input logic data_wr_en, //[out] Data memory write enable to be used together with funct3
    input funct3ITypeLOAD_e funct3, //[out] funct3 LOAD from instruction decode (id)
	input regAddr_t rd0_addr,  //[out] Reg destination (rd) addr from instruction decode (id)
    input logic flush, // Insert NOP
    //TODO: Check critical path of forward from not registered ALU (alu_ex)
    output dataBus_u alu_ex, //[out] ALU result from execution not registered to jump forward (ex)
    output dataBus_u alu_ma, //[out] ALU result to memory access (ma)
    output dataBus_u csr_wdata, //[out] Zicsr source operand, forwarded (FR-47)
    output dataBus_u pc_ma, //[out] PC value to memory access (ma)
    output instruction_u inst_ma, //[out] Instruction word to memory access (ma)
    output logic valid_ma, //[out] Instruction valid to memory access (ma)
    output dataBus_u rs2_ma, //[out] Reg source two (rs2) data
    output dataBus_u rs2_raw_ma, //[out] Reg source two (rs2) data before the store lane (ma)
    output logic [3:0] data_wr_strb_ma, //[out] Byte write strobe to memory access (ma)
	output logic rd0_wr_en_ma,//[out] Reg destination (rd) write enable to pipeline to memory access
    output logic data_rd_en_ma, //[out] Data memory read enable (wb_mux_sel) to be used with funct3 
	output logic data_wr_en_ma, //[out] Data memory write enable to be used together with funct3
    output funct3ITypeLOAD_e funct3_ma, //[out] funct3 LOAD to memory access (ma)
	output regAddr_t rd0_addr_ma  //[out] Reg destination (rd) addr to memory access (ma)
);

    /* 
     * ALU result to pipeline 
     */
    dataBus_u alu_result;

    /* 
     * ALU source data from mux to ALU
     */
    dataBus_u alu_data1;
    dataBus_u alu_data2;

    /* 
     * rs2 to pipeline 
     */
    dataBus_u rs2_pipeline;

    /* 
     * Store data placed in the addressed lane and its byte write strobe. 
     */
    dataBus_u rs2_lane;
    logic [3:0] data_wr_strb_ex;

    /* 
     * Register signals to be used in memory access (ma) stage. 
     */
    always_ff @(posedge clk or negedge rst_n) begin: proc_ex_ma
        if (!rst_n || flush) begin: proc_ex_ma_rst
            alu_ma <= '0;
            pc_ma <= '0;
            inst_ma <= '0;
            valid_ma <= '0;
            rd0_wr_en_ma <= '0;
            data_rd_en_ma <= '0;
            data_wr_en_ma <= '0;
            funct3_ma <= LB;
            rd0_addr_ma <= '0;
            rs2_ma <= '0;
            rs2_raw_ma <= '0;
            data_wr_strb_ma <= 4'b0000;
        end: proc_ex_ma_rst
        else if (clk_en) begin
            alu_ma <= alu_result;
            pc_ma <= pc;
            inst_ma <= inst;
            valid_ma <= valid;
            rd0_wr_en_ma <= rd0_wr_en;
            data_rd_en_ma <= data_rd_en;
            data_wr_en_ma <= data_wr_en;
            funct3_ma <= funct3;
            rd0_addr_ma <= rd0_addr;
            rs2_ma <= rs2_lane;
            rs2_raw_ma <= rs2_pipeline;
            data_wr_strb_ma <= data_wr_strb_ex;
        end        
    end: proc_ex_ma

    /* 
     * ALU mux 1
     */
    always_comb begin: proc_alu_mux1
        case (alu_src1)
            PC_S1: begin
                alu_data1 = pc;
            end 
            RS1_S1: begin
                alu_data1 = rs1;
            end
            //Red destination (rd) from Memory Access (MA) to rs1 forward
            RD_MA_S1: begin
               alu_data1 = alu_ma;     
            end 
            //Red destination (rd) from Write Back (WB) to rs1 forward
            RD_WB_S1: begin
               alu_data1 = rd0_data;     
            end  
        endcase
    end: proc_alu_mux1

    /* 
     * ALU mux 2
     */
    always_comb begin: proc_alu_mux2
        case (alu_src2)
            RS2_S2: begin
                alu_data2 = rs2;
            end 
            IMM_S2: begin
                alu_data2 = imm;
            end
            //Red destination (rd) from Memory Access (MA) to rs2 forward
            RD_MA_S2: begin
                alu_data2 = alu_ma;     
            end 
            //Red destination (rd) from Write Back (WB) to rs2 forward
            RD_WB_S2: begin
                alu_data2 = rd0_data;     
            end  
        endcase
    end: proc_alu_mux2

    /* 
     * rs2 mux
     */
    always_comb begin: proc_rs2_mux
        case (storage_src)
            RS2_S2: begin
                rs2_pipeline = rs2;
            end 
            //Red destination (rd) from Memory Access (MA) to rs2 forward
            RD_MA_S2: begin
                rs2_pipeline = alu_ma;     
            end 
            //Red destination (rd) from Write Back (WB) to rs2 forward
            RD_WB_S2: begin
                rs2_pipeline = rd0_data;     
            end  
            default: begin
                rs2_pipeline = rs2;
            end
        endcase
    end: proc_rs2_mux

    /* 
     * Store lane and byte write strobe.
     * The EX address (alu_result) selects the lane; the width comes from the
     * single package decode (access_size), the same function that drives
     * data_rd_wr_ctrl in the top level. With no write the strobe is zero.
     */
    always_comb begin: proc_store_lane
        rs2_lane = rs2_pipeline;
        data_wr_strb_ex = 4'b0000;
        if (data_wr_en) begin
            case (access_size(funct3))
                ACCESS_BYTE: begin
                    rs2_lane.u_data = rs2_pipeline.u_data << {alu_result.u_data[1:0], 3'b000};
                    data_wr_strb_ex = 4'b0001 << alu_result.u_data[1:0];
                end
                ACCESS_HALF: begin
                    /* A halfword is byte-granular: offset 1 occupies bytes 1-2
                     * of the same word, so both the rotation and the strobe use
                     * 8 * addr[1:0], not 16 * addr[1]. Offset 3 spans bytes 3-4
                     * and crosses the word -- that is the misaligned split
                     * (FR-42/G-22, WP-13 P6), not a lane. The shift and the
                     * 4-bit strobe stay defined there: byte 3 is written
                     * (4'b1000) with the low byte at lane 3, and the byte at
                     * offset 4 is not written until P6 issues the second beat. */
                    rs2_lane.u_data = rs2_pipeline.u_data << {alu_result.u_data[1:0], 3'b000};
                    data_wr_strb_ex = 4'b0011 << alu_result.u_data[1:0];
                end
                ACCESS_WORD: begin
                    /* A word is byte-granular as well: at offset 1 it occupies
                     * bytes 1-3 of the addressed word and crosses it, so the
                     * beat carries the operand rotated into those lanes and
                     * the byte at offset 4 is left for the second beat
                     * (FR-42/G-22, WP-13 P6). At offset 0 the rotation and the
                     * strobe are the identity, which is the unaligned-in-word
                     * word store every test before this WP performs. */
                    rs2_lane.u_data = rs2_pipeline.u_data << {alu_result.u_data[1:0], 3'b000};
                    data_wr_strb_ex = 4'b1111 << alu_result.u_data[1:0];
                end
                default: begin
                    rs2_lane = rs2_pipeline;
                    data_wr_strb_ex = 4'b0000;
                end
            endcase
        end
    end: proc_store_lane

    /*
     * Zicsr source operand (FR-47). The register forms take the forwarded rs1
     * that the ALU source mux already produced (control forwards MA/WB), and
     * the immediate forms zero-extend their 5-bit zimm. The CSR file applies
     * the read-modify-write operation, so this is the raw source.
     */
    always_comb begin: proc_csr_wdata
        if (inst.csr_type.funct3[2]) begin
            csr_wdata.u_data = {27'b0, inst.csr_type.rs1};
        end else begin
            csr_wdata = alu_data1;
        end
    end: proc_csr_wdata

    /* 
     * ALU calculation
     */
    alu u_alu (
        .alu_op        (alu_op), //[in] Opcode for alu operation ( composed by funct3ITypeALU_e)
        .alu_data1     (alu_data1), //[in] Reg destination (rd) data
        .alu_data2     (alu_data2), //[in] Registered alu result to memory access (ma) 
        .csr_data      (csr_rdata), //[in] CSR read value, the Zicsr result
        .alu_result    (alu_result)  //[out] ALU result to pipeline 
    );

    /*
     * ALU result before the EX/MA register, used by the jump comparison in ID
     * to forward the value produced by the instruction currently in EX.
     */
    assign alu_ex = alu_result;

endmodule: execution