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

import riscv_definitions::*; // import package into $unit space
 
module execution (
    input clk,    //[in] Clock
    input clk_en, //[in] Clock Enable
    input rst_n,  //[in] Asynchronous reset active low
    input aluOpType_e alu_op, //[in] Opcode for alu operation ( composed by funct3ITypeALU_e)
    input ctrlAluSrc1_e alu_src1, //[in] ALU mux1 sel (PC/RS1/RD MA forward [alu_ma]/ RD WB rd0_data)
	input ctrlAluSrc2_e alu_src2, //[in] ALU mux2 sel (RS2/IMM/RD MA forward [alu_ma]/ RD WB rd0_data)
    input ctrlAluSrc2_e storage_src,//[in] rs2 mux2 sel (RS2/RD MA forward [alu_ma]/ RD WB rd0_data)
    input dataBus_u pc, //[in] PC value to EX	
	input dataBus_u rs1, //[in] Reg source one (rs1) data
	input dataBus_u rs2, //[in] Reg source two (rs2) data
	input dataBus_u imm, //[in] Immediate value
    input dataBus_u rd0_data, //[in] Reg destination (rd) data from write back (wb) forward
    input logic rd0_wr_en,//[out] Reg destination (rd) write enable to pipeline from (id)
    input logic data_rd_en, //[out] Data memory read enable (wb_mux_sel) to be used with funct3 
	input logic data_wr_en, //[out] Data memory write enable to be used together with funct3
    input funct3ITypeLOAD_e funct3, //[out] funct3 LOAD from instruction decode (id)
	input regAddr_t rd0_addr,  //[out] Reg destination (rd) addr from instruction decode (id)
    input logic flush, // Insert NOP
    output dataBus_u alu_ma, //[out] ALU result to memory access (ma)
    output dataBus_u rs2_ma, //[out] Reg source two (rs2) data
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
     * Register signals to be used in memory access (ma) stage. 
     */
    always_ff @(posedge clk or negedge rst_n) begin: proc_ex_ma
        if (!rst_n || flush) begin: proc_ex_ma_rst
            alu_ma <= '0;
            rd0_wr_en_ma <= '0;
            data_rd_en_ma <= '0;
            data_wr_en_ma <= '0;
            funct3_ma <= LB;
            rd0_addr_ma <= '0;
            rs2_ma <= '0;
        end: proc_ex_ma_rst
        else if (clk_en) begin
            alu_ma <= alu_result;
            rd0_wr_en_ma <= rd0_wr_en;
            data_rd_en_ma <= data_rd_en;
            data_wr_en_ma <= data_wr_en;
            funct3_ma <= funct3;
            rd0_addr_ma <= rd0_addr;
            rs2_ma <= rs2_pipeline;
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
        case (alu_src2)
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
     * ALU calculation
     */
    alu u_alu (
        .alu_op        (alu_op), //[in] Opcode for alu operation ( composed by funct3ITypeALU_e)
        .alu_data1     (alu_data1), //[in] Reg destination (rd) data
        .alu_data2     (alu_data2), //[in] Registered alu result to memory access (ma) 
        .alu_result    (alu_result)  //[out] ALU result to pipeline 
    );
    
endmodule: execution