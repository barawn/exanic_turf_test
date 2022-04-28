`timescale 1ns / 1ps
// ExaNIC TURF test, PSA 4/12/22, consisting of:
//
// UDP interface mimicking TURF
// Xillybus PCIe interface for mimicking DAQ event behavior
// DDR interface storing fake events

// Derived from the ExaNIC X25 example for verilog-ethernet,
// which had the following copyright notice.

/*

Copyright (c) 2014-2021 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/


module exanic_turf_test(
    input wire clk_10mhz,
    /*
     * GPIO
     */
    output wire [1:0] sfp_1_led,
    output wire [1:0] sfp_2_led,
    output wire [1:0] sma_led,

    /*
     * Ethernet: SFP+
     */
    input  wire       sfp_1_rx_p,
    input  wire       sfp_1_rx_n,
    output wire       sfp_1_tx_p,
    output wire       sfp_1_tx_n,
    input  wire       sfp_2_rx_p,
    input  wire       sfp_2_rx_n,
    output wire       sfp_2_tx_p,
    output wire       sfp_2_tx_n,
    input  wire       sfp_mgt_refclk_p,
    input  wire       sfp_mgt_refclk_n,
    output wire       sfp_1_tx_disable,
    output wire       sfp_2_tx_disable,
    input  wire       sfp_1_npres,
    input  wire       sfp_2_npres,
    input  wire       sfp_1_los,
    input  wire       sfp_2_los,
    output wire       sfp_1_rs,
    output wire       sfp_2_rs,
    // DDR4
    input  clk161_ddr_p,
    input  clk161_ddr_n,
    output [16:0] c0_ddr4_adr,
    output [1:0] c0_ddr4_ba,
    output [0:0] c0_ddr4_cke,
    output [0:0] c0_ddr4_cs_n,
    inout [3:0] c0_ddr4_dm_dbi_n,
    inout [31:0] c0_ddr4_dq,
    inout [3:0] c0_ddr4_dqs_c,
    inout [3:0] c0_ddr4_dqs_t,
    output [0:0] c0_ddr4_odt,
    output [1:0] c0_ddr4_bg,
    output c0_ddr4_reset_n,
    output c0_ddr4_act_n,
    output [0:0] c0_ddr4_ck_c,
    output [0:0] c0_ddr4_ck_t,
    input ddr_npres,
    // PCIe
    input [7:0] pcie_rx_p,
    input [7:0] pcie_rx_n,
    output [7:0] pcie_tx_p,
    output [7:0] pcie_tx_n,
    input pcie_refclk_p,
    input pcie_refclk_n,
    input pcie_reset_n
);

    parameter [31:0] IDENT = "TURF";
    parameter [3:0] VER_MAJOR = 0;
    parameter [3:0] VER_MINOR = 0;
    parameter [7:0] VER_REV = 2;
    localparam [15:0] FIRMWARE_VERSION = { VER_MAJOR, VER_MINOR, VER_REV };
    parameter [15:0] FIRMWARE_DATE = {16{1'b0}};
    localparam [31:0] DATEVERSION = { FIRMWARE_DATE, FIRMWARE_VERSION };
    
wire init_clk;
(* KEEP = "TRUE" *)
BUFG u_init_clk(.I(clk_10mhz),.O(init_clk));

wire ifclk;
wire ifen;
wire ifwr;
wire ifack;
wire [27:0] ifadr;
wire [31:0] ifdat_read;
wire [31:0] ifdat_write;
reg [31:0] test_reg = {32{1'b0}};
wire [31:0] registers[3:0];
assign registers[0] = IDENT;
assign registers[1] = DATEVERSION;
assign registers[2] = test_reg;
assign registers[3] = DATEVERSION;

turf_udp_wrap #(.NSFP(2)) 
    u_udp_wrap( .sfp_led( { sfp_2_led, sfp_1_led } ),
                .sfp_tx_p({ sfp_2_tx_p, sfp_1_tx_p } ),
                .sfp_tx_n({ sfp_2_tx_n, sfp_1_tx_n } ),
                .sfp_rx_p({ sfp_2_rx_p, sfp_1_rx_p } ),
                .sfp_rx_n({ sfp_2_rx_n, sfp_1_rx_n } ),
                .sfp_refclk_p( sfp_mgt_refclk_p ),
                .sfp_refclk_n( sfp_mgt_refclk_n ),
                .sfp_tx_disable( { sfp_2_tx_disable, sfp_1_tx_disable } ),
                .sfp_npres( { sfp_2_npres, sfp_1_npres } ),
                .sfp_los( { sfp_2_los, sfp_1_los } ),
                .sfp_rs( { sfp_2_rs, sfp_1_rs } ),
                
                .clk_o(ifclk),
                .en_o(ifen),
                .wr_o(ifwr),
                .ack_i(ifack),
                .adr_o(ifadr),
                .dat_i(ifdat_read),
                .dat_o(ifdat_write));
                
assign ifack = ifen;
assign ifdat_read = registers[ifadr[1:0]];
always @(posedge ifclk) begin
    if (ifen && ifwr && ifadr[1:0] == 2'd2) test_reg <= ifdat_write;
end
// xillybus
wire xil_clk;
wire interface_not_ready;
// These are the request/response paths. They're 32 bits,
// but they need to be 64 bits so sadly this means
// you *have* to make sure to read/write stuff in pairs.
// This has to be used instead of the memory-mapped
// stuff because that interface has no way to arbitrate
// a transaction against an interface with delayed response:
// when you issue an addr update, there's no way to know
// if it's a read or a write pending, and when you read
// you *have* to provide data one cycle later. Which
// means you *have* to execute a read every time there's
// an address update even though there might not be
// an actual read. Which means reads must be benign,
// which cannot be guaranteed on an interface.
//
// So instead, we just mock it up with a request/response.

// request path
wire [31:0] xil_mmreq_data;
wire        xil_mmreq_wren;
wire        xil_mmreq_wrfull;
wire        xil_mmreq_open;
// response path
wire [31:0] xil_mmresp_data;
wire        xil_mmresp_rden;
wire        xil_mmresp_rdempty;
wire        xil_mmresp_open;
wire        xil_mmresp_eof = 1'b0;

// state change path
wire [7:0]  xil_event_ctrl_data;
wire        xil_event_ctrl_rden;
wire        xil_event_ctrl_rdempty;
wire        xil_event_ctrl_open;
wire        xil_event_ctrl_eof = 1'b0;

// and inbound event path
wire [31:0] xil_event_out_data;
wire        xil_event_out_wren;
wire        xil_event_out_wrfull;
wire        xil_event_out_open;

// I dunno what these do.
wire [3:0] GPIO_LED;

// Kill the inbound paths for now
assign xil_event_ctrl_rdempty = 1'b0;
assign xil_event_ctrl_data = 8'h00;

assign xil_mmresp_data = {32{1'b0}};
assign xil_mmresp_rdempty = 1'b0;

// and don't care the fulls
assign xil_mmreq_wrfull = 1'b0;
assign xil_event_out_wrfull = 1'b0;

xillybus u_xillybus(.PCIE_TX_P(pcie_tx_p),
                    .PCIE_TX_N(pcie_tx_n),
                    .PCIE_RX_P(pcie_rx_p),
                    .PCIE_RX_N(pcie_rx_n),
                    .PCIE_REFCLK_P(pcie_refclk_p),
                    .PCIE_REFCLK_N(pcie_refclk_n),
                    .PCIE_PERST_B_LS(pcie_reset_n),
                    .bus_clk(xil_clk),
                    .quiesce(interface_not_ready),
                    .GPIO_LED(GPIO_LED),
                    // request path
                    .user_w_mmreq_data( xil_mmreq_data ),
                    .user_w_mmreq_wren( xil_mmreq_wren ),
                    .user_w_mmreq_full( xil_mmreq_wrfull ),
                    .user_w_mmreq_open( xil_mmreq_open ),
                    // response path
                    .user_r_mmresp_data( xil_mmresp_data ),
                    .user_r_mmresp_rden( xil_mmresp_rden ),
                    .user_r_mmresp_empty(xil_mmresp_rdempty ),
                    .user_r_mmresp_eof(  xil_mmresp_eof ),
                    .user_r_mmresp_open( xil_mmresp_open ),
                    // state change path
                    .user_r_event_ctrl_data( xil_event_ctrl_data ),
                    .user_r_event_ctrl_rden( xil_event_ctrl_rden ),
                    .user_r_event_ctrl_empty(xil_event_ctrl_rdempty ),
                    .user_r_event_ctrl_eof(  xil_event_ctrl_eof ),
                    .user_r_event_ctrl_open( xil_event_ctrl_open ),
                    // inbound event path
                    .user_w_event_out_data( xil_event_out_data ),
                    .user_w_event_out_wren( xil_event_out_wren ),
                    .user_w_event_out_full( xil_event_out_wrfull ),
                    .user_w_event_out_open( xil_event_out_open ));

// ddr4
wire ddr_cal_ok;
wire ddr_clk;
wire ddr_reset_sync;
wire ddr_reset;

wire ddr_sys_clk_in;
IBUFDS u_ddr4_ibufds(.I(clk161_ddr_p),.IB(clk161_ddr_n),.O(ddr_sys_clk_in));
BUFG u_ddr4_bufg(.I(ddr_sys_clk_in),.O(ddr_sys_clk_g));

ddr4_0 u_ddr4( .c0_sys_clk_i(ddr_sys_clk_g),
               .sys_rst(ddr_reset),
               .c0_ddr4_adr(c0_ddr4_adr),
               .c0_ddr4_ba(c0_ddr4_ba),
               .c0_ddr4_cke(c0_ddr4_cke),
               .c0_ddr4_cs_n(c0_ddr4_cs_n),
               .c0_ddr4_dm_dbi_n(c0_ddr4_dm_dbi_n),
               .c0_ddr4_dq(c0_ddr4_dq),
               .c0_ddr4_dqs_c(c0_ddr4_dqs_c),
               .c0_ddr4_dqs_t(c0_ddr4_dqs_t),
               .c0_ddr4_odt(c0_ddr4_odt),
               .c0_ddr4_bg(c0_ddr4_bg),
               .c0_ddr4_reset_n(c0_ddr4_reset_n),
               .c0_ddr4_act_n(c0_ddr4_act_n),
               .c0_ddr4_ck_c(c0_ddr4_ck_c),
               .c0_ddr4_ck_t(c0_ddr4_ck_t),
               
               // app
               .c0_init_calib_complete(ddr_cal_ok),
               .c0_ddr4_ui_clk(ddr_clk),
               .c0_ddr4_ui_clk_sync_rst(ddr_reset_sync),
               // we use the AXI interface
               .c0_ddr4_aresetn(!ddr_reset_sync)
               // but not now
               );               
 ddr4_vio u_vio(.clk(ddr_clk),
                .probe_in0( ddr_cal_ok ),
                .probe_in1( ddr_reset_sync ),
                .probe_out0( ddr_reset ));              
// ILA for event out
// probe0: quiesce
// probe1: open
// probe2: wren
// probe3: data 
event_ila u_evila(.clk(xil_clk),
                .probe0( interface_not_ready ),
                .probe1( xil_event_out_open ),
                .probe2( xil_event_out_wren ),
                .probe3( xil_event_out_data ));

xil_vio u_xilvio(.clk(xil_clk),
                 .probe_in0( GPIO_LED[0] ),
                 .probe_in1( GPIO_LED[1] ),
                 .probe_in2( GPIO_LED[2] ),
                 .probe_in3( GPIO_LED[3] ),
                 .probe_in4( pcie_reset_n ));
                
sfp_vio u_sfpvio(.clk(ifclk),
                 .probe_in0(sfp_1_npres),
                 .probe_in1(sfp_2_npres));

endmodule
