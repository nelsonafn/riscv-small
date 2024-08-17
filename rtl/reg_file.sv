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
 * Package: reg_file
 *
 * Description: This module is responsible for control the read and write of 
 * register for risc-v.
 *
 * Maintainer: Nelson Alves <nelsonafn@gmail.com>
 *
 * History:
 * January 03, 2021 at 20:53 - Created by Nelson Alves <nelsonafn@gmail.com>
 */

 import riscv_definitions::*; // import package into $unit space
    
module reg_file (
    input clk,    //[in] Clock
    input clk_en, //[in] Clock Enable
    input rst_n,  //[in] Asynchronous reset active low
    input regAddr_t rs1_addr, //[in] Reg source one address
    input regAddr_t rs2_addr, //[in] Reg source two address
    input regAddr_t rd0_addr,  //[in] Reg destination address
    input logic rd0_wr_en, //[in] Reg destination write enable
    input dataBus_u rd0_data, //[in] Reg destination data
    output dataBus_u rs1, //[out] Reg source one data 
    output dataBus_u rs2  //[out] Reg source two data 
);

    /*
     * Register bank. 
     * Register x0 is always 32'b0.
     */
    dataBus_u regs [1:31];

    /*
     * Combinational read of source registers (rs1 and rs2). 
     * x0 is always 32'b0.
     */
    always_comb begin: comb_rs_read

        //R0 is always zeros, it should not be forward
        if (rs1_addr == '0) begin
            rs1 = '0;
        end
        // Forward rd0 to rs1 if same address being write and read
        else if (rd0_addr == rs1_addr) begin
            rs1 = rd0_data;
        end 
        else begin
            rs1 = regs[rs1_addr];
        end

        //R0 is always zeros, it should not be forward
        if (rs2_addr == '0) begin
            rs2 = '0;
        end
        // Forward rd0 to rs2 if same address being write and read
        else if (rd0_addr == rs2_addr) begin
            rs2 = rd0_data;
        end 
        else begin
            rs2 = regs[rs2_addr];
        end
    end: comb_rs_read

    /*
     * Synchronized write of destination (rd)
     */
    always_ff @(posedge clk or negedge rst_n) begin: rd0_write
        if (!rst_n) begin: rd0_write_rst
            // TODO: Remove X from reset after tests
            regs <= '{default:'X};
        end: rd0_write_rst
        else if (clk_en) begin
            if (rd0_wr_en) begin
                regs[rd0_addr] <= rd0_data;
            end
        end        
    end: rd0_write
    
endmodule: reg_file
