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
 * Package: memory_access
 *
 * Description: Memory access is the stage responsible for control the load 
 * extension and the store operation.
 *
 * Maintainer: Nelson Alves <nelsonafn@gmail.com>
 *
 * History:
 * January 17, 2021 at 18:42 - Created by Nelson Alves <nelsonafn@gmail.com>
 */

 
// TODO: rename data to dtm_data and rd0 to rdst_data
module memory_access 
import riscv_definitions_pkg::*;
(
    input clk,    //[in] Clock
    input clk_en, //[in] Clock Enable
    input rst_n,  //[in] Asynchronous reset active low
    input dataBus_u alu_result, //[in] ALU result to from (ex)
    input dataBus_u pc, //[in] PC value from execution (ex)
    input instruction_u inst, //[in] Instruction word from execution (ex)
    input logic valid, //[in] Instruction valid from execution (ex)
    input dataBus_u data, //[in] Data from data_memory
    input dataBus_u split_word, //[in] Loaded word assembled from both beats, aligned (FR-42)
    input logic split_ld_en, //[in] This cycle completes a split load (FR-42)
    input logic rd0_wr_en,//[in] Reg destination (rd) write enable from (ex)
    input logic data_rd_en, //[in] Data memory read enable (wb_mux_sel) to be used with funct3  
    input funct3ITypeLOAD_e rd_wr_ctrl, //[in] funct3 LOAD from execution (ex)
	input regAddr_t rd0_addr,  //[in] Reg destination (rd) addr from execution (ex)
    output dataBus_u alu_wb, //[out] ALU result to write back (wb)
    output dataBus_u pc_wb, //[out] PC value to write back (wb)
    output instruction_u inst_wb, //[out] Instruction word to write back (wb)
    output logic valid_wb, //[out] Instruction valid in write back (wb)
	output logic rd0_wr_en_wb,//[out] Reg destination (rd) write enable to pipeline to write back
    output logic wb_mux_sel_wb, //[out] Data memory read enable (wb_mux_sel) 
    output dataBus_u ld_data_wb, //[out] Data from load_extension
	output regAddr_t rd0_addr_wb  //[out] Reg destination (rd) addr to memory access (ma)
);

    //dataBus_u ld_data;
    funct3ITypeLOAD_e rd_wr_ctrl_wb;

    /* Split load (FR-42/G-22): the MA/WB registers below mark the load whose
     * beats were assembled by misaligned_split, and carry its aligned word. */
    logic split_wb;
    dataBus_u split_word_wb;

    /* Byte lane of the word the data memory returned for this load.
     * alu_wb is the effective address registered in the same cycle as
     * rd_wr_ctrl_wb, so it stays aligned with `data` while the load is in WB.
     * dataBus_u declares its byte array as [0:3] (index 0 = bits [31:24]), so
     * the lane is taken from an indexed part-select of u_data instead of a
     * byte-array index: offset 0 is bits [7:0], offset 3 is bits [31:24].
     * A split load presents an ALIGNED word in ld_word (the merge of both
     * beats puts the accessed bytes at bit 0), so its lane is 0. */
    logic [1:0] ld_lane;
    assign ld_lane = split_wb ? 2'd0 : alu_wb.u_data[1:0];

    /* Byte lane of a HALFWORD load. A halfword is byte-granular, so its lane is
     * the address lane: offset 1 reads bytes 1-2 of the same word. Offset 3
     * would span bytes 3-4, i.e. it crosses the word, and `8 * lane +: 16`
     * would then select bits [39:24], of which [39:32] do not exist. That
     * access is the misaligned split (FR-42/G-22, WP-13 P6), so until the split
     * issues the second beat the lane is clamped to 2: offset 3 reads the upper
     * halfword, which is defined (and is the value the pre-fix
     * halfword-granular lane produced there) instead of an out-of-range
     * part-select. */
    logic [1:0] ld_lane_half;
    assign ld_lane_half = (ld_lane == 2'd3) ? 2'd2 : ld_lane;

    /* Word the load extension reads: the memory's answer, or the aligned word
     * the two split beats assembled. It is registered through MA/WB in the same
     * edge as rd_wr_ctrl_wb/alu_wb, so it stays aligned with them. */
    dataBus_u ld_word;

    always_comb begin: proc_ld_word
        ld_word = data;
        if (split_wb) ld_word.u_data = split_word_wb.u_data;
    end: proc_ld_word

    always_ff @(posedge clk or negedge rst_n) begin: proc_ma_wb
        if (!rst_n) begin: proc_ma_wb_rst
            //ld_data_wb <= '0;
            rd0_addr_wb <= '0;
            wb_mux_sel_wb <= '0;
            rd0_wr_en_wb <= '0;
            alu_wb <= '0;
            pc_wb <= '0;
            inst_wb <= '0;
            valid_wb <= '0;
            split_wb <= '0;
            split_word_wb <= '0;
        end: proc_ma_wb_rst
        else if (clk_en) begin
            //ld_data_wb <= ld_data;
            rd_wr_ctrl_wb <= rd_wr_ctrl;
            rd0_addr_wb <= rd0_addr;
            wb_mux_sel_wb <= data_rd_en;
            rd0_wr_en_wb <= rd0_wr_en;
            alu_wb <= alu_result;
            pc_wb <= pc;
            inst_wb <= inst;
            valid_wb <= valid;
            split_wb <= split_ld_en;
            split_word_wb <= split_word;
        end        
    end: proc_ma_wb
    
    always_comb begin: load_extension
        case (rd_wr_ctrl_wb)
            LB: begin
                ld_data_wb.s_data = $signed(ld_word.u_data[8 * ld_lane +: 8]);
            end
            LH: begin
                ld_data_wb.s_data = $signed(ld_word.u_data[8 * ld_lane_half +: 16]);
            end
            LW: begin
                ld_data_wb.s_data = ld_word.s_data;
            end
            LBU: begin
                ld_data_wb.u_data = ld_word.u_data[8 * ld_lane +: 8];
            end
            LHU: begin
                ld_data_wb.u_data = ld_word.u_data[8 * ld_lane_half +: 16];
            end
            default: begin
                ld_data_wb.s_data = ld_word.s_data;
            end
        endcase
        
    end: load_extension
    
endmodule: memory_access