/*******************************************************************************
 * Copyright 2019-2020 Nelson Alves Ferreira Neto
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
 * The instruction Fetch module is responsible for update Program Counter PC and 
 * get the next instruction from the program memory. 
 *
 * Maintainer: Nelson Alves <nelsonafn@gmail.com>
 * Revision : $Revision$
 *
 * History:
 * $Log$
 */



import riscv_definitions::*; // import package into $unit space

module instruction_fetch #(
    parameter INST_WIDTH = 32,
    parameter ARCH_WIDTH = 32
    )(
    input logic clk,    // Clock
    input logic clk_en, // Clock Enable
    input logic rst_n,  // Asynchronous reset active low
    // Communication with the instruction memory
    input instruction_u inst_data, // Data from instruction memory
    output logic [ARCH_WIDTH-1:0] inst_addr,// Address of next instruction
    // Communication instruction decoder
    output instruction_u inst_id,// Registered instruction to be decode
    output logic [ARCH_WIDTH-1:0] pc_id,  // PC of current instruction to decode
    // Next PC control
    input logic [ARCH_WIDTH-1:0] jump_address,// Jump address
    input logic [ARCH_WIDTH-1:0] trap_address,// Exception/interruption address
    input nextPCType_e pc_sel
);

    logic [INST_WIDTH-1:0] pc;

    assign inst_addr = pc;

    /* 
     * Register PC (pc_id) and instruction (inst_id) for instruction decode (id)
     * stage.
     */
    always_ff @(posedge clk or negedge rst_n) begin: proc_if_id
        if(~rst_n) begin
            pc_id <= {ARCH_WIDTH{1'b0}};
            inst_id <= {INST_WIDTH{1'b0}};
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
            pc <= {ARCH_WIDTH{1'b0}};
        end else if(clk_en) begin
            case (pc_sel)
                PC_PLUS4: begin
                    pc <= pc + 4;
                end
                JUMP: begin 
                    pc <= jump_address;
                end
                TRAP: begin 
                    pc <= trap_address;
                end
                default: begin 
                    pc <= pc + 4;
                end 
            endcase
        end
    end: proc_pc

endmodule: instruction_fetch