`timescale 1ns / 1ps
`include "interfaces.vh"

// This module wraps up the various SFP and UDP related stuff.
// 
module turf_udp_wrap #(parameter NSFP=2)(
        output [2*NSFP-1:0] sfp_led,
        output [NSFP-1:0] sfp_tx_p,
        output [NSFP-1:0] sfp_tx_n,
        input [NSFP-1:0] sfp_rx_p,
        input [NSFP-1:0] sfp_rx_n,
        input sfp_refclk_p,
        input sfp_refclk_n,
        output [NSFP-1:0] sfp_tx_disable,
        input [NSFP-1:0] sfp_npres,
        input [NSFP-1:0] sfp_los,
        output [NSFP-1:0] sfp_rs,
        
        // register interface
        output  clk_o,
        output  en_o,
        output  wr_o,
        input   ack_i,
        output [27:0] adr_o,
        input [31:0] dat_i,
        output [31:0] dat_o                
    );

    localparam COMMON_SFP=0;
    
    wire sfp_mgt_refclk;
    // 161.1328125
    wire sfp_refclk;    
    wire sfp_gtpowergood;
    wire sfp_qpll0lock;
    wire sfp_qpll0outclk;
    wire sfp_qpll0outrefclk;
        
    wire [NSFP-1:0] sfp_tx_clk;
    wire [NSFP-1:0] sfp_tx_rst;
    wire [63:0]     sfp_txd[NSFP-1:0];
    wire [7:0]      sfp_txc[NSFP-1:0];
    wire [NSFP-1:0] sfp_rx_clk;
    wire [NSFP-1:0] sfp_rx_rst;
    wire [63:0]     sfp_rxd[NSFP-1:0];
    wire [7:0]      sfp_rxc[NSFP-1:0];    
    wire [NSFP-1:0] sfp_rx_block_lock;

    wire clk156 = sfp_tx_clk[0];
    wire clk156_rst = sfp_tx_rst[0];    

    wire refclk_int;
    // the defaults here are all 0, which implies ODIV2 is actually just O = 161 MHz
    IBUFDS_GTE4 ibufds_refclk(.I(sfp_refclk_p),.IB(sfp_refclk_n),
                              .CEB(1'b0),
                              .O(sfp_mgt_refclk),
                              .ODIV2(refclk_int));
    BUFG_GT bufg_gt_refclk(.I(refclk_int),.O(sfp_refclk),
                           .CE(sfp_gtpowergood),
                           .CEMASK(1'b1),
                           .CLR(1'b0),
                           .CLRMASK(1'b1),
                           .DIV(3'b000));

    // Clocking
    // Generate a 125 MHz clock.
    wire mmcm_rst = 1'b0;
    wire mmcm_locked;
    wire mmcm_clkfb;
    // 125 MHz clock stuff
    wire clk125;
    wire rst_clk125;
    wire clk_125mhz_mmcm_out;
    // MMCM instance
    // 161.13 MHz in, 125 MHz out
    // PFD range: 10 MHz to 500 MHz
    // VCO range: 800 MHz to 1600 MHz
    // M = 64, D = 11 sets Fvco = 937.5 MHz (in range)
    // Divide by 7.5 to get output frequency of 125 MHz
    MMCME4_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKOUT0_DIVIDE_F(7.5),
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT0_PHASE(0),
        .CLKOUT1_DIVIDE(1),
        .CLKOUT1_DUTY_CYCLE(0.5),
        .CLKOUT1_PHASE(0),
        .CLKOUT2_DIVIDE(1),
        .CLKOUT2_DUTY_CYCLE(0.5),
        .CLKOUT2_PHASE(0),
        .CLKOUT3_DIVIDE(1),
        .CLKOUT3_DUTY_CYCLE(0.5),
        .CLKOUT3_PHASE(0),
        .CLKOUT4_DIVIDE(1),
        .CLKOUT4_DUTY_CYCLE(0.5),
        .CLKOUT4_PHASE(0),
        .CLKOUT5_DIVIDE(1),
        .CLKOUT5_DUTY_CYCLE(0.5),
        .CLKOUT5_PHASE(0),
        .CLKOUT6_DIVIDE(1),
        .CLKOUT6_DUTY_CYCLE(0.5),
        .CLKOUT6_PHASE(0),
        .CLKFBOUT_MULT_F(64),
        .CLKFBOUT_PHASE(0),
        .DIVCLK_DIVIDE(11),
        .REF_JITTER1(0.010),
        .CLKIN1_PERIOD(6.206),
        .STARTUP_WAIT("FALSE"),
        .CLKOUT4_CASCADE("FALSE")
    )
    clk_mmcm_inst (
        .CLKIN1(sfp_refclk),
        .CLKFBIN(mmcm_clkfb),
        .RST(mmcm_rst),
        .PWRDWN(1'b0),
        .CLKOUT0(clk_125mhz_mmcm_out),
        .CLKOUT0B(),
        .CLKOUT1(),
        .CLKOUT1B(),
        .CLKOUT2(),
        .CLKOUT2B(),
        .CLKOUT3(),
        .CLKOUT3B(),
        .CLKOUT4(),
        .CLKOUT5(),
        .CLKOUT6(),
        .CLKFBOUT(mmcm_clkfb),
        .CLKFBOUTB(),
        .LOCKED(mmcm_locked)
    );

    BUFG u_clk125(.I(clk_125mhz_mmcm_out),.O(clk125));
    sync_reset #(.N(4)) sync_reset_125mhz_inst( .clk(clk125),
                                                .rst(~mmcm_locked),
                                                .out(rst_clk125));
         
    generate
        genvar i;
        for (i=0;i<NSFP;i=i+1) begin : SFP
            wire powergood;
            wire qpll0lock;
            wire qpll0outclk;
            wire qpll0outrefclk;
            
            wire qpll0lock_in;
            wire qpll0outclk_in;
            wire qpll0outrefclk_in;
                        
            if (i==COMMON_SFP) begin : HEAD
                assign sfp_gtpowergood = powergood;
                assign sfp_qpll0lock = qpll0lock;
                assign sfp_qpll0outclk = qpll0outclk;
                assign sfp_qpll0outrefclk = qpll0outrefclk;
            end else begin : BODY
                assign qpll0lock_in = sfp_qpll0lock;
                assign qpll0outclk_in = sfp_qpll0outclk;
                assign qpll0outrefclk_in = sfp_qpll0outrefclk;
            end
            eth_xcvr_phy_wrapper #(.HAS_COMMON(i==0?1:0))
                u_phy( .xcvr_ctrl_clk( clk125 ),
                       .xcvr_ctrl_rst( rst_clk125 ),
                       .xcvr_gtpowergood_out(powergood),
                       .xcvr_gtrefclk00_in(sfp_mgt_refclk),
                       .xcvr_qpll0lock_out(qpll0lock),
                       .xcvr_qpll0outclk_out(sfp_qpll0outclk),
                       .xcvr_qpll0outrefclk_out(sfp_qpll0outrefclk),
                       
                       .xcvr_qpll0lock_in(qpll0lock_in),
                       .xcvr_qpll0reset_out(),
                       .xcvr_qpll0clk_in(qpll0outclk_in),
                       .xcvr_qpll0refclk_in(qpll0outrefclk_in),
                       
                       .xcvr_txp(sfp_tx_p[i]),
                       .xcvr_txn(sfp_tx_n[i]),
                       .xcvr_rxp(sfp_rx_p[i]),
                       .xcvr_rxn(sfp_rx_n[i]),
                       
                       .phy_tx_clk(sfp_tx_clk[i]),
                       .phy_tx_rst(sfp_tx_rst[i]),
                       .phy_xgmii_txd(sfp_txd[i]),
                       .phy_xgmii_txc(sfp_txc[i]),
                       .phy_rx_clk(sfp_rx_clk[i]),
                       .phy_rx_rst(sfp_rx_rst[i]),
                       .phy_xgmii_rxd(sfp_rxd[i]),
                       .phy_xgmii_rxc(sfp_rxc[i]),
                       .phy_rx_block_lock(sfp_rx_block_lock[i]));
           assign sfp_led[2*i + 0] = sfp_rx_block_lock[i];
           assign sfp_tx_disable[i] = 1'b0;
           assign sfp_rs[i] = 1'b1;
        end        
    endgenerate

    // kill the unused. well, make it go idle I guess
    assign sfp_txd[1] = 64'h0707070707070707;
    assign sfp_txc[1] = 8'hff;
    
    // the header path is always 64 bits
    localparam PAYLOAD_WIDTH=64;

    // OK, now the UDP stuff. See how much more compact this is...?
    `DEFINE_AXI4S_MIN_IF( udpin_hdr_ , 64);
    wire [15:0] udpin_hdr_tdest;
    `DEFINE_AXI4S_IF( udpin_data_ , PAYLOAD_WIDTH);
    
    `DEFINE_AXI4S_MIN_IF( udpout_hdr_ , 64);
    wire [15:0] udpout_hdr_tuser;
    `DEFINE_AXI4S_IF( udpout_data_ , PAYLOAD_WIDTH);       
    
    // Its clock is clk156, its reset is clk156_rst.
    turf_udp_core u_udp_core( .clk(clk156), .rst(clk156_rst),
        .sfp_tx_clk(sfp_tx_clk[0]),
        .sfp_tx_rst(sfp_tx_rst[0]),
        .sfp_txd(sfp_txd[0]),
        .sfp_txc(sfp_txc[0]),
        .sfp_rx_clk(sfp_rx_clk[0]),
        .sfp_rx_rst(sfp_rx_rst[0]),
        .sfp_rxd(sfp_rxd[0]),
        .sfp_rxc(sfp_rxc[0]),
        `CONNECT_AXI4S_MIN_IF( m_udphdr_ , udpin_hdr_ ),
        .m_udphdr_tdest( udpin_hdr_tdest ),
        `CONNECT_AXI4S_IF( m_udpdata_ , udpin_data_ ),
        
        `CONNECT_AXI4S_MIN_IF( s_udphdr_ , udpout_hdr_ ),
        .s_udphdr_tuser( udpout_hdr_tuser ),
        `CONNECT_AXI4S_IF( s_udpdata_ , udpout_data_ ));

    // OK! Now we can hook up the UDP port switch, the RDWR/ack/nack/control core and finally the fragment generator.
    // Our inbound ports are
    // 'Tr', 'Tw', 'Ta', 'Tn', 'Tc'
    // 21601 ('Ta') - port 4 - 0x5461 0110 0001
    // 21603 ('Tc') - port 3 - 0x5463 0110 0011
    // 21614 ('Tn') - port 2 - 0x546E 0110 1110
    // 21618 ('Tr') - port 1 - 0x5472 0111 0010
    // 21623 ('Tw') - port 0 - 0x5477 0111 0111
    // We combine the last two by just looking for 0x547(0-7)        

    localparam NUM_INBOUND = 4;
    localparam [NUM_INBOUND*16-1:0]
        INBOUND = { 16'd21601,      // 3
                    16'd21603,      // 2
                    16'd21614,      // 1
                    16'd21618 };    // 0
                 // 16'd21623   is covered in the last match
    localparam [NUM_INBOUND*16-1:0]
        INBOUND_MASK = { 16'd0,                     // exact match
                         16'd0,                     // exact match
                         16'd0,                     // exact match
                         16'b0000_0000_0000_0111 }; // match 21616-21623
    localparam TA_PORT = 3;
    localparam TC_PORT = 2;
    localparam TN_PORT = 1;
    localparam TRW_PORT = 0;
        
    wire [NUM_INBOUND*64-1:0] hdr_tdata;
    wire [NUM_INBOUND-1:0]    hdr_tvalid;
    wire [NUM_INBOUND-1:0]    hdr_tready;
    wire [NUM_INBOUND*16-1:0] hdr_tdest;
        
    wire [NUM_INBOUND*PAYLOAD_WIDTH-1:0] data_tdata;
    wire [NUM_INBOUND-1:0] data_tvalid;
    wire [NUM_INBOUND-1:0] data_tready;
    wire [(PAYLOAD_WIDTH/8)-1:0] data_tkeep;
    wire [NUM_INBOUND-1:0] data_tlast;
    
    wire [NUM_INBOUND-1:0] in_port_active;
    
    localparam NUM_OUTBOUND = 5;
    localparam TE_PORT = 4;
    // we don't actually have to *specify* the outbound port values, but we do
    localparam [NUM_OUTBOUND*16-1:0]
        OUTBOUND = { 16'd21605, // Te port
                     INBOUND };
    localparam TW_PORT_VALUE = 16'd21623;        
        
    wire [NUM_OUTBOUND*64-1:0] hdrout_tdata;
    wire [NUM_OUTBOUND-1:0]    hdrout_tvalid;
    wire [NUM_OUTBOUND-1:0]    hdrout_tready;
    wire [NUM_OUTBOUND*16-1:0]    hdrout_tuser;

    wire [NUM_OUTBOUND*PAYLOAD_WIDTH-1:0]   dataout_tdata;
    wire [NUM_OUTBOUND-1:0]                 dataout_tvalid;
    wire [NUM_OUTBOUND-1:0]                 dataout_tready;
    wire [NUM_OUTBOUND*(PAYLOAD_WIDTH/8)-1:0] dataout_tkeep;
    wire [NUM_OUTBOUND-1:0]                 dataout_tlast;        
    
    udp_port_switch #(.NUM_PORT(NUM_INBOUND),
                      .PORTS( INBOUND ),
                      .PORT_MASK( INBOUND_MASK ),
                      .PAYLOAD_WIDTH(PAYLOAD_WIDTH))
              u_udpin_switch( .aclk(clk156), .aresetn(!clk156_rst),
                              `CONNECT_AXI4S_MIN_IF( s_udphdr_ , udpin_hdr_ ),
                              .s_udphdr_tdest(udpin_hdr_tdest),
                              `CONNECT_AXI4S_IF( s_udpdata_ , udpin_data_ ),
                              
                              .m_udphdr_tdata( hdr_tdata ),
                              .m_udphdr_tvalid(hdr_tvalid),
                              .m_udphdr_tready(hdr_tready),
                              .m_udphdr_tdest( hdr_tdest),
                              
                              .m_udpdata_tdata( data_tdata ),
                              .m_udpdata_tvalid(data_tvalid),
                              .m_udpdata_tready(data_tready),
                              .m_udpdata_tkeep( data_tkeep),
                              .m_udpdata_tlast( data_tlast),
                              
                              .port_active(in_port_active));

    // kill non-implemented ports
    `define KILL_UDP_IN(idx) \
        assign hdr_tready[ idx ] = 1'b1; \
        assign data_tready[ idx ] = 1'b1

    `define KILL_UDP_OUT(idx) \
        assign hdrout_tvalid[ idx ] = 1'b0;                                                           \
        assign hdrout_tdata[64* idx  +: 64] = {64{1'b0}};                                             \
        assign hdrout_tuser[16* idx  +: 16] = OUTBOUND[16* idx  +: 16];                             \
        assign dataout_tvalid[ idx ] = 1'b0;                                                          \
        assign dataout_tdata[PAYLOAD_WIDTH* idx  +: PAYLOAD_WIDTH] = {PAYLOAD_WIDTH{1'b0}};           \
        assign dataout_tkeep[(PAYLOAD_WIDTH/8)* idx  +: (PAYLOAD_WIDTH/8)] = {(PAYLOAD_WIDTH/8){1'b0}};   \
        assign dataout_tlast[ idx ] = 1'b0
    
    `KILL_UDP_IN( TA_PORT );
    `KILL_UDP_IN( TN_PORT );
    `KILL_UDP_IN( TC_PORT ); 
    
    `KILL_UDP_OUT( TA_PORT );
    `KILL_UDP_OUT( TN_PORT );
    `KILL_UDP_OUT( TC_PORT );
    `KILL_UDP_OUT( TE_PORT );
            
    // now try the UDP RDWR core
    wire rdwr_tuser = (hdr_tdest[16*TRW_PORT +: 16] == INBOUND[TRW_PORT*16 +: 16]);
    wire rdwrout_tuser;
    assign hdrout_tuser[16*TRW_PORT +: 16] = (rdwrout_tuser) ? OUTBOUND[TRW_PORT*16 +: 16] : TW_PORT_VALUE;
    turf_udp_rdwr u_rdwr( .aclk(clk156),.aresetn(!clk156_rst),
                          // I REALLY NEED ARRAY MACROS
                          .s_hdr_tdata( hdr_tdata[64*TRW_PORT +: 64]),
                          .s_hdr_tvalid(hdr_tvalid[TRW_PORT]),
                          .s_hdr_tready(hdr_tready[TRW_PORT]),
                          .s_hdr_tuser( rdwr_tuser),
                          .s_payload_tdata( data_tdata[PAYLOAD_WIDTH*TRW_PORT +: PAYLOAD_WIDTH] ),
                          .s_payload_tvalid(data_tvalid[TRW_PORT]),
                          .s_payload_tready(data_tready[TRW_PORT]),
                          .s_payload_tkeep(data_tkeep[(PAYLOAD_WIDTH/8)*TRW_PORT +: (PAYLOAD_WIDTH/8)]),
                          .s_payload_tlast(data_tlast[TRW_PORT]),
                                                    
                          .m_hdr_tdata( hdrout_tdata[64*TRW_PORT +: 64]),
                          .m_hdr_tvalid(hdrout_tvalid[TRW_PORT]),
                          .m_hdr_tready(hdrout_tready[TRW_PORT]),
                          .m_hdr_tuser(rdwrout_tuser),
                          
                          .m_payload_tdata( dataout_tdata[PAYLOAD_WIDTH*TRW_PORT +: PAYLOAD_WIDTH] ),
                          .m_payload_tvalid(dataout_tvalid[TRW_PORT]),
                          .m_payload_tready(dataout_tready[TRW_PORT]),
                          .m_payload_tkeep( dataout_tkeep[(PAYLOAD_WIDTH/8)*TRW_PORT +: (PAYLOAD_WIDTH/8)]),
                          .m_payload_tlast(dataout_tlast[TRW_PORT]),
                          
                          // and the interface
                          .en_o(en_o),
                          .wr_o(wr_o),
                          .adr_o(adr_o),
                          .dat_o(dat_o),
                          .dat_i(dat_i),
                          .ack_i(ack_i));                          

    wire [NUM_OUTBOUND-1:0] out_port_active;
    udp_port_mux #(.NUM_PORT(NUM_OUTBOUND),
                   .PAYLOAD_WIDTH(PAYLOAD_WIDTH))
                   u_udpmux(.aclk(clk156),.aresetn(!clk156_rst),
                            `CONNECT_AXI4S_MIN_IF( s_udphdr_ , hdrout_ ),
                            .s_udphdr_tuser( hdrout_tuser ),
                            `CONNECT_AXI4S_IF( s_udpdata_ , dataout_ ),
                            
                            `CONNECT_AXI4S_MIN_IF( m_udphdr_ , udpout_hdr_ ),
                            .m_udphdr_tuser( udpout_hdr_tuser ),
                            `CONNECT_AXI4S_IF( m_udpdata_ , udpout_data_ ),
                            
                            .port_active(out_port_active));

    udp_ila u_udp_ila( .clk(clk156),
                       .probe0( udpin_hdr_tdest ),
                       .probe1( udpin_hdr_tvalid),
                       .probe2( udpin_data_tdata ),
                       .probe3( udpin_data_tkeep ),
                       .probe4( udpin_data_tvalid ),
                       .probe5( udpin_data_tready ),
                       .probe6( udpin_data_tlast ),
                       .probe7( udpin_hdr_tdata[0 +: 15] ));                      

endmodule