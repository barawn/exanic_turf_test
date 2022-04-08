`timescale 1ns / 1ps
// This module handles the read/write control port.
// We buffer the incoming data so we don't block anything.
// tuser is used to indicate that it's a header word.
// For the header, the 64 bits are
// bits [63:32] = source IP
// bits [31:16] = source port
// bits [15:0]  = length
// and tuser[1] is set.
// tuser[3:2] indicate if the [high:low] 32 bits are valid
// tuser[0] indicates a read port match (when tuser[1] is set)
module turf_udp_rdwr(
        input aclk,
        input aresetn,

        // ports get merged externally
        `TARGET_NAMED_PORTS_AXI4S_MIN_IF( s_hdr_ , 64 ),
        // tuser here indicates a read
        input [0:0] s_hdr_tuser,
        `TARGET_NAMED_PORTS_AXI4S_MIN_IF( s_payload_ , 64),
        input [7:0] s_payload_tkeep,
        input s_payload_tlast,
        
        // now our output. 
        `HOST_NAMED_PORTS_AXI4S_MIN_IF( m_hdr_ , 64 ),
        output [0:0] m_hdr_tuser,
        `HOST_NAMED_PORTS_AXI4S_MIN_IF( m_payload_ , 64),
        output [7:0] m_payload_tkeep,
        output m_payload_tlast,
        
        
        // world's dumbest memory interface
        // note that here I'm working in the aclk domain
        output en_o,
        output wr_o,
        input ack_i,
        output [27:0] adr_o,
        input [31:0] dat_i,
        output [31:0] dat_o
    );
    
    // First we need to combine the headers and payloads.
    wire [3:0] hdr_tuser = { 3'b111, s_hdr_tuser[0] };
    wire [3:0] payload_tuser = { &s_payload_tkeep[7:4], &s_payload_tkeep[3:0], 2'b00 };
        
    reg select_payload = 0;
    always @(posedge aclk) begin
        if (!aresetn || (s_payload_tvalid && s_payload_tready && s_payload_tlast)) select_payload <= 0;
        else if (s_hdr_tvalid && s_hdr_tready) select_payload <= 1;
    end
    
    `DEFINE_AXI4S_MIN_IF( fifo_in_ , 64 );
    wire [3:0] fifo_in_tuser;
    wire fifo_in_tlast;
    
    // the axis_mux basically works by:
    // if a frame is not flowing, the stream output is the one in 'select'
    // once a frame starts flowing, the output will stay the same until tlast.
    // plus there's an enable
    axis_mux #(.S_COUNT(2),
               .DATA_WIDTH(64),
               .KEEP_ENABLE(0),
               .ID_ENABLE(0),
               .DEST_ENABLE(0),
               .USER_ENABLE(1),
               .USER_WIDTH(4))
            u_combine( .clk(aclk), .rst(!aresetn),
                       .s_axis_tdata( { s_payload_tdata, s_hdr_tdata } ),
                       .s_axis_tvalid({ s_payload_tvalid, s_hdr_tvalid } ),
                       .s_axis_tready({ s_payload_tready, s_hdr_tready } ),
                       .s_axis_tuser( { s_payload_tuser, s_hdr_tuser } ),
                       .s_axis_tlast( { s_payload_tlast, s_hdr_tlast } ),
                       `CONNECT_AXI4S_MIN_IF( m_axis_ , fifo_in_ ),
                       .m_axis_tuser( fifo_in_tuser ),
                       .m_axis_tlast( fifo_in_tlast ),
                       .enable(1'b1),
                       .select( select_payload ));
    // now FIFO...
    axis_ccfifo64_tuser4_tlast u_fifo(.s_aclk(aclk),.s_aresetn(aresetn),
                       `CONNECT_AXI4S_MIN_IF( s_axis_ , fifo_in_ ),
                       .s_axis_tuser( fifo_in_tuser ),
                       .s_axis_tlast( fifo_in_tlast ));
    
    // ok, now we state machine the thing
    localparam FSM_BITS=3;
    // waiting for a header (we dump everything non-header in case there's some weird reset $#!+)
    localparam [FSM_BITS-1:0] IDLE = 0;
    // read path, from the low (first) word
    localparam [FSM_BITS-1:0] READ_0 = 1;
    // wait for ack
    localparam [FSM_BITS-1:0] READ_0_ACK = 2;
    // read path, from the high (second) word
    localparam [FSM_BITS-1:0] READ_1 = 3;
    // wait for ack
    localparam [FSM_BITS-1:0] READ_1_ACK = 4;
    // skip state, in case we're repeating
    localparam [FSM_BITS-1:0] READ_SKIP = 5;
    // 
        
endmodule
