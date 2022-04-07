`timescale 1ns / 1ps
`include "interfaces.vh"
module turf_fragment_gen(
        input aclk,
        input aresetn,
        // Payload uint64_ts in a fragment, minus 1.
        input [9:0] nfragment_count_i,
        
        // control interface
        `TARGET_NAMED_PORTS_AXI4S_MIN_IF( s_ctrl_ , 32 ),
        // data interface
        `TARGET_NAMED_PORTS_AXI4S_MIN_IF( s_data_ , 64 ),
        input [7:0] s_data_tkeep,
        input       s_data_tlast,
        
        // UDP header interface, without the global statics
        // (dscp/ecn/ttl/source port/source ip/dest ip/dest port)
        // Checksum is pointless, Ethernet does a CRC, so it's static
        // So tdata here is just length
        `HOST_NAMED_PORTS_AXI4S_MIN_IF( m_hdr_ , 16),
        // UDP payload interface, I don't know what tuser does
        `HOST_NAMED_PORTS_AXI4S_MIN_IF( m_payload_ , 64 ),
        output [7:0] m_payload_tkeep,
        output       m_payload_tuser,
        output       m_payload_tlast                
    );

    // this constant needs its top bit set
    localparam [15:0] CONSTANT_0 = 16'hDA7A;
    localparam [5:0] CONSTANT_1 = 6'h00;

    // This takes an AXI-Stream input and splits it into UDP fragments.
    // States are IDLE, HEADER, TAG, and STREAM
    // We receive an AXI4-Stream for the event generation which consists
    // of the address + length (status output of the S2MM data mover
    // after going through control logic).
    // This is functionally 32-bit (and generates our header).

    localparam FSM_BITS = 2;
    localparam [FSM_BITS-1:0] IDLE = 0;
    localparam [FSM_BITS-1:0] HEADER = 1;
    localparam [FSM_BITS-1:0] TAG = 2;
    localparam [FSM_BITS-1:0] STREAM = 3;
    reg [FSM_BITS-1:0] state = IDLE;
    
    reg [9:0] fragment_beats = {10{1'b0}};
    reg [9:0] fragment_number = {10{1'b0}};
    reg [11:0] address = {12{1'b0}};
    reg [19:0] length = {20{1'b0}};
    reg [19:0] remaining_length = {20{1'b0}};
    reg [15:0] fragment_length = {16{1'b0}};

    wire [19:0] current_length_remaining = (state == IDLE) ? 
        s_ctrl_tdata[0 +: 20] : remaining_length;

    wire [63:0] tag = { CONSTANT_0, CONSTANT_1, fragment_number, address, length };

    always @(posedge aclk) begin
        if (!aresetn) state <= IDLE;
        else begin
            case (state)
                IDLE: if (s_ctrl_tvalid && s_ctrl_tready) state <= HEADER;
                HEADER: if (m_hdr_tvalid && m_hdr_tready) state <= TAG;
                TAG: if (m_payload_tvalid && m_payload_tready) state <= STREAM;
                STREAM: if (m_payload_tvalid && m_payload_tready) begin
                    if (m_payload_tlast) state <= IDLE;
                    else if (fragment_beats == nfragment_count_i) state <= HEADER;
                end
            endcase
        end
        
        // Calculate the fragment length.
        // We have to do this for the first fragment and then after each new fragment
        if ((state == IDLE && s_ctrl_tvalid && s_ctrl_tready)|| 
            (state == TAG && m_payload_tvalid && m_payload_tready)) begin
            // fits in a single fragment
            if (current_length_remaining < {nfragment_count_i,3'b000}) begin
                // nfragment_count_i is 10 bits, so we only need to grab
                // 13 bits here and add 8.
                fragment_length <= current_length_remaining[0 +: 13] + 8;
            end
        end
        // Calculate the remaining length
        if (state == IDLE && s_ctrl_tvalid && s_ctrl_tready)
           remaining_length <= s_ctrl_tdata[0 +: 20];
        else if (state == HEADER && m_hdr_tvalid && m_hdr_tready)
            remaining_length <= remaining_length - (fragment_length - 8);
        
        if (state == HEADER) fragment_beats <= {10{1'b0}};
        else if (state == STREAM && m_payload_tvalid && m_payload_tready)
            fragment_beats <= fragment_beats + 1;
        
        if (state == IDLE && s_ctrl_tvalid && s_ctrl_tready) begin
            address <= s_ctrl_tdata[20 +: 12];
            length <= s_ctrl_tdata[0 +: 20];
        end
        
        if (state == IDLE) fragment_number <= {10{1'b0}};
        else if (state == TAG && m_payload_tvalid && m_payload_tready) 
            fragment_number <= fragment_number + 1;                            
     end

    assign m_hdr_tvalid = (state == HEADER);
    assign m_payload_tvalid = (state == TAG || (state == STREAM && s_data_tvalid));
    assign s_data_tready = (state == STREAM && m_payload_tready);
    assign s_ctrl_tready = (state == IDLE);
    assign m_hdr_tdata = fragment_length;
    assign m_payload_tdata = (state == TAG) ? tag : s_data_tdata;
endmodule
