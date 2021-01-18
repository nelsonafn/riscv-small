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
 * Package: alu
 *
 * Description: This module is responsible for performing integer ans logic 
 * operations.
 *
 * Maintainer: Nelson Alves <nelsonafn@gmail.com>
 *
 * History:
 * January 10, 2021 at 22:13 - Created by Nelson Alves <nelsonafn@gmail.com>
 */

import riscv_definitions::*; // import package into $unit space

 
module alu (
    input aluOpType_e alu_op, //[in] Opcode for alu operation ( composed by funct3ITypeALU_e)
    input dataBus_u alu_data1, //[in] Reg destination (rd) data
    input dataBus_u alu_data2, //[in] Registered alu result to memory access (ma) 
    output dataBus_u alu_result //[out] ALU result to pipeline 
);

    /* 
     * ALU calculation
     */
    always_comb begin: proc_alu
        case (alu_op)
            ALU_ADD : begin
                alu_result = alu_data1.s_data + alu_data2.s_data;
            end
            ALU_SLL : begin // Logical Left Shift (zero in lower bits, only lower 5 bits of data2)
                alu_result = alu_data1 << alu_data2[4:0];
            end
            ALU_SLT : begin // Signed data1 les then signed data2
                alu_result = alu_data1.s_data < alu_data2.s_data;
            end
            ALU_SLTU : begin // Unsigned data1 les then unsigned data2
                alu_result = alu_data1.u_data < alu_data2.u_data;
            end
            ALU_XOR : begin
                alu_result = alu_data1 ^ alu_data2;
            end
            ALU_SRL : begin // Logical Right Shift (zero in upper bits, only lower 5 bits of data2)
                alu_result = alu_data1 >> alu_data2[4:0];
            end
            ALU_OR : begin
                alu_result = alu_data1 | alu_data2;
            end
            ALU_AND : begin
                alu_result = alu_data1 & alu_data2;
            end
            ALU_SUB : begin
                alu_result = alu_data1 - alu_data2;
            end
            ALU_SRA : begin // Arithmetical Right Shift (signal in upper bits, only lower 5 bits of data2)
                alu_result = alu_data1.s_data >>> alu_data2[4:0];
            end
            ALU_ADD4 : begin
                alu_result = alu_data1 + 4;
            end
            ALU_BPS2 : begin
                alu_result = alu_data2;
            end
            default: begin
                alu_result = alu_data2;
            end
        endcase
    end: proc_alu
    
endmodule: alu