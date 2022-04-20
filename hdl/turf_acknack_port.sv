`timescale 1ns / 1ps
`include "interfaces.vh"
// Handles the ack AND nack path!
// This gets sleazed with a mask that deterministically ignores
// portions of the input.
// Then the output (acknack) is remapped as well outside.
// We can do this because the logic's exactly the same.
// Note that bit [62] is ALWAYS ignored because it's the
// OPEN bit in response.
// The top constant in the data response always has both 63 and 62
// set so to check you can just do
// fragment header & checkmask == value returned
module turf_acknack_port #(
        // this is ACK, NACK would be
        // 000000FF_FFFFFFFF
        parameter [63:0] CHECK_BITS = 64'h800000FF_FFF00000
    )(
        input aclk,
        input aresetn,
        input event_open_i,
        `TARGET_NAMED_PORTS_AXI4S_MIN_IF( s_udphdr_ , 64 ),
        `TARGET_NAMED_PORTS_AXI4S_IF( s_udpdata_ , 64 ),
        `HOST_NAMED_PORTS_AXI4S_MIN_IF( m_udphdr_ , 64),
        `HOST_NAMED_PORTS_AXI4S_MIN_IF( m_udpdata_ , 64),
        // generate acks.
        // here tdata[15] is allow, and tdata[0 +: 12] are addr
        // this matches the frame buffer
        `HOST_NAMED_PORTS_AXI4S_MIN_IF( m_acknack_ , 16 )        
    );
    
    // kill bit 62, always ignored (used for OPEN)
    localparam [63:0] MY_CHECK_BITS =
        { CHECK_BITS[63],1'b0,CHECK_BITS[61:0] };
    
    reg [31:0] this_ip = {32{1'b0}};
    reg [15:0] this_port {32{1'b0}};
    // the LENGTH of our reply is always 16.
    wire [15:0] this_length = 16'd16;
        
    reg [63:0] last_store = {64{1'b0}};
    reg last_valid = 0;
    
    localparam FSM_BITS=3;
    localparam [FSM_BITS-1:0] IDLE = 0;
    localparam [FSM_BITS-1:0] CHECK_DATA_0 = 1;
    localparam [FSM_BITS-1:0] WRITE_DATA = 2;
    localparam [FSM_BITS-1:0] READ_DATA_N = 3;
    localparam [FSM_BITS-1:0] READ_SKIP = 4;
    localparam [FSM_BITS-1:0] DUMP = 5;
    localparam [FSM_BITS-1:0] WRITE_RESPONSE = 6;
    reg [FSM_BITS-1:0] state = IDLE;
    
    always @(posedge aclk) begin    
        if (!aresetn || !event_open_i) last_valid <= 0;
        else if (state == WRITE_DATA && s_udpdata_tvalid && s_udpdata_tready) last_valid <= 1;
    
        if (state == WRITE_DATA && s_udpdata_tvalid && s_udpdata_tready) begin
            last_store <= s_udpdata_tdata & MY_CHECK_BITS;
        end
    
        if (s_udphdr_tready && s_udphdr_tvalid) begin
            this_ip <= s_udphdr_tdata[32 +: 32];
            this_port <= s_udphdr_tdata[16 +: 16];
        end
        
        always @(posedge aclk) begin
            if (!aresetn) state <= IDLE;
            else begin
                case (state)
                    // s_udphdr_tready is always 1 here
                    IDLE: if (s_udphdr_tvalid && s_udphdr_tready) state <= CHECK_DATA_0;
                    // DUMP is EXCLUSIVELY for when we receive less than 8 bytes and DON'T respond
                    // s_udpdata_tready is always 0 here
                    CHECK_DATA_0: if (s_udpdata_tvalid) begin
                        if (s_udpdata_tkeep != 8'hFF) state <= DUMP;
                        else if (last_valid) begin
                            // this should optimize away
                            if (s_udpdata_tdata & MY_CHECK_BITS == last_store) state <= READ_SKIP;
                            else state <= WRITE_DATA;
                        end else state <= WRITE_DATA;
                    end
                    // s_udpdata_tready is m_acknack_tready here
                    WRITE_DATA: 
                        if (m_acknack_tready) begin
                            // single valid ack
                            if (s_udpdata_tlast) state <= WRITE_RESPONSE;
                            // more than 1
                            else state <= READ_DATA_N;
                        end
                    // s_udpdata_tready is always 0 here
                    READ_DATA_N:
                        if (s_udpdata_tvalid) begin
                            if (s_udpdata_tkeep != 8'hFF) state <= READ_SKIP;
                            else state <= WRITE_DATA;
                        end
                    // s_udpdata_tready is always 1 here
                    READ_SKIP:
                        if (s_udpdata_tvalid && s_udpdata_tlast) state <= WRITE_RESPONSE;
                    // no response, we didn't get anything valid
                    DUMP:
                        if (s_udpdata_tvalid && s_udpdata_tlast) state <= IDLE;
                    
endmodule
