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
 * Package: riscv_definitions
 *
 * Definition of types, opcode, instruction for thw risc-v.
 *
 * Maintainer: Nelson Alves <nelsonafn@gmail.com>
 * Revision : $Revision$
 *
 * History:
 * $Log$ 
 */


package riscv_definitions;

    /* 
     * Type for select the next pc source.
     */
    typedef enum logic [1:0] {
        PC_PLUS4 = 2'b00, 
        JUMP     = 2'b01,
        TRAP     = 2'b1?
    } nextPCType_e;

    /* 
     * Type for select the branch base source.
     * It is used by decoder to inform with should be the base address source for the jump_decision.
     */
    typedef enum logic {
        PC  = 1'b0, 
        RS1 = 1'b1
    } branchBaseSrcType_e;

    /* 
     * Opcode types enum.
     */
    typedef enum logic [6:0] {
        // U-type
        LUI    = 7'b0110111,
        AUIPC  = 7'b0010111,
        // J-type
        JAL    = 7'b1101111,
        // I-type
        JALR   = 7'b1100111,
        // B-type
        // BEQ    = 7'b1100011,
        // BNE    = 7'b1100011,
        // BLT    = 7'b1100011,
        // BGE    = 7'b1100011,
        // BLTU   = 7'b1100011,
        // BGEU   = 7'b1100011,
        BRCH_C = 7'b1100011,
        // I-type
        // LB     = 7'b0000011,
        // LH     = 7'b0000011,
        // LW     = 7'b0000011,
        // LBU    = 7'b0000011,
        // LHU    = 7'b0000011,
        LOAD_C = 7'b0000011,
        // S-type
        // SB     = 7'b0100011,
        // SH     = 7'b0100011,
        // SW     = 7'b0100011,
        STORE_C = 7'b0100011,
        // I-type
        // ADDI   = 7'b0010011,
        // SLTI   = 7'b0010011,
        // SLTIU  = 7'b0010011,
        // XORI   = 7'b0010011,
        // ORI    = 7'b0010011,
        // ANDI   = 7'b0010011,
        // // I-type - Shifts by constant are encoded as specialization of I-type
        // SLLI   = 7'b0010011,
        // SRLI   = 7'b0010011,
        // SRAI   = 7'b0010011,
        ALUI_C = 7'b0010011,
        // R-type
        // ADD    = 7'b0110011,
        // SUB    = 7'b0110011,
        // SLL    = 7'b0110011,
        // SLT    = 7'b0110011,
        // SLTU   = 7'b0110011,
        // XOR    = 7'b0110011,
        // SRL    = 7'b0110011,
        // SRA    = 7'b0110011,
        // OR     = 7'b0110011,
        // AND    = 7'b0110011,
        ALU_C  = 7'b0110011,
        // X-type?
        FENCE  = 7'b0001111,
        // I-type
        // ECALL  = 7'b1110011,
        // EBREAK = 7'b1110011
        ECBK_C = 7'b1110011
    } opcodeType_e;

    /* 
     * Funct3 for R-type enum.
     * It is the specialization for ALUI_C.
     */
    typedef enum logic [2:0] {
        // R-type funct3
        ADD_SUB = 3'b000, //0110011 funct7 0000000/0100000
        SLL     = 3'b001, //0110011 funct7 0000000
        SLT     = 3'b010, //0110011 funct7 0000000
        SLTU    = 3'b011, //0110011 funct7 0000000
        XOR     = 3'b100, //0110011 funct7 0000000
        SRL_SRA = 3'b101, //0110011 funct7 0000000/0100000 
        OR      = 3'b110, //0110011 funct7 0000000
        AND     = 3'b111 //0110011 funct7 0000000
    } funct3RType_e;


    /* 
     * Funct3 for I-type LOAD enum.
     * It is the specialization for LOAD_C.
     */
    typedef enum logic [2:0] {
        // I-type funct3
        LB  = 3'b000, //0000011     
        LH  = 3'b001, //0000011     
        LW  = 3'b010, //0000011     
        LBU = 3'b100, //0000011     
        LHU = 3'b101 //0000011     
    } funct3ITypeLOAD_e;

    /* 
     * Funct3 for I-type ALU enum.
     * It is the specialization for ALU_C.
     */
    typedef enum logic [2:0] {
        // I-type funct3
        ADDI       = 3'b000, //0010011     
        SLTI       = 3'b010, //0010011     
        SLTIU      = 3'b011, //0010011     
        XORI       = 3'b100, //0010011     
        ORI        = 3'b110, //0010011     
        ANDI       = 3'b111, //0010011     
        SLLI       = 3'b001, //0010011 imm0 split into funct7 0000000 and shamt
        SRLI_SRAI  = 3'b101 //0010011 imm0 split into funct7 0000000/0100000 and shamt
    } funct3ITypeALU_e;

    /* 
     * Funct3 for B-type enum.
     * It is the specialization for BRCH_C.
     */
    typedef enum logic [2:0] {
        // B-type funct3
        BEQ  = 3'b000, //1100011    
        BNE  = 3'b001, //1100011    
        BLT  = 3'b100, //1100011    
        BGE  = 3'b101, //1100011    
        BLTU = 3'b110, //1100011    
        BGEU = 3'b111  //1100011    
    } funct3BType_e;

    /* 
     * Funct3 for S-type enum.
     * It is the specialization for STORE_C.
     */
    typedef enum logic [2:0] {
        // S-type funct3
        SB = 3'b000, //0100011
        SH = 3'b001, //0100011
        SW = 3'b010  //0100011
    } funct3SType_e;


    /* 
     * R-type instruction definition.
     */
    typedef struct packed {
        logic [6:0] funct7;
        logic [4:0] rs2;
        logic [4:0] rs1;
        funct3RType_e funct3;
        logic [4:0] rd;
        opcodeType_e opcode; // logic [6:0]
    } instRType_s;

    /* 
     * I-type instruction definition.
     */
    typedef struct packed {
        signed logic [11:0] imm0;
        logic [4:0] rs1;
        logic [2:0] funct3;
        logic [4:0] rd;
        opcodeType_e opcode; // logic [6:0]
    } instIType_s;

    /* 
     * I-type LOAD instruction definition.
     */
    typedef struct packed {
        signed logic [11:0] imm0;
        logic [4:0] rs1;
        funct3ITypeLOAD_e funct3;
        logic [4:0] rd;
        opcodeType_e opcode; // logic [6:0]
    } instITypeLoad_s;


    /* 
     * I-type ALU instruction definition.
     */
    typedef struct packed {
        signed logic [11:0] imm0;
        logic [4:0] rs1;
        funct3ITypeALU_e funct3;
        logic [4:0] rd;
        opcodeType_e opcode; // logic [6:0]
    } instITypeALU_s;

    /* 
     * S-type instruction definition.
     */
    typedef struct packed {
        logic [6:0] imm1;
        logic [4:0] rs2;
        logic [4:0] rs1;
        funct3SType_e funct3;
        logic [4:0] imm0;
        opcodeType_e opcode; // logic [6:0]
    } instSType_s;

    /* 
     * B-type instruction definition.
     */
    typedef struct packed {
        logic [0:0] imm4;
        logic [5:0] imm2;
        logic [4:0] rs2;
        logic [4:0] rs1;
        funct3BType_e funct3;
        logic [4:1] imm1;
        logic [0:0] imm3; //imm0 is predefined as 0 {imm4,imm3,imm2, imm1, 1'b0} 
        opcodeType_e opcode; // logic [6:0]
    } instBType_s;

    /* 
     * U-type instruction definition.
     */
    typedef struct packed {
        logic [19:0] imm1; //imm0 is predefined as 12'b0 {imm1, 12'b0}
        logic [4:0] rd;
        opcodeType_e opcode; // logic [6:0]
    } instUType_s;

    /* 
     * J-type instruction definition.
     */
    typedef struct packed {
        logic [0:0] imm4;
        logic [9:0] imm1;
        logic [0:0] imm2;
        logic [7:0] imm3; //imm0 is predefined as 0 {imm4,imm3,imm2, imm1, 1'b0} 
        logic [4:0] rd;
        opcodeType_e opcode; // logic [6:0]
    } instJType_s;
            
    /* 
     * Instruction definition.
     */
    typedef union packed {
        instRType_s r_type;
        instIType_s i_type;
        instITypeLoad_s i_type_load;
        instITypeALU_s i_type_alu;
        instSType_s s_type;
        instBType_s b_type;
        instUType_s u_type;
        instJType_s j_type;
        logic [0:3] [7:0] memory; 
    } instruction_u;

    /* 
     * Architect data BUS size definition.
     */
    typedef union packed {
        logic [31:0] u_data;
        logic signed [31:0] s_data;
        logic [0:3] [7:0] memory;
    } dataBus_u;

    typedef logic [4:0] regAddr_t;


endpackage: riscv_definitions