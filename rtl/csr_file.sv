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
 * Module: csr_file
 *
 * Description: Machine-mode CSR file of FR-50, read in EX. The address map and
 * the write rule live in riscv_definitions_pkg (csr_implemented,
 * csr_read_only, csr_write_mask), so the legality instruction_decode decides
 * in ID and the storage implemented here are the same table.
 *
 * The read is combinational and has no side effect. The write is synchronous
 * and consumes the source operand of the EX instruction; the read-modify-write
 * value is computed here, from the value being read in the same cycle, because
 * CSRRW/CSRRS/CSRRC share one port.
 *
 * mepc/mcause are written by the trap path (trap_we), which is younger than any
 * CSR instruction in EX: when both target the same register in one cycle, the
 * trap wins (it is the later architectural event).
 *
 * The counter aliases are true views (FR-50, vol. II sec. 2.1.1.10): `cycle`
 * and `cycleh` read the halves of the `mcycle` counter, `instret` and
 * `instreth` the halves of `minstret` plus the older instructions still in
 * MA/WB -- those retire before the instruction reading the counter, so their
 * count belongs to the value it must observe, and both halves come from ONE
 * 64-bit quantity so the carry between them is the hardware's. There is no
 * `cycle` register: a write to `mcycle` is a write to what `cycle` reads, and
 * vice versa. The instret value is stable across a stall (one retires while the
 * other leaves the stage), which is what a held pipeline needs.
 *
 * Maintainer: Nelson Alves <nelsonafn@gmail.com>
 *
 * History:
 * November 20, 2026 - Created by WP-14 F3 (FR-32, FR-37, FR-47, FR-49..FR-52).
 */

module csr_file
import riscv_definitions_pkg::*;
(
    input logic clk,    //[in] Clock
    input logic clk_en, //[in] Clock Enable
    input logic rst_n,  //[in] Asynchronous reset active low
    input logic [11:0] csr_addr, //[in] CSR address of the instruction in EX
    output dataBus_t csr_rdata, //[out] Value read from that address
    input logic csr_we, //[in] Write the addressed CSR this cycle
    input dataBus_t csr_wdata, //[in] Source operand of the write
    input csrOpType_e csr_op, //[in] Zicsr operation (funct3)
    input logic trap_we, //[in] A trap is taken this cycle
    input dataBus_t trap_pc, //[in] PC of the trapping instruction
    input trapCause_e trap_cause, //[in] Cause the trap carries
    input logic [63:0] mtime, //[in] Machine timer (FR-49)
    input logic [3:0] hart_id, //[in] Hart identifier, read as mhartid (FR-32)
    input dataBus_t misa_val, //[in] Configuration-derived misa (FR-37)
    input logic retire_valid, //[in] A valid instruction leaves WB this cycle
    input logic valid_ma, //[in] A valid instruction in MA (older than EX)
    input logic valid_wb, //[in] A valid instruction in WB (older than EX)
    output dataBus_t mtvec_base //[out] Trap vector, mtvec.BASE (FR-29)
);

    /* Architectural state. The counters are 64 bits so a write to either half
     * keeps the other one, and so the wrap/carry is the hardware's and not a
     * test's. */
    dataBus_t mstatus_q;
    dataBus_t mie_q;
    dataBus_t mtvec_q;
    dataBus_t mscratch_q;
    dataBus_t mepc_q;
    dataBus_t mcause_q;
    logic [63:0] mcycle_q;
    logic [63:0] minstret_q;

    /* Next value of the counters and of the read-modify-write CSR write. */
    logic [63:0] mcycle_nxt;
    logic [63:0] minstret_nxt;
    logic [63:0] mcycle_view;
    logic [63:0] instret_view;
    dataBus_t csr_new;

    /* FR-29: direct mode. mtvec.BASE is bits [31:2]; MODE is legalised to 0 on
     * a write, so the vector is the stored base shifted back into place. */
    assign mtvec_base = {mtvec_q[31:2], 2'b00};

    /*
     * FR-50: `cycle`/`cycleh` and `mcycle`/`mcycleh` are two addresses of ONE
     * 64-bit counter, and this is the value both read: the counter as it stands
     * at the end of the cycle the read happens in (the register holds the count
     * as of the start of the cycle, and the counter advances on every enabled
     * cycle). Reading one value for the four addresses is what makes the views
     * views: they cannot disagree with the machine counter, and a write to
     * either half of `mcycle` changes what `cycle` reads.
     */
    always_comb begin: proc_mcycle_view
        mcycle_view = mcycle_q + 64'd1;
    end: proc_mcycle_view

    /*
     * FR-50: `instret`/`instreth` are views of `minstret`/`minstreth`, and the
     * counter the reading instruction must observe includes the instructions
     * older than it that have not yet retired: they retire first, so their
     * count belongs to the value it reads. One 64-bit sum, so the two halves
     * are two views of the same counter and the carry between them is real.
     */
    always_comb begin: proc_instret_view
        instret_view = minstret_q + {63'b0, valid_ma} + {63'b0, valid_wb};
    end: proc_instret_view

    /*
     * Combinational read. The address is the one the instruction in EX carries;
     * an address the decode marks illegal never reaches EX (it traps in ID), so
     * the default arm is only the read-only-zero remainder of FR-50.
     */
    always_comb begin: proc_csr_read
        case (csr_addr)
            CSR_MSTATUS:   csr_rdata = mstatus_q;
            CSR_MISA:      csr_rdata = misa_val;                 // FR-37
            CSR_MIE:       csr_rdata = mie_q;
            CSR_MTVEC:     csr_rdata = mtvec_q;
            CSR_MSTATUSH:  csr_rdata = 32'h0000_0000;            // RO zero
            CSR_MSCRATCH:  csr_rdata = mscratch_q;               // FR-51
            CSR_MEPC:      csr_rdata = mepc_q;                   // FR-23
            CSR_MCAUSE:    csr_rdata = mcause_q;                 // FR-23
            CSR_MTVAL:     csr_rdata = 32'h0000_0000;            // FR-52
            CSR_MIP:       csr_rdata = 32'h0000_0000;
            CSR_MCYCLE:    csr_rdata = mcycle_view[31:0];         // machine counter
            CSR_MINSTRET:  csr_rdata = minstret_q[31:0];
            CSR_MCYCLEH:   csr_rdata = mcycle_view[63:32];        // machine counter
            CSR_MINSTRETH: csr_rdata = minstret_q[63:32];
            CSR_CYCLE:     csr_rdata = mcycle_view[31:0];         // view of mcycle
            CSR_TIME:      csr_rdata = mtime[31:0];              // FR-49
            CSR_INSTRET:   csr_rdata = instret_view[31:0];       // view of minstret
            CSR_CYCLEH:    csr_rdata = mcycle_view[63:32];        // view of mcycleh
            CSR_TIMEH:     csr_rdata = mtime[63:32];
            CSR_INSTRETH:  csr_rdata = instret_view[63:32];      // view of minstreth
            CSR_MHARTID:   csr_rdata = {28'b0, hart_id};         // FR-32
            default:       csr_rdata = 32'h0000_0000;            // RO zero remainder
        endcase
    end: proc_csr_read

    /*
     * The value a write leaves in the CSR. CSRRW/CSRRWI replace, CSRRS/CSRRSI
     * set and CSRRC/CSRRCI clear; the mask then drops the bits the address
     * makes read-only and the WARL legalisation fixes mtvec.MODE and mepc[1:0].
     */
    always_comb begin: proc_csr_new
        case (csr_op)
            CSRRW, CSRRWI: csr_new = csr_wdata;
            CSRRS, CSRRSI: csr_new = csr_rdata | csr_wdata;
            CSRRC, CSRRCI: csr_new = csr_rdata & ~csr_wdata;
            default:       csr_new = csr_wdata;
        endcase
        csr_new = csr_new & csr_write_mask(csr_addr);
        if (csr_addr == CSR_MTVEC)
            if (csr_new[1:0] >= 2'b10) csr_new[1:0] = 2'b00;
        if (csr_addr == CSR_MEPC)
            csr_new[1:0] = 2'b00;
    end: proc_csr_new

    /*
     * Counter next values: free-running, and a CSR write to one half overrides
     * the increment of that half for the cycle, so writing one half keeps the
     * other one and the carry between them stays the hardware's.
     */
    always_comb begin: proc_counter_next
        mcycle_nxt   = mcycle_q + 64'd1;
        minstret_nxt = minstret_q + {63'b0, retire_valid};

        if (csr_we) begin
            case (csr_addr)
                CSR_MCYCLE:    mcycle_nxt[31:0]   = csr_new;
                CSR_MCYCLEH:   mcycle_nxt[63:32]  = csr_new;
                CSR_MINSTRET:  minstret_nxt[31:0] = csr_new;
                CSR_MINSTRETH: minstret_nxt[63:32]= csr_new;
                default: ;
            endcase
        end
    end: proc_counter_next

    /*
     * Synchronous update. The trap assignment comes after the CSR write, so a
     * trap and a younger CSR write to mepc/mcause in the same cycle leave the
     * trap's pair (the trap is the later architectural event).
     */
    always_ff @(posedge clk or negedge rst_n) begin: proc_csr_file
        if (!rst_n) begin: proc_csr_file_rst
            mstatus_q  <= '0;
            mie_q      <= '0;
            mtvec_q    <= '0;
            mscratch_q <= '0;
            mepc_q     <= '0;
            mcause_q   <= '0;
            mcycle_q   <= '0;
            minstret_q <= '0;
        end: proc_csr_file_rst
        else if (clk_en) begin
            mcycle_q   <= mcycle_nxt;
            minstret_q <= minstret_nxt;

            if (csr_we) begin
                case (csr_addr)
                    CSR_MSTATUS:   mstatus_q  <= csr_new;
                    CSR_MIE:       mie_q      <= csr_new;
                    CSR_MTVEC:     mtvec_q    <= csr_new;
                    CSR_MSCRATCH:  mscratch_q <= csr_new;
                    CSR_MEPC:      mepc_q     <= csr_new;
                    CSR_MCAUSE:    mcause_q   <= csr_new;
                    default: ; // misa/mstatush/mtval/mip/counters: see masks
                endcase
            end

            if (trap_we) begin
                mepc_q   <= trap_pc;
                mcause_q <= {28'b0, trap_cause};
            end
        end
    end: proc_csr_file

endmodule: csr_file
