//Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2019.2 (win64) Build 2708876 Wed Nov  6 21:40:23 MST 2019
//Date        : Wed Apr 20 01:10:51 2022
//Host        : DESKTOP-ELJAE7D running 64-bit major release  (build 9200)
//Command     : generate_target frame_buffer_1MB_wrapper.bd
//Design      : frame_buffer_1MB_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module frame_buffer_1MB_wrapper
   (aclk,
    allow_count_o,
    allow_i,
    aresetn,
    ddr_act_n,
    ddr_adr,
    ddr_ba,
    ddr_bg,
    ddr_ck_c,
    ddr_ck_t,
    ddr_cke,
    ddr_clk,
    ddr_cs_n,
    ddr_dm_n,
    ddr_dq,
    ddr_dqs_c,
    ddr_dqs_t,
    ddr_odt,
    ddr_ready,
    ddr_ref_clk,
    ddr_reset_n,
    m_ddrev_tdata,
    m_ddrev_tkeep,
    m_ddrev_tlast,
    m_ddrev_tready,
    m_ddrev_tvalid,
    m_event_tdata,
    m_event_tkeep,
    m_event_tlast,
    m_event_tready,
    m_event_tvalid,
    m_mm2s_sts_tdata,
    m_mm2s_sts_tkeep,
    m_mm2s_sts_tlast,
    m_mm2s_sts_tready,
    m_mm2s_sts_tvalid,
    m_s2mm_sts_tdata,
    m_s2mm_sts_tkeep,
    m_s2mm_sts_tlast,
    m_s2mm_sts_tready,
    m_s2mm_sts_tvalid,
    reset_i,
    s_ack_tdata,
    s_ack_tready,
    s_ack_tvalid,
    s_ddrev_tdata,
    s_ddrev_tkeep,
    s_ddrev_tlast,
    s_ddrev_tready,
    s_ddrev_tvalid,
    s_nack_tdata,
    s_nack_tready,
    s_nack_tvalid,
    sys_rst);
  input aclk;
  output [8:0]allow_count_o;
  input allow_i;
  input aresetn;
  output ddr_act_n;
  output [16:0]ddr_adr;
  output [1:0]ddr_ba;
  output [1:0]ddr_bg;
  output [0:0]ddr_ck_c;
  output [0:0]ddr_ck_t;
  output [0:0]ddr_cke;
  output ddr_clk;
  output [0:0]ddr_cs_n;
  inout [3:0]ddr_dm_n;
  inout [31:0]ddr_dq;
  inout [3:0]ddr_dqs_c;
  inout [3:0]ddr_dqs_t;
  output [0:0]ddr_odt;
  output ddr_ready;
  input ddr_ref_clk;
  output ddr_reset_n;
  output [255:0]m_ddrev_tdata;
  output [31:0]m_ddrev_tkeep;
  output m_ddrev_tlast;
  input m_ddrev_tready;
  output m_ddrev_tvalid;
  output [31:0]m_event_tdata;
  output [3:0]m_event_tkeep;
  output m_event_tlast;
  input m_event_tready;
  output m_event_tvalid;
  output [7:0]m_mm2s_sts_tdata;
  output [0:0]m_mm2s_sts_tkeep;
  output [0:0]m_mm2s_sts_tlast;
  input [0:0]m_mm2s_sts_tready;
  output [0:0]m_mm2s_sts_tvalid;
  output [31:0]m_s2mm_sts_tdata;
  output [3:0]m_s2mm_sts_tkeep;
  output m_s2mm_sts_tlast;
  input m_s2mm_sts_tready;
  output m_s2mm_sts_tvalid;
  input reset_i;
  input [15:0]s_ack_tdata;
  output s_ack_tready;
  input s_ack_tvalid;
  input [255:0]s_ddrev_tdata;
  input [31:0]s_ddrev_tkeep;
  input s_ddrev_tlast;
  output s_ddrev_tready;
  input s_ddrev_tvalid;
  input [31:0]s_nack_tdata;
  output s_nack_tready;
  input s_nack_tvalid;
  input sys_rst;

  wire aclk;
  wire [8:0]allow_count_o;
  wire allow_i;
  wire aresetn;
  wire ddr_act_n;
  wire [16:0]ddr_adr;
  wire [1:0]ddr_ba;
  wire [1:0]ddr_bg;
  wire [0:0]ddr_ck_c;
  wire [0:0]ddr_ck_t;
  wire [0:0]ddr_cke;
  wire ddr_clk;
  wire [0:0]ddr_cs_n;
  wire [3:0]ddr_dm_n;
  wire [31:0]ddr_dq;
  wire [3:0]ddr_dqs_c;
  wire [3:0]ddr_dqs_t;
  wire [0:0]ddr_odt;
  wire ddr_ready;
  wire ddr_ref_clk;
  wire ddr_reset_n;
  wire [255:0]m_ddrev_tdata;
  wire [31:0]m_ddrev_tkeep;
  wire m_ddrev_tlast;
  wire m_ddrev_tready;
  wire m_ddrev_tvalid;
  wire [31:0]m_event_tdata;
  wire [3:0]m_event_tkeep;
  wire m_event_tlast;
  wire m_event_tready;
  wire m_event_tvalid;
  wire [7:0]m_mm2s_sts_tdata;
  wire [0:0]m_mm2s_sts_tkeep;
  wire [0:0]m_mm2s_sts_tlast;
  wire [0:0]m_mm2s_sts_tready;
  wire [0:0]m_mm2s_sts_tvalid;
  wire [31:0]m_s2mm_sts_tdata;
  wire [3:0]m_s2mm_sts_tkeep;
  wire m_s2mm_sts_tlast;
  wire m_s2mm_sts_tready;
  wire m_s2mm_sts_tvalid;
  wire reset_i;
  wire [15:0]s_ack_tdata;
  wire s_ack_tready;
  wire s_ack_tvalid;
  wire [255:0]s_ddrev_tdata;
  wire [31:0]s_ddrev_tkeep;
  wire s_ddrev_tlast;
  wire s_ddrev_tready;
  wire s_ddrev_tvalid;
  wire [31:0]s_nack_tdata;
  wire s_nack_tready;
  wire s_nack_tvalid;
  wire sys_rst;

  frame_buffer_1MB frame_buffer_1MB_i
       (.aclk(aclk),
        .allow_count_o(allow_count_o),
        .allow_i(allow_i),
        .aresetn(aresetn),
        .ddr_act_n(ddr_act_n),
        .ddr_adr(ddr_adr),
        .ddr_ba(ddr_ba),
        .ddr_bg(ddr_bg),
        .ddr_ck_c(ddr_ck_c),
        .ddr_ck_t(ddr_ck_t),
        .ddr_cke(ddr_cke),
        .ddr_clk(ddr_clk),
        .ddr_cs_n(ddr_cs_n),
        .ddr_dm_n(ddr_dm_n),
        .ddr_dq(ddr_dq),
        .ddr_dqs_c(ddr_dqs_c),
        .ddr_dqs_t(ddr_dqs_t),
        .ddr_odt(ddr_odt),
        .ddr_ready(ddr_ready),
        .ddr_ref_clk(ddr_ref_clk),
        .ddr_reset_n(ddr_reset_n),
        .m_ddrev_tdata(m_ddrev_tdata),
        .m_ddrev_tkeep(m_ddrev_tkeep),
        .m_ddrev_tlast(m_ddrev_tlast),
        .m_ddrev_tready(m_ddrev_tready),
        .m_ddrev_tvalid(m_ddrev_tvalid),
        .m_event_tdata(m_event_tdata),
        .m_event_tkeep(m_event_tkeep),
        .m_event_tlast(m_event_tlast),
        .m_event_tready(m_event_tready),
        .m_event_tvalid(m_event_tvalid),
        .m_mm2s_sts_tdata(m_mm2s_sts_tdata),
        .m_mm2s_sts_tkeep(m_mm2s_sts_tkeep),
        .m_mm2s_sts_tlast(m_mm2s_sts_tlast),
        .m_mm2s_sts_tready(m_mm2s_sts_tready),
        .m_mm2s_sts_tvalid(m_mm2s_sts_tvalid),
        .m_s2mm_sts_tdata(m_s2mm_sts_tdata),
        .m_s2mm_sts_tkeep(m_s2mm_sts_tkeep),
        .m_s2mm_sts_tlast(m_s2mm_sts_tlast),
        .m_s2mm_sts_tready(m_s2mm_sts_tready),
        .m_s2mm_sts_tvalid(m_s2mm_sts_tvalid),
        .reset_i(reset_i),
        .s_ack_tdata(s_ack_tdata),
        .s_ack_tready(s_ack_tready),
        .s_ack_tvalid(s_ack_tvalid),
        .s_ddrev_tdata(s_ddrev_tdata),
        .s_ddrev_tkeep(s_ddrev_tkeep),
        .s_ddrev_tlast(s_ddrev_tlast),
        .s_ddrev_tready(s_ddrev_tready),
        .s_ddrev_tvalid(s_ddrev_tvalid),
        .s_nack_tdata(s_nack_tdata),
        .s_nack_tready(s_nack_tready),
        .s_nack_tvalid(s_nack_tvalid),
        .sys_rst(sys_rst));
endmodule
