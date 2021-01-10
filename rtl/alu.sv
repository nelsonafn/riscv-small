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
 
module alu (
    input clk,    //[in] Clock
    input clk_en, //[in] Clock Enable
    input rst_n,  //[in] Asynchronous reset active low
    input aluOpType_e alu_op, //[in] Opcode for alu operation ( composed by funct3ITypeALU_e)
    input ctrlAluSrc1_e alu_src1, //[in] ALU mux1 sel (PC/RS1/RD MA forward [alu_ma]/ RD WB rd_data)
	input ctrlAluSrc2_e alu_src2, //[in] ALU mux2 sel (RS2/IMM/RD MA forward [alu_ma]/ RD WB rd_data)
    input dataBus_u pc, //[in] PC value to EX	
	input dataBus_u rs1, //[in] Reg source one (rs1) data
	input dataBus_u rs2, //[in] Reg source two (rs2) data
	input dataBus_u imm, //[in] Immediate value
    input dataBus_u rd_data, //[in] Reg destination (rd) data
    input dataBus_u alu_ma, //[in] Registered alu result to memory access (ma) 
    output dataBus_u alu_result //[out] ALU result to pipeline 
);

    dataBus_u alu_data1, alu_data2;

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
               alu_data1 = rd_data;     
            end  
        endcase
    end: proc_alu_mux1

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
               alu_data2 = rd_data;     
            end  
        endcase
    end: proc_alu_mux2

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
        endcase: proc_alu
    end
    
endmodule: alu