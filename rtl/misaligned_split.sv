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
 * Package: misaligned_split
 *
 * Description: Executes a non-atomic access that crosses a 32-bit word
 * boundary as two word-aligned beats, instead of trapping it (FR-42, G-22,
 * A-05). The access is detected by width -- addr[1:0] + bytes > 4 -- and held
 * in Memory Access until both beats are granted. Beat 1 uses the address the
 * core computed and the lane/strobe EX already produced; beat 2 uses
 * (addr & ~3) + 4 with the strobes and the store data recomputed for the bytes
 * that did not fit. A load's two words are merged, before sign/zero extension,
 * into an aligned word, so the accessed field starts at bit 0.
 *
 * The module holds no pipeline register of its own: it observes the EX/MA
 * outputs and drives the data port for the beat it is presenting, and control
 * freezes the pipeline through split_stall. The one edge that advances is the
 * one that completes the second beat.
 *
 * Maintainer: Nelson Alves <nelsonafn@gmail.com>
 *
 * History:
 * November 19, 2026 - Created by WP-13 P6 (FR-42/G-22).
 */

module misaligned_split 
import riscv_definitions_pkg::*;
(
    input clk,    //[in] Clock
    input clk_en, //[in] Clock Enable
    input rst_n,  //[in] Asynchronous reset active low
    input dataBus_u addr_ma, //[in] Effective address in memory access (ma)
    input funct3ITypeLOAD_e funct3_ma, //[in] Access width, load or store funct3 (ma)
    input logic data_rd_en_ma, //[in] Data memory read enable (ma)
    input logic data_wr_en_ma, //[in] Data memory write enable (ma)
    input dataBus_u store_data_ma, //[in] Store operand in memory access, before the lane (ma)
    input dataBus_u store_lane_ma, //[in] Store operand placed in the beat-1 lanes (ma)
    input logic [3:0] store_strb_ma, //[in] Beat-1 byte write strobe (ma)
    input dataBus_u data_rd, //[in] Data from data_memory
    input logic data_ready, //[in] Indicates that data is ready
    output dataBus_u data_addr, //[out] Address of the beat on the data port
    output dataBus_u data_wr, //[out] Store data of the beat
    output logic [3:0] data_wr_strb, //[out] Byte write strobe of the beat
    output logic split_stall, //[out] Hold the pipeline while a split beat is outstanding
    output logic ld_split_en, //[out] This cycle completes a split load
    output dataBus_u ld_split_word //[out] Loaded word assembled from both beats, aligned
);

    /* Beat the data port is presenting. IDLE is not "no access": the beat-1
     * shape is the EX/MA output itself, so the port is combinatorial from the
     * register in both IDLE and BEAT1. The two BEAT2 states are the same beat,
     * split in two because the grant for beat 1 is still a level when beat 2
     * starts: only the second one may consume it. */
    typedef enum logic [1:0] {
        SPLIT_IDLE        = 2'b00,
        SPLIT_BEAT1       = 2'b01,
        SPLIT_BEAT2       = 2'b10,
        SPLIT_BEAT2_GRANT = 2'b11
    } splitState_e;

    splitState_e split_state;

    accessSize_e size_ma;
    logic [2:0]  bytes_ma;
    logic [1:0]  lane_ma;
    logic        access_ma;
    logic        split_needed;
    logic [2:0]  spill_ma;
    logic        beat2_sel;

    dataBus_u beat2_addr;
    dataBus_u beat2_data;
    logic [3:0] beat2_strb;
    dataBus_u beat1_word;

    assign access_ma = data_rd_en_ma || data_wr_en_ma;
    assign size_ma = access_size(funct3_ma);
    assign bytes_ma = access_bytes(size_ma);
    assign lane_ma = addr_ma.u_data[1:0];

    /* FR-42/G-22: the access crosses the word boundary when its byte lane plus
     * its width passes the fourth byte. Derived from the size, not from three
     * special cases: SB/LB never cross, SH/LH only at lane 3, SW/LW at every
     * lane but 0. */
    assign split_needed = access_ma && (({1'b0, lane_ma} + bytes_ma) > 3'd4);

    /* Beat 2 carries the bytes that did not fit: spill = lane + bytes - 4 of
     * them, at lanes 0..spill-1, taken from the top of the store operand. */
    assign spill_ma = {1'b0, lane_ma} + bytes_ma - 3'd4;
    assign beat2_strb = (4'b0001 << spill_ma) - 4'b0001;

    always_comb begin: proc_beat2
        beat2_addr = addr_ma;
        beat2_addr.u_data = (addr_ma.u_data & 32'hFFFF_FFFC) + 32'd4;
        beat2_data = '0;
        beat2_data.u_data = store_data_ma.u_data >> (6'd32 - {1'b0, lane_ma, 3'b000});
    end: proc_beat2

    assign beat2_sel = (split_state == SPLIT_BEAT2) || (split_state == SPLIT_BEAT2_GRANT);

    assign data_addr = beat2_sel ? beat2_addr : addr_ma;
    assign data_wr = beat2_sel ? beat2_data : store_lane_ma;
    assign data_wr_strb = beat2_sel ? beat2_strb : store_strb_ma;

    /* The second beat is done when the memory grants it; split_stall is low at
     * that edge only, so the MA/WB register latches the load with the word the
     * two beats assembled. */
    assign split_stall = ((split_state != SPLIT_IDLE) || split_needed) &&
                         !(split_state == SPLIT_BEAT2_GRANT && data_ready);
    assign ld_split_en = (split_state == SPLIT_BEAT2_GRANT) && data_ready && data_rd_en_ma;

    /* Aligned merge of the two beats: byte 0 of the result is the first byte of
     * the access. For LW at lane 1 this is (word1 >> 8) | (word2 << 24), the
     * value the image compares; a crossing LH keeps its two bytes in the low
     * half, so the same expression serves both widths. */
    always_comb begin: proc_load_merge
        ld_split_word = data_rd;
        ld_split_word.u_data = (beat1_word.u_data >> {1'b0, lane_ma, 3'b000}) |
                               (data_rd.u_data << (6'd32 - {1'b0, lane_ma, 3'b000}));
    end: proc_load_merge

    always_ff @(posedge clk or negedge rst_n) begin: proc_split_state
        if (!rst_n) begin: proc_split_state_rst
            split_state <= SPLIT_IDLE;
            beat1_word <= '0;
        end: proc_split_state_rst
        else if (clk_en) begin
            case (split_state)
                SPLIT_IDLE: begin
                    if (split_needed) split_state <= SPLIT_BEAT1;
                end
                SPLIT_BEAT1: begin
                    if (!access_ma) begin
                        split_state <= SPLIT_IDLE;
                    end
                    else if (data_ready) begin
                        beat1_word <= data_rd;
                        split_state <= SPLIT_BEAT2;
                    end
                end
                SPLIT_BEAT2: begin
                    if (!access_ma) begin
                        split_state <= SPLIT_IDLE;
                    end
                    else begin
                        split_state <= SPLIT_BEAT2_GRANT;
                    end
                end
                SPLIT_BEAT2_GRANT: begin
                    if (!access_ma || data_ready) split_state <= SPLIT_IDLE;
                end
                default: split_state <= SPLIT_IDLE;
            endcase
        end
    end: proc_split_state

endmodule: misaligned_split
