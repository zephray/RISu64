`timescale 1ns / 1ps
`default_nettype none
//
// RISu64
// Copyright 2022 Wenting Zhang
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
`include "defines.vh"

module cpu(
    input  wire         clk,
    input  wire         rst,
    output wire [63:0]  im_req_addr,
    output wire         im_req_valid,
    input  wire [63:0]  im_resp_rdata,
    input  wire         im_resp_valid,
    output wire [63:0]  dm_req_addr,
    output wire [63:0]  dm_req_wdata,
    output wire         dm_req_wen,
    output wire         dm_req_valid,
    input  wire [63:0]  dm_resp_rdata,
    input  wire         dm_resp_valid
);
    // IF stage
    wire [63:0] if_dec_pc;
    wire [31:0] if_dec_instr;
    wire        if_dec_valid;
    wire        if_dec_ready;
    ifu ifu (
        .clk(clk),
        .rst(rst),
        // I-mem interface
        .im_req_addr(im_req_addr),
        .im_req_valid(im_req_valid),
        .im_resp_rdata(im_resp_rdata),
        .im_resp_valid(im_resp_valid),
        // Decoder interface
        .if_dec_pc(if_dec_pc),
        .if_dec_instr(if_dec_instr),
        .if_dec_valid(if_dec_valid),
        .if_dec_ready(if_dec_ready)
    );

    // Decode stage
    wire [63:0] dec_ix_pc;
    wire [2:0]  dec_ix_op;
    wire        dec_ix_option;
    wire        dec_ix_truncate;
    wire        dec_ix_mem_sign;
    wire [1:0]  dec_ix_mem_width;
    wire [1:0]  dec_ix_operand1;
    wire [1:0]  dec_ix_operand2;
    wire [63:0] dec_ix_imm;
    wire [2:0]  dec_ix_op_type;
    wire        dec_ix_legal;
    wire        dec_ix_wb_en;
    wire [4:0]  dec_ix_rs1;
    wire [4:0]  dec_ix_rs2;
    wire [4:0]  dec_ix_rd;
    wire        dec_ix_valid;
    wire        dec_ix_ready;
    dec dec(
        .clk(clk),
        .rst(rst),
        // IF interface
        .if_dec_pc(if_dec_pc),
        .if_dec_instr(if_dec_instr),
        .if_dec_valid(if_dec_valid),
        .if_dec_ready(if_dec_ready),
        // IX interface
        .dec_ix_pc(dec_ix_pc),
        .dec_ix_op(dec_ix_op),
        .dec_ix_option(dec_ix_option),
        .dec_ix_truncate(dec_ix_truncate),
        .dec_ix_mem_sign(dec_ix_mem_sign),
        .dec_ix_mem_width(dec_ix_mem_width),
        .dec_ix_operand1(dec_ix_operand1),
        .dec_ix_operand2(dec_ix_operand2),
        .dec_ix_imm(dec_ix_imm),
        .dec_ix_op_type(dec_ix_op_type),
        .dec_ix_legal(dec_ix_legal),
        .dec_ix_wb_en(dec_ix_wb_en),
        .dec_ix_rs1(dec_ix_rs1),
        .dec_ix_rs2(dec_ix_rs2),
        .dec_ix_rd(dec_ix_rd),
        .dec_ix_valid(dec_ix_valid),
        .dec_ix_ready(dec_ix_ready)
    );

    // Issue and writeback stage
    wire [63:0] ix_ip_pc;
    wire [4:0]  ix_ip_dst;
    wire        ix_ip_wb_en;
    wire [2:0]  ix_ip_op;
    wire        ix_ip_option;
    wire        ix_ip_truncate;
    wire [63:0] ix_ip_operand1;
    wire [63:0] ix_ip_operand2;
    wire        ix_ip_valid;
    wire        ix_ip_ready;
    wire [4:0]  ip_ix_dst;
    wire [63:0] ip_ix_result;
    wire [63:0] ip_ix_pc;
    wire        ip_ix_wb_en;
    wire        ip_ix_valid;
    wire        ip_ix_ready;
    wire [63:0] ix_lsp_pc;
    wire [4:0]  ix_lsp_dst;
    wire        ix_lsp_wb_en;
    wire [63:0] ix_lsp_base;
    wire [11:0] ix_lsp_offset;
    wire [63:0] ix_lsp_source;
    wire        ix_lsp_mem_sign;
    wire [1:0]  ix_lsp_mem_width;
    wire        ix_lsp_valid;
    wire        ix_lsp_ready;
    wire [4:0]  lsp_ix_dst;
    wire [63:0] lsp_ix_result;
    wire [63:0] lsp_ix_pc;
    wire        lsp_ix_wb_en;
    wire        lsp_ix_valid;
    wire        lsp_ix_ready;
    ix ix(
        .clk(clk),
        .rst(rst),
        // IX interface
        .dec_ix_pc(dec_ix_pc),
        .dec_ix_op(dec_ix_op),
        .dec_ix_option(dec_ix_option),
        .dec_ix_truncate(dec_ix_truncate),
        .dec_ix_mem_sign(dec_ix_mem_sign),
        .dec_ix_mem_width(dec_ix_mem_width),
        .dec_ix_operand1(dec_ix_operand1),
        .dec_ix_operand2(dec_ix_operand2),
        .dec_ix_imm(dec_ix_imm),
        .dec_ix_op_type(dec_ix_op_type),
        .dec_ix_legal(dec_ix_legal),
        .dec_ix_wb_en(dec_ix_wb_en),
        .dec_ix_rs1(dec_ix_rs1),
        .dec_ix_rs2(dec_ix_rs2),
        .dec_ix_rd(dec_ix_rd),
        .dec_ix_valid(dec_ix_valid),
        .dec_ix_ready(dec_ix_ready),
        // FU interfaces
        // To integer pipe
        .ix_ip_pc(ix_ip_pc),
        .ix_ip_dst(ix_ip_dst),
        .ix_ip_wb_en(ix_ip_wb_en),
        .ix_ip_op(ix_ip_op),
        .ix_ip_option(ix_ip_option),
        .ix_ip_truncate(ix_ip_truncate),
        .ix_ip_operand1(ix_ip_operand1),
        .ix_ip_operand2(ix_ip_operand2),
        .ix_ip_valid(ix_ip_valid),
        .ix_ip_ready(ix_ip_ready),
        .ip_ix_dst(ip_ix_dst),
        .ip_ix_result(ip_ix_result),
        .ip_ix_pc(ip_ix_pc),
        .ip_ix_wb_en(ip_ix_wb_en),
        .ip_ix_valid(ip_ix_valid),
        .ip_ix_ready(ip_ix_ready),
        // To load/ store pipe
        .ix_lsp_pc(ix_lsp_pc),
        .ix_lsp_dst(ix_lsp_dst),
        .ix_lsp_wb_en(ix_lsp_wb_en),
        .ix_lsp_base(ix_lsp_base),
        .ix_lsp_offset(ix_lsp_offset),
        .ix_lsp_source(ix_lsp_source),
        .ix_lsp_mem_sign(ix_lsp_mem_sign),
        .ix_lsp_mem_width(ix_lsp_mem_width),
        .ix_lsp_valid(ix_lsp_valid),
        .ix_lsp_ready(ix_lsp_ready),
        .lsp_ix_dst(lsp_ix_dst),
        .lsp_ix_result(lsp_ix_result),
        .lsp_ix_pc(lsp_ix_pc),
        .lsp_ix_wb_en(lsp_ix_wb_en),
        .lsp_ix_valid(lsp_ix_valid),
        .lsp_ix_ready(lsp_ix_ready)
    );

    ip ip0(
        .clk(clk),
        .rst(rst),
        // From decoder
        .ix_ip_pc(ix_ip_pc),
        .ix_ip_dst(ix_ip_dst),
        .ix_ip_wb_en(ix_ip_wb_en),
        .ix_ip_op(ix_ip_op),
        .ix_ip_option(ix_ip_option),
        .ix_ip_truncate(ix_ip_truncate),
        .ix_ip_operand1(ix_ip_operand1),
        .ix_ip_operand2(ix_ip_operand2),
        .ix_ip_valid(ix_ip_valid),
        .ix_ip_ready(ix_ip_ready),
        // To writeback
        .ip_ix_dst(ip_ix_dst),
        .ip_ix_result(ip_ix_result),
        .ip_ix_pc(ip_ix_pc),
        .ip_ix_wb_en(ip_ix_wb_en),
        .ip_ix_valid(ip_ix_valid),
        .ip_ix_ready(ip_ix_ready)
    );

    lsp lsp(
        .clk(clk),
        .rst(rst),
        // D-mem interface
        .dm_req_addr(dm_req_addr),
        .dm_req_wdata(dm_req_wdata),
        .dm_req_wen(dm_req_wen),
        .dm_req_valid(dm_req_valid),
        .dm_resp_rdata(dm_resp_rdata),
        .dm_resp_valid(dm_resp_valid),
        // From decoder
        .ix_lsp_pc(ix_lsp_pc),
        .ix_lsp_dst(ix_lsp_dst),
        .ix_lsp_wb_en(ix_lsp_wb_en),
        .ix_lsp_base(ix_lsp_base),
        .ix_lsp_offset(ix_lsp_offset),
        .ix_lsp_source(ix_lsp_source),
        .ix_lsp_mem_sign(ix_lsp_mem_sign),
        .ix_lsp_mem_width(ix_lsp_mem_width),
        .ix_lsp_valid(ix_lsp_valid),
        .ix_lsp_ready(ix_lsp_ready),
        // To writeback
        .lsp_ix_dst(lsp_ix_dst),
        .lsp_ix_result(lsp_ix_result),
        .lsp_ix_pc(lsp_ix_pc),
        .lsp_ix_wb_en(lsp_ix_wb_en),
        .lsp_ix_valid(lsp_ix_valid),
        .lsp_ix_ready(lsp_ix_ready)
    );

endmodule
