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

 import riscv_definitions::*; // import package into $unit space
 
// TODO: rename data to dtm_data and rd0 to rdst_data
module memory_access (
    input clk,    //[in] Clock
    input clk_en, //[in] Clock Enable
    input rst_n,  //[in] Asynchronous reset active low
    input dataBus_u alu_result, //[in] ALU result to from (ex)
    input dataBus_u data, //[in] Data from data_memory
    input logic rd0_wr_en,//[in] Reg destination (rd) write enable from (ex)
    input logic data_rd_en, //[in] Data memory read enable (wb_mux_sel) to be used with funct3  
    input funct3ITypeLOAD_e rd_wr_ctrl, //[in] funct3 LOAD from execution (ex)
	input regAddr_t rd0_addr,  //[in] Reg destination (rd) addr from execution (ex)
    output dataBus_u alu_wb, //[out] ALU result to write back (wb)
	output logic rd0_wr_en_wb,//[out] Reg destination (rd) write enable to pipeline to write back
    output logic wb_mux_sel_wb, //[out] Data memory read enable (wb_mux_sel) 
    output dataBus_u ld_data_wb, //[out] Data from load_extension
	output regAddr_t rd0_addr_wb  //[out] Reg destination (rd) addr to memory access (ma)
);

    dataBus_u ld_data;

    always_ff @(posedge clk or negedge rst_n) begin: proc_ma_wb
        if (!rst_n) begin: proc_ma_wb_rst
            ld_data_wb <= '0;
            rd0_addr_wb <= '0;
            wb_mux_sel_wb <= '0;
            rd0_wr_en_wb <= '0;
            alu_wb <= '0;
        end: proc_ma_wb_rst
        else if (clk_en) begin
            ld_data_wb <= ld_data;
            rd0_addr_wb <= rd0_addr;
            wb_mux_sel_wb <= data_rd_en;
            rd0_wr_en_wb <= rd0_wr_en;
            alu_wb <= alu_result;
        end        
    end: proc_ma_wb
    
    always_comb begin: load_extension
        case (rd_wr_ctrl)
            LB: begin
                ld_data.s_data = data.s_bytes[0];
            end
            LH: begin
                ld_data.s_data = data.s_half[0];
            end
            LW: begin
                ld_data.s_data = data.s_data;
            end
            LBU: begin
                ld_data.u_data = data.u_bytes[0];
            end
            LHU: begin
                ld_data.u_data = data.u_half[0];
            end
            default: begin
                ld_data.s_data = data.s_data;
            end
        endcase
        
    end: load_extension
    
endmodule: memory_access