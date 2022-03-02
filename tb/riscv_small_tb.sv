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
 * Package: riscv_small_tb
 *
 * Description: This is the basic test bench made aimed to generate stimulus and 
 * check basic design functionalities.
 *
 * Maintainer: Nelson Alves <nelsonafn@gmail.com>
 *
 * History:
 * March 01, 2022 at 21:10 - Created by Nelson Alves <nelsonafn@gmail.com>
 */
 `timescale 1ns/1ps

module riscv_small_tb;

    logic clk;    //[in] Clock
    logic en;
    logic clk_en; //[in] Clock Enable
    logic rst_n;  //[in] Asynchronous reset active low
    logic exception; //[in] exception
    // Instruction Memory controls
    logic inst_ready; //[in] Indicates that data instruction ready
    instruction_u inst_data; //[in] Data from instruction memory
    dataBus_u inst_addr;//[out] Address of next instruction
    logic inst_rd_en; //[out] Instruction memory read enable 
    // Data Memory controls
    logic data_ready; //[in] Indicates that data is ready
    dataBus_u data_rd; //[in] Data from data_memory
    logic data_rd_en_ma; //[out] Data memory read enable to be used with data_rd_wr_ctrl 
	logic data_wr_en_ma; //[out] Data memory write enable to be used with data_rd_wr_ctrl
    dataBus_u data_wr; //[out] Data to data_memory
    logic [1:0] data_rd_wr_ctrl; //[out] 2'b00 = 8bits, 2'b01 = 16bits, 2'b10 = 32bits,


    clk_gen #(
        .CLK_PERIOD (4), // Period in ns
        .CLK_PHASE (0), // Phase in degrees 
        .CLK_DUTY (50) // Duty cycle of %
    ) u_clk_gen (
        .en     (en), //[in] Clock Enable   
        .clk    (clk) //[in] Clock 
    );

    riscv_small u_riscv_small (
        .clk                (clk),
        //[in] Clock
        .clk_en             (clk_en),
        //[in] Clock Enable
        .rst_n              (rst_n),
        //[in] Asynchronous reset active low
        .exception          (exception),
        //[in] exception
        // Instruction Memory controls
        .inst_ready         (inst_ready),
        //[in] Indicates that data instruction ready
        .inst_data          (inst_data),
        //[in] Data from instruction memory
        .inst_addr          (inst_addr),
        //[out] Address of next instruction
        .inst_rd_en         (inst_rd_en),
        //[out] Instruction memory read enable 
        // Data Memory controls
        .data_ready         (data_ready),
        //[in] Indicates that data is ready
        .data_rd            (data_rd),
        //[in] Data from data_memory
        .data_rd_en_ma      (data_rd_en_ma),
        //[out] Data memory read enable to be used with data_rd_wr_ctrl 
        .data_wr_en_ma      (data_wr_en_ma),
        //[out] Data memory write enable to be used with data_rd_wr_ctrl
        .data_wr            (data_wr),
        //[out] Data to data_memory
        //[out] 2'b00 = 8bits, 2'b01 = 16bits, 2'b10 = 32bits,
        .data_rd_wr_ctrl    (data_rd_wr_ctrl)
    );
    

    initial begin
        clk_en <= '1; //[in] Clock Enable
        en <= '1;
        rst_n <= '0;  //[in] Asynchronous reset active low
        exception <= '0; //[in] exception
        @(posedge clk);
        @(posedge clk);
        rst_n <= '1;
    end

    initial begin
        // Instruction Memory controls
        inst_ready <= '1; //[in] Indicates that data instruction ready
        inst_data <= '0; //[in] Data from instruction memory
        //dataBus_u inst_addr;//[out] Address of next instruction
        //logic inst_rd_en; //[out] Instruction memory read enable 
    end

    initial begin
        // Data Memory controls
        data_ready <= '1; //[in] Indicates that data is ready
        data_rd <= '0; //[in] Data from data_memory
        //logic data_rd_en_ma; //[out] Data memory read enable to be used with data_rd_wr_ctrl 
        //logic data_wr_en_ma; //[out] Data memory write enable to be used with data_rd_wr_ctrl
        //dataBus_u data_wr; //[out] Data to data_memory
        //logic [1:0] data_rd_wr_ctrl; //[out] 2'b00 = 8bits, 2'b01 = 16bits, 2'b10 = 32bits,
    end
    
endmodule: riscv_small_tb