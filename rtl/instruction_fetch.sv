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
 * Module: instruction_fetch
 *
 * The Instruction Fetch module is responsible for update Program Counter PC and 
 * get the next instruction from the program memory. 
 *
 * Maintainer: Nelson Alves <nelsonafn@gmail.com>
 * Revision : $Revision$
 *
 * History:
 * $Log$
 */



import riscv_definitions::*; // import package into $unit space

module instruction_fetch (
    input logic clk,    // Clock
    input logic clk_en, // Clock Enable
    input logic rst_n,  // Asynchronous reset active low
    // Communication with the instruction memory
    input instruction_u inst_data, // Data from instruction memory
    input logic flush, // Insert NOP
    output dataBus_u inst_addr,// Address of next instruction
    // Communication instruction decoder
    output instruction_u inst_id,// Registered instruction to be decode
    output dataBus_u pc_id,  // PC of current instruction to decode
    // Next PC control
    input dataBus_u jump_addr,// Jump address
    input dataBus_u trap_addr,// Exception/interruption address
    input nextPCType_e pc_sel // PC source selector
);

    dataBus_u pc;

    assign inst_addr = pc;

    /* 
     * Register PC (pc_id) and instruction (inst_id) for instruction decode (id)
     * stage.
     */
    always_ff @(posedge clk or negedge rst_n) begin: proc_if_id
        if(~rst_n || flush) begin
            pc_id <= 'b0;
            inst_id <= 'b0;
        end else if(clk_en) begin
            pc_id <= pc;
            inst_id <= inst_data;
        end
    end: proc_if_id


    /* 
     * Selection next PC value based on the pc_sel control.
     * PC (pc) is registered.
     */
    always_ff @(posedge clk or negedge rst_n) begin: proc_pc
        if(~rst_n) begin
            pc <= 'b0;
        end else if(clk_en) begin
            case (pc_sel) inside
                PC_PLUS4: begin
                    pc <= pc + 4;
                end
                JUMP: begin 
                    pc <= jump_addr;
                end
                TRAP: begin 
                    pc <= trap_addr;
                end
                default: begin 
                    pc <= pc + 4;
                end 
            endcase
        end
    end: proc_pc

endmodule: instruction_fetch