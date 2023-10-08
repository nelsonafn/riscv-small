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
 * Package: control
 *
 * Description: This module is responsible for control data forwarding, 
 * exception and interruption.
 *
 * Maintainer: Nelson Alves <nelsonafn@gmail.com>
 *
 * History:
 * January 17, 2021 at 21:01 - Created by Nelson Alves <nelsonafn@gmail.com>
 */
 
module control (
    input clk,    //[in] Clock
    input clk_en, //[in] Clock Enable
    input rst_n,  //[in] Asynchronous reset active low
    input regAddr_t rs1_addr_id, //[in] Reg source one (rs1) addr
	input regAddr_t rs2_addr_id, //[in] Reg source two (rs2) addr
	input regAddr_t rs1_addr_ex, //[in] Reg source one (rs1) addr
	input regAddr_t rs2_addr_ex,  //[in] Reg source two (rs2) addr
    input regAddr_t rd0_addr_ex,  //[in] Reg destination (rd) addr
    input regAddr_t rd0_addr_ma,  //[in] Reg destination (rd) addr
    input regAddr_t rd0_addr_wb,  //[in] Reg destination (rd) addr
    input logic rd0_wr_en_ex,//[in] Reg destination (rd) write enable to pipeline
    input logic rd0_wr_en_ma,//[in] Reg destination (rd) write enable to pipeline
    input logic rd0_wr_en_wb,//[in] Reg destination (rd) write enable to pipeline
    input logic data_rd_en_ex, //[in] Data memory read enable (wb_mux_sel) to be used with funct3
	input logic data_rd_en_ma, //[in] Data memory read enable (wb_mux_sel) to be used with funct3
    input logic data_wr_en_ex,  //[in] Data memory write enable to be used with funct3
    input logic cond_jump, // Used to indicate a conditional branch have been decoded
    input logic branch_taken,  //[in] Indicates that a branch should be taken to the control  
    input exception, //[in] Exception trigger
    input dataBus_u pc_ex, //[in] PC value to EX
    input logic inst_ready, //[in] Indicates that instruction from memory is available
    input logic data_ready, //[in] Indicates that data from memory is available
    input aluSrc1_e alu_src1_ex, //[in] ALU source one mux selection (possible values PC/RS1) (id)
	input aluSrc2_e alu_src2_ex, //[in] ALU source two mux selection (possible values RS2/IMM) (id)
    output ctrlAluSrc1_e alu_src1,//[out] ALU mux1 sel (PC/RS1/RD MA forward [alu_ma]/ RD WB rd0_data)
	output ctrlAluSrc2_e alu_src2,//[out] ALU mux2 sel (RS2/IMM/RD MA forward [alu_ma]/ RD WB rd0_data)
    output ctrlAluSrc2_e storage_src,//[out] rs2 mux2 sel (RS2/RD MA forward [alu_ma]/ RD WB rd0_data) //TODO:TBR
    output ctrlCJmpSrc_e jmp_src1,//[out] JUMP mux1 sel (from RD_: EX alu_ex, MA alu_ma, WB rd0_data)
    output ctrlCJmpSrc_e jmp_src2,//[out] JUMP mux2 sel (from RD_: EX alu_ex, MA alu_ma, WB rd0_data)
	output nextPCType_e pc_sel, //[out] PC source selector
    output dataBus_u trap_addr,  //[out] Trap Addr
    output logic inst_rd_en,    //[out] Instruction memory read enable
    output logic if_id_clk_en, // Run/Pause IF_ID
    output logic id_ex_clk_en, // Run/Pause ID_EX
    output logic ex_ma_clk_en, // Run/Pause EX_MA
    output logic ma_wb_clk_en, // Run/Pause MA_WB
    output logic if_id_flush, // Insert NOP in IF_ID
    output logic id_ex_flush, // Insert NOP in ID_EX
    output logic ex_ma_flush // Insert NOP in EX_MA
); 


    dataBus_u sepc;
    dataBus_u scause;

    always_comb begin: proc_forward_ctrl
        jmp_src1 = RD_ID;
        jmp_src2 = RD_ID;
        alu_src1 = ctrlAluSrc1_e'({1'b0, alu_src1_ex});
        alu_src2 = ctrlAluSrc2_e'({1'b0, alu_src2_ex});
        if_id_clk_en = '1;// Run IF_ID
        id_ex_clk_en = '1;// Run ID_EX
        ex_ma_clk_en = '1;// Run EX_MA
        ma_wb_clk_en = '1;// Run MA_WB
        if_id_flush =  '0;// Don't insert NOP in IF_ID
        id_ex_flush =  '0;// Don't insert NOP in ID_EX
        ex_ma_flush =  '0;// Don't insert NOP in EX_MA
        pc_sel = PC_PLUS4; 
        inst_rd_en = 1;
        
        //TODO: Duplicated code. Move to function
        /*
         * Forward for JUMP Compare
         */
        //R0 is always zeros, it should not be forward
        if (rs1_addr_id != '0 && cond_jump) begin
            // TODO: Maybe it doesn't need jump forward from wb because it is already 
            //       bypassed inside register file bank. We should try remove this after
            //       verification be stable and check logic and paths length
            // Forward write back
            if (rs1_addr_id == rd0_addr_wb && rd0_wr_en_wb) begin
                jmp_src1 = RD_WB; //Do forward from write back
            end
            // Forward from memory access
            if (rs1_addr_id == rd0_addr_ma && rd0_wr_en_ma) begin
                // If the data is being read from memory
                if (data_rd_en_ma) begin
                    ex_ma_flush =  '1;// Insert NOP in EX_MA
                    if_id_clk_en = '0;// Pause IF_ID
                    id_ex_clk_en = '0;// Pause ID_EX
                end
                // If rd0 data is not from memory
                else begin
                    jmp_src1 = RD_MA; //Do forward from memory access
                end
            end
            // Forward execution
            if (rs1_addr_id == rd0_addr_ex && rd0_wr_en_ex) begin
                // If the data is being read from memory
                if (data_rd_en_ex) begin
                    id_ex_flush =  '1;// Insert NOP in ID_EX
                    if_id_clk_en = '0;// Pause IF_ID
                end
                // If rd0 data is not from memory
                else begin
                    jmp_src1 = RD_EX; //Do forward from write back
                end
            end
        end

        //R0 is always zeros, it should not be forward
        if (rs2_addr_id != '0 && cond_jump) begin
            // TODO: Maybe it doesn't need jump forward from wb because it is already 
            //       bypassed inside register file bank. We should try remove this after
            //       verification be stable and check logic and paths length
            // Forward write back to ID
            if (rs2_addr_id == rd0_addr_wb && rd0_wr_en_wb) begin
                jmp_src2 = RD_WB; //Do forward from write back
            end
            // Forward from memory access
            if (rs2_addr_id == rd0_addr_ma && rd0_wr_en_ma) begin
                // If the data is being read from memory
                if (data_rd_en_ma) begin
                    ex_ma_flush =  '1;// Insert NOP in EX_MA
                    if_id_clk_en = '0;// Pause IF_ID
                    id_ex_clk_en = '0;// Pause ID_EX
                end
                // If rd0 data is not from memory
                else begin
                    jmp_src2 = RD_MA; //Do forward from memory access
                end
            end
            // Forward execution
            if (rs2_addr_id == rd0_addr_ex && rd0_wr_en_ex) begin
                // If the data is being read from memory
                if (data_rd_en_ex) begin
                    id_ex_flush =  '1;// Insert NOP in ID_EX
                    if_id_clk_en = '0;// Pause IF_ID
                end
                // If rd0 data is not from memory
                else begin
                    jmp_src2 = RD_EX; //Do forward from execution
                end
            end
        end

        /*
         * Forward for ALU
         */
        //TODO: Duplicated code. Move to function
        //R0 is always zeros, it should not be forward
        if (rs1_addr_ex != '0) begin
            // Forward write back
            if (rs1_addr_ex == rd0_addr_wb && rd0_wr_en_wb && alu_src1_ex == RS1) begin
                alu_src1 = RD_WB_S1;
            end
            // Forward from memory access
            if (rs1_addr_ex == rd0_addr_ma && rd0_wr_en_ma && alu_src1_ex == RS1) begin
                // If the data is being read from memory
                if (data_rd_en_ma) begin
                    ex_ma_flush =  '1;// Insert NOP in EX_MA
                    if_id_clk_en = '0;// Pause IF_ID
                    id_ex_clk_en = '0;// Pause ID_EX
                end
                // If rd0 data is not from memory
                else begin
                    alu_src1 = RD_MA_S1; //Do forward from memory access
                end
            end
        end

        //R0 is always zeros, it should not be forward
        if (rs2_addr_ex != '0) begin
            // Forward write back
            if (rs2_addr_ex == rd0_addr_wb && rd0_wr_en_wb) begin
                if (alu_src2_ex == RS2) begin
                    alu_src2 = RD_WB_S2;
                end
                storage_src = RD_WB_S2; //TODO:TBR
            end
            // If rs2 is coming from Memory Access, and ALU need rs2 or Storage will need it on next stage
            if (rs2_addr_ex == rd0_addr_ma && rd0_wr_en_ma && (alu_src2_ex == RS2 || data_wr_en_ex)) begin
                // If the data is being read from memory
                if (data_rd_en_ma) begin
                    ex_ma_flush =  '1;// Insert NOP in EX_MA
                    if_id_clk_en = '0;// Pause IF_ID
                    id_ex_clk_en = '0;// Pause ID_EX
                end
                // If rd0 data is not from memory
                else begin
                    alu_src2 = RD_MA_S2; //Do forward from memory access
                    storage_src = RD_MA_S2; //TODO:TBR
                end
            end
        end

        if (branch_taken) begin
            if_id_flush =  '1;
            pc_sel = JUMP;
        end

        if (exception) begin
            if_id_flush = '1;
            id_ex_flush = '1;
            pc_sel = TRAP;
        end

        //Insert NOP if there is no instruction available
        if (!inst_ready) begin
            if_id_flush =  '1;
        end

        //Pause pipeline id there is not data available
        if (!data_ready) begin
            if_id_clk_en = '0;// Run IF_ID
            id_ex_clk_en = '0;// Run ID_EX
            ex_ma_clk_en = '0;// Run EX_MA
            ma_wb_clk_en = '0;// Run MA_WB
        end

    end: proc_forward_ctrl

    assign trap_addr = 1000; //TODO:TBD

    always_ff @(posedge clk or negedge rst_n) begin: proc_exception
        if (!rst_n) begin: proc_exception_rst
            sepc <= '0;
            scause <= '0;
        end: proc_exception_rst
        else if (clk_en) begin
            if (exception) begin
                sepc <= pc_ex;
                scause <= '0; //TODO: TBD
            end 
        end        
    end: proc_exception
    
endmodule: control