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
 * Package: data_memory
 *
 * Description: .
 *
 * Maintainer: Nelson Alves <nelsonafn@gmail.com>
 *
 * History:
 * January 19, 2021 at 22:35 - Created by Nelson Alves <nelsonafn@gmail.com>
 */
 
module data_memory (
    input clk,    //[in] Clock
    input clk_en, //[in] Clock Enable
    input rst_n,  //[in] Asynchronous reset active low
    input dataBus_u data_in,
    input dataBus_u data_out,
    input logic data_rd_en,
    input logic data_wr_en,
    input dataBus_u addr,// Address of next instruction
    output data_ready
);
    
        /*
     * Register bank. 
     * Register x0 is always 32'b0.
     */
    dataBus_u mem [0:1023];

    /*
     * Combinational read of source registers (rs1 and rs2). 
     * x0 is always 32'b0.
     */
    always_comb begin: proc_comb_read
        instruction = mem[addr];
    end: comb_rs_read

    /*
     * Synchronized write 
     */
    always_ff @(posedge clk or negedge rst_n) begin: rd0_write
        if (!rst_n) begin: rd0_write_rst
            mem <= '{default:0};
        end: rd0_write_rst
        else if (clk_en) begin
            if (rd0_wr_en) begin
                mem[rd0_addr] <= rd0_data;
            end
        end        
    end: rd0_write
    
endmodule: data_memory