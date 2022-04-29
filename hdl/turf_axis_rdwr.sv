`timescale 1ns / 1ps
`include "interfaces.vh"
// This is a very simple stream interface to the generic rdwr interface.
// This is *similar* but not identical to the TURF UDP RDWR interface.
// The main difference is that the top tag bit is used as a read/write
// select, and there's no "skip" protection since stuff can't be lost.
// So the tags are basically ignored (but echoed)
module turf_axis_rdwr(
        input aclk,
        input aresetn,
        `TARGET_NAMED_PORTS_AXI4S_MIN_IF( s_axis_ , 32 ),
        `HOST_NAMED_PORTS_AXI4S_MIN_IF( m_axis_ , 32 ),
        output en_o,
        output wr_o,
        input ack_i,
        output [27:0] adr_o,
        input [31:0] dat_i,
        output [31:0] dat_o
    );
    
    localparam FSM_BITS = 3;
    localparam [FSM_BITS-1:0] IDLE = 0;
    localparam [FSM_BITS-1:0] READ_RESPOND_0 = 1;
    localparam [FSM_BITS-1:0] READ_ACK = 2;
    localparam [FSM_BITS-1:0] READ_RESPOND_1 = 3;
    localparam [FSM_BITS-1:0] WRITE_GET_DATA = 4;
    localparam [FSM_BITS-1:0] WRITE_ACK = 5;
    localparam [FSM_BITS-1:0] WRITE_RESPOND = 6;
    reg [FSM_BITS-1:0] state = IDLE;
    
    wire [3:0] tag_in = s_axis_tdata[28 +: 4];
    wire [27:0] adr_in = s_axis_tdata[0 +: 28];
    // storage
    reg [31:0] reg_store = {32{1'b0}};   
    
    always @(posedge aclk) begin
        if (!aresetn) state <= IDLE;
        else begin
            case (state)
                IDLE: if (s_axis_tvalid) begin
                    if (tag_in[3]) state <= READ_RESPOND_0;
                    else state <= WRITE_GET_DATA;
                end
                // write out the address/tag for the response **first**
                // this saves us from needing another 32-bit register
                READ_RESPOND_0: if (m_axis_tready) state <= READ_ACK;
                READ_ACK: if (ack_i) state <= READ_RESPOND_1;
                READ_RESPOND_1: if (m_axis_tready) state <= IDLE;
                WRITE_GET_DATA: state <= WRITE_ACK;
                WRITE_ACK: if (ack_i) state <= WRITE_RESPOND;
                WRITE_RESPOND: if (m_axis_tready) state <= IDLE;
            endcase
        end
        if (state == IDLE && s_axis_tvalid) reg_store <= s_axis_tdata;
        else if (state == READ_ACK && ack_i) reg_store <= dat_i;
    end
    
    assign s_axis_tready = ( ack_i && (state == READ_ACK || state == WRITE_ACK) ) ||
                            (state == WRITE_GET_DATA);
    assign m_axis_tvalid = (state == READ_RESPOND_0 || state == READ_RESPOND_1 || state == WRITE_RESPOND);
    assign m_axis_tdata = reg_store;

    assign en_o = (state == READ_ACK || (state == WRITE_ACK && s_axis_tvalid));
    assign adr_o = reg_store[0 +: 28];
    assign dat_o = s_axis_tdata;
    assign wr_o = (state == WRITE_ACK);
        
endmodule
