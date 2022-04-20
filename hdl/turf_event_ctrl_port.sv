`timescale 1ns / 1ps
`include "interfaces.vh"
// TURF event control UDP port.
// This port is stateful so we don't buffer anything.
// We also ONLY respond to the FIRST command. Period. Anything else in the packet
// gets ignored.
module turf_event_ctrl_port #(
        // our MAC address (for ID command)
        parameter [47:0] MY_MAC_ADDRESS = 48'h0200_0000_0000,
        // maximum value for the fragment length
        parameter MAX_FRAGMENT_LEN=8095,
        // maximum address value
        parameter MAX_ADDR = 4095
        )
        (
        input aclk,
        input aresetn,
        // IP/port/length
        `TARGET_NAMED_PORTS_AXI4S_MIN_IF( s_udphdr_ , 64),
        `TARGET_NAMED_PORTS_AXI4S_IF( s_udpdata_ , 64),
        // IP/port/length
        `HOST_NAMED_PORTS_AXI4S_MIN_IF( m_udphdr_ , 64),
        `HOST_NAMED_PORTS_AXI4S_IF( m_udpdata_ , 64 ),
        // Fragment length (in uint64_t's)
        output [9:0] nfragment_count_o,
        output [31:0] event_ip_o,
        output [15:0] event_port_o,
        output        event_open_o
    );
    
    localparam NUM_CMDS = 5;
    localparam [16*NUM_CMDS-1:0] CMD_TABLE =
        { "PW",
          "PR",
          "ID",
          "CL",
          "OP" };
    wire [NUM_CMDS-1:0] cmd_match;
    generate
        genvar i;
        for (i=0;i<NUM_CMDS;i=i+1) begin : MATCHGEN
            assign cmd_match[i] = (s_udpdata_tdata[15:0] == CMD_TABLE[16*i +: 16]);
        end
    endgenerate
    
    reg [31:0] dest_ip = {32{1'b0}};
    reg [15:0] dest_port = {16{1'b0}};
    
    reg [31:0] event_ip = {32{1'b0}};
    reg [15:0] event_port = {16{1'b0}};
    reg event_is_open = 0;
    
    reg [63:0] response = {64{1'b0}};
            
    // default is 1024 bytes, which is 128, which we write as 127.
    reg [9:0] nfragment = 10'd127;
    
    localparam FSM_BITS=3;
    localparam [FSM_BITS-1:0] IDLE = 0;
    localparam [FSM_BITS-1:0] READ_COMMAND = 1;
    localparam [FSM_BITS-1:0] WRITE_HEADER = 2;
    localparam [FSM_BITS-1:0] WRITE_PAYLOAD = 3;
    localparam [FSM_BITS-1:0] DUMP = 4;
    reg [FSM_BITS-1:0] state = IDLE;
    
    always @(posedge aclk) begin
        if (!aresetn) state <= IDLE;
        else begin
            case (state)
                IDLE: if (s_udphdr_tvalid) state <= READ_COMMAND;
                READ_COMMAND: if (s_udpdata_tvalid) begin
                    if (s_udpdata_tkeep == 8'hFF && cmd_match != {NUM_CMDS{1'b0}})
                        state <= WRITE_HEADER;
                    else state <= DUMP;
                end
                WRITE_HEADER: if (m_udphdr_tready) state <= WRITE_PAYLOAD;
                WRITE_PAYLOAD: if (m_udpdata_tready) state <= DUMP;
                DUMP: if (s_udpdata_tvalid && s_udpdata_tlast) state <= IDLE;
            endcase
        end
    end
    
    assign s_udphdr_tready = (state == IDLE);
    assign s_udpdata_tready = (state == DUMP);
    assign m_udphdr_tvalid = (state == WRITE_HEADER);
    assign m_udpdata_tvalid = (state == WRITE_PAYLOAD);
    
endmodule
