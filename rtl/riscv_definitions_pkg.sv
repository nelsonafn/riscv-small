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

`ifndef RISCV_DEFINITIONS_PKG
`define RISCV_DEFINITIONS_PKG

package riscv_definitions_pkg;

    /*
    * General definitions
    */

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
     * Type enum for select ALU source 1.
     */
    typedef enum logic {
        PC = 1'b0, 
        RS1 = 1'b1
    } aluSrc1_e;

    /* 
     * Type enum for select ALU source 2.
     */
    typedef enum logic {
        RS2 = 1'b0, 
        IMM = 1'b1
    } aluSrc2_e;

    /* 
     * Type enum for select ALU source 1 from control.
     */
    typedef enum logic [1:0] {
        PC_S1 = 2'b00, 
        RS1_S1 = 2'b01,
        RD_MA_S1 = 2'b10, //Red destination (rd) from Memory Access (MA) to rs1 forward
        RD_WB_S1 = 2'b11  //Red destination (rd) from Write Back (WB) to rs1 forward
    } ctrlAluSrc1_e;

    /* 
     * Type enum for select ALU source 2 from control.
     */
    typedef enum logic [1:0] {
        RS2_S2 = 2'b00, 
        IMM_S2 = 2'b01,
        RD_MA_S2 = 2'b10, //Red destination (rd) from Memory Access (MA) to rs2 forward
        RD_WB_S2 = 2'b11  //Red destination (rd) from Write Back (WB) to rs2 forward
    } ctrlAluSrc2_e;

    /* 
     * Type enum for select JUMP COMPARE source from control.
     */
    typedef enum logic [1:0] {
        RD_ID = 2'b00, //Red destination (rd) from instruction Decoder (ID)
        RD_EX = 2'b01, //Red destination (rd) from Execution (EX) to rsx forward
        RD_MA = 2'b10, //Red destination (rd) from Memory Access (MA) to rsx forward
        RD_WB = 2'b11  //Red destination (rd) from Write Back (WB) to rsx forward
    } ctrlCJmpSrc_e;

    /* 
     * Type enum for ALU operation code.
     * These ALU opcode should always be composed by ALU_C/ALUI_C funct3ITypeALU_e enum.
     */
    typedef enum logic [3:0] {
        ALU_ADD  = 4'b0000, // funct7 0000000, funct3 ADD  = 3'b000
        ALU_SLL  = 4'b0001, // funct7 0000000, funct3 SLL  = 3'b001
        ALU_SLT  = 4'b0010, // funct7 0000000, funct3 SLT  = 3'b010
        ALU_SLTU = 4'b0011, // funct7 0000000, funct3 SLTU = 3'b011
        ALU_XOR  = 4'b0100, // funct7 0000000, funct3 XOR  = 3'b100
        ALU_SRL  = 4'b0101, // funct7 0000000, funct3 SRL  = 3'b101
        ALU_OR   = 4'b0110, // funct7 0000000, funct3 OR   = 3'b110
        ALU_AND  = 4'b0111, // funct7 0000000, funct3 AND  = 3'b111
        ALU_SUB  = 4'b1000, // funct7 0100000, funct3 SUB  = 3'b000
        ALU_SRA  = 4'b1101, // funct7 0100000, funct3 SRA  = 3'b101
        ALU_ADD4 = 4'b1001, // Source one plus 4
        ALU_BPS2 = 4'b1010, // By pass source 2
        /* Zicsr (FR-47): pass the CSR read value to write-back untouched. The
         * CSR is read in EX, so it reuses the ALU's write-back mux instead of
         * adding a fourth select (wp-14 D3). */
        CSR_PASS = 4'b1110
    } aluOpType_e;


    typedef logic [4:0] regAddr_t;

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
     * Memory access size, the width shared by data_rd_wr_ctrl and the store
     * lane/strobe logic.
     */
    typedef enum logic [1:0] {
        ACCESS_BYTE = 2'b00,
        ACCESS_HALF = 2'b01,
        ACCESS_WORD = 2'b10
    } accessSize_e;

    /*
     * Zicsr operation, encoded exactly as the instruction's funct3 (FR-47).
     * funct3 000 (ECALL/EBREAK/...) and 100 are not CSR operations and are
     * decoded outside this enum.
     */
    typedef enum logic [2:0] {
        CSRRW  = 3'b001,
        CSRRS  = 3'b010,
        CSRRC  = 3'b011,
        CSRRWI = 3'b101,
        CSRRSI = 3'b110,
        CSRRCI = 3'b111
    } csrOpType_e;

    /*
     * Trap causes this build raises (FR-22..FR-25). TRAP_NONE is the "this
     * instruction is legal" value the decode carries in ID; the external
     * exception bus carries its own 4-bit cause beside it.
     */
    typedef enum logic [3:0] {
        TRAP_NONE                = 4'd0,
        TRAP_ILLEGAL_INSTRUCTION = 4'd2,
        TRAP_BREAKPOINT          = 4'd3,
        TRAP_ECALL_M             = 4'd11
    } trapCause_e;

    /* 
     * Decode the access size from a LOAD or STORE funct3.
     * The low two bits select the width: 00 byte, 01 halfword, 10 word.
     * funct3[2] only distinguishes LBU/LHU from LB/LH. It is total, so a
     * reserved encoding defaults to a word instead of producing 'x.
     */
    function automatic accessSize_e access_size(logic [2:0] funct3);
        case (funct3)
            3'b000, 3'b100: access_size = ACCESS_BYTE;
            3'b001, 3'b101: access_size = ACCESS_HALF;
            3'b010:         access_size = ACCESS_WORD;
            default:        access_size = ACCESS_WORD;
        endcase
    endfunction

    /*
     * Number of bytes an access of that size occupies. The split condition is
     * derived from it (addr[1:0] + bytes > 4, FR-42/G-22) instead of
     * enumerating the misaligned cases one by one.
     */
    function automatic logic [2:0] access_bytes(accessSize_e size);
        case (size)
            ACCESS_BYTE: access_bytes = 3'd1;
            ACCESS_HALF: access_bytes = 3'd2;
            ACCESS_WORD: access_bytes = 3'd4;
            default:     access_bytes = 3'd4;
        endcase
    endfunction

    /*
     * Machine-mode CSR address map (FR-50). This is the ONE truth table:
     * instruction_decode asks csr_implemented()/csr_read_only(), and
     * csr_file uses the same functions, so the legality decided in ID cannot
     * drift from the register the file actually implements.
     */
    localparam logic [11:0] CSR_MSTATUS    = 12'h300;
    localparam logic [11:0] CSR_MISA       = 12'h301;
    localparam logic [11:0] CSR_MIE        = 12'h304;
    localparam logic [11:0] CSR_MTVEC      = 12'h305;
    localparam logic [11:0] CSR_MSTATUSH   = 12'h310;
    localparam logic [11:0] CSR_MSCRATCH   = 12'h340;
    localparam logic [11:0] CSR_MEPC       = 12'h341;
    localparam logic [11:0] CSR_MCAUSE     = 12'h342;
    localparam logic [11:0] CSR_MTVAL      = 12'h343;
    localparam logic [11:0] CSR_MIP        = 12'h344;
    localparam logic [11:0] CSR_MCYCLE     = 12'hB00;
    localparam logic [11:0] CSR_MINSTRET   = 12'hB02;
    localparam logic [11:0] CSR_MCYCLEH    = 12'hB80;
    localparam logic [11:0] CSR_MINSTRETH  = 12'hB82;
    localparam logic [11:0] CSR_CYCLE      = 12'hC00;
    localparam logic [11:0] CSR_TIME       = 12'hC01;
    localparam logic [11:0] CSR_INSTRET    = 12'hC02;
    localparam logic [11:0] CSR_CYCLEH     = 12'hC80;
    localparam logic [11:0] CSR_TIMEH      = 12'hC81;
    localparam logic [11:0] CSR_INSTRETH   = 12'hC82;
    localparam logic [11:0] CSR_MVENDORID  = 12'hF11;
    localparam logic [11:0] CSR_MARCHID    = 12'hF12;
    localparam logic [11:0] CSR_MIMPID     = 12'hF13;
    localparam logic [11:0] CSR_MHARTID    = 12'hF14;
    localparam logic [11:0] CSR_MCONFIGPTR = 12'hF15;

    /*
     * FR-50: is the address implemented at all? The five groups of the
     * requirement, plus the two performance-counter windows the standard makes
     * legally read-only zero. The trigger and debug windows are absent
     * (NUM_TRIGGERS = 0, FR-57), so they take the illegal-instruction trap.
     */
    function automatic logic csr_implemented(logic [11:0] addr);
        case (addr)
            CSR_MSTATUS, CSR_MISA, CSR_MIE, CSR_MTVEC, CSR_MSTATUSH,
            CSR_MSCRATCH, CSR_MEPC, CSR_MCAUSE, CSR_MTVAL, CSR_MIP,
            CSR_MCYCLE, CSR_MINSTRET, CSR_MCYCLEH, CSR_MINSTRETH,
            CSR_CYCLE, CSR_TIME, CSR_INSTRET, CSR_CYCLEH, CSR_TIMEH, CSR_INSTRETH,
            CSR_MVENDORID, CSR_MARCHID, CSR_MIMPID, CSR_MHARTID, CSR_MCONFIGPTR:
                csr_implemented = 1'b1;
            default:
                csr_implemented = ((addr >= 12'hB03) && (addr <= 12'hB1F)) ||
                                  ((addr >= 12'h323) && (addr <= 12'h33F));
        endcase
    endfunction

    /*
     * FR-50 write rule, read from the ADDRESS: csr[11:10] = 2'b11 is a
     * read-only address, so a write there raises illegal-instruction. A write
     * to a read/write address whose bits are read-only is accepted and
     * ignored (see csr_write_mask).
     */
    function automatic logic csr_read_only(logic [11:0] addr);
        csr_read_only = (addr[11:10] == 2'b11);
    endfunction

    /*
     * Which bits a write to a R/W address can change (FR-37, FR-50, FR-52).
     * Zero means "accepted, ignored, no trap".
     */
    function automatic logic [31:0] csr_write_mask(logic [11:0] addr);
        case (addr)
            CSR_MISA, CSR_MSTATUSH, CSR_MTVAL, CSR_MIP:
                csr_write_mask = 32'h0000_0000;
            default:
                csr_write_mask = (((addr >= 12'hB03) && (addr <= 12'hB1F)) ||
                                  ((addr >= 12'h323) && (addr <= 12'h33F)))
                                 ? 32'h0000_0000 : 32'hFFFF_FFFF;
        endcase
    endfunction

    /*
     * FR-37: misa reports the CONFIGURED extension set, never a literal.
     * MXL = 01 (RV32) and I are always present; A, M and C come from the build
     * configuration, so a build that does not execute an extension reads its
     * bit as zero (D11).
     */
    function automatic logic [31:0] misa_value(bit enable_a, bit enable_m, bit enable_c);
        logic [31:0] v;
        v = 32'h0000_0000;
        v[31:30] = 2'b01; // MXL = 1: RV32
        v[8]     = 1'b1;  // I
        if (enable_m) v[12] = 1'b1;
        if (enable_c) v[2]  = 1'b1;
        if (enable_a) v[0]  = 1'b1;
        misa_value = v;
    endfunction


    /* 
     * R-type instruction definition.
     */
    typedef struct packed {
        logic [6:0] funct7;
        regAddr_t rs2;
        regAddr_t rs1;
        funct3RType_e funct3;
        regAddr_t rd;
        opcodeType_e opcode; // logic [6:0]
    } instRType_s;

    /* 
     * I-type instruction definition.
     */
    typedef struct packed {
        logic signed [11:0] imm0;
        regAddr_t rs1;
        logic [2:0] funct3;
        regAddr_t rd;
        opcodeType_e opcode; // logic [6:0]
    } instIType_s;

    /* 
     * I-type LOAD instruction definition.
     */
    typedef struct packed {
        logic signed [11:0] imm0;
        regAddr_t rs1;
        funct3ITypeLOAD_e funct3;
        regAddr_t rd;
        opcodeType_e opcode; // logic [6:0]
    } instITypeLoad_s;


    /* 
     * I-type ALU instruction definition.
     */
    typedef struct packed {
        logic signed [11:0] imm0;
        regAddr_t rs1;
        funct3ITypeALU_e funct3;
        regAddr_t rd;
        opcodeType_e opcode; // logic [6:0]
    } instITypeALU_s;

    /* 
     * S-type instruction definition.
     */
    typedef struct packed {
        logic [6:0] imm1;
        regAddr_t rs2;
        regAddr_t rs1;
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
        regAddr_t rs2;
        regAddr_t rs1;
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
        regAddr_t rd;
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
        regAddr_t rd;
        opcodeType_e opcode; // logic [6:0]
    } instJType_s;

    /* 
     * CSR-type instruction definition (Zicsr, FR-47). The rs1 field carries
     * either a register address or the 5-bit zimm of the immediate forms.
     */
    typedef struct packed {
        logic [11:0] csr;
        regAddr_t rs1;
        logic [2:0] funct3;
        regAddr_t rd;
        opcodeType_e opcode; // logic [6:0]
    } instCSRType_s;
            
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
        instCSRType_s csr_type;
        logic [0:3] [7:0] memory_b; 
        logic [31:0] memory_w;
    } instruction_u;

    /* 
     * Architect data BUS size definition.
     */
    typedef logic [31:0] dataBus_t;
    typedef union packed {
        dataBus_t u_data;
        logic signed [31:0] s_data;
        logic [0:3] [7:0] u_bytes;
        logic [0:1] [15:0] u_half;
        logic signed [0:3] [7:0] s_bytes;
        logic signed [0:1] [15:0] s_half;
    } dataBus_u;


endpackage: riscv_definitions_pkg

`endif