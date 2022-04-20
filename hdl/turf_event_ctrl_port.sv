`timescale 1ns / 1ps
`include "interfaces.vh"
// TURF event control UDP port.
// This port is stateful so we don't buffer anything.
// We also ONLY respond to the FIRST command. Period. Anything else in the packet
// gets ignored.
module turf_event_ctrl_port #(
        // maximum value for the fragment length
        parameter MAX_FRAGMENT_LEN=8095,
        // maximum address value
        parameter MAX_ADDR = 4095,
        // holdoff in clock cycles
        parameter [4:0] HOLDOFF_DELAY = 31
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
        input [47:0] my_mac_address,
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
    localparam [NUM_CMDS-1:0] needs_holdoff =
        { 1'b0,
          1'b0,
          1'b0,
          1'b1,
          1'b1 };
    wire [NUM_CMDS-1:0] cmd_match;
    // need to automate this bull somehow
    localparam OP_CMD = 0;
    localparam CL_CMD = 1;
    localparam ID_CMD = 2;
    localparam PR_CMD = 3;
    localparam PW_CMD = 4;

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
    wire [15:0] nfragment_as_bytes = { 3'b000, nfragment, 3'b000 };
    
    // dumbass holdoff
    reg cur_val = 0;
    wire delay_val;
    SRLC32E u_delayline(.D(cur_val),
                        .A(HOLDOFF_DELAY),
                        .CE(1'b1),
                        .CLK(aclk),
                        .Q(delay_val));
    wire holdoff_done = (delay_val == cur_val);                        
    
    localparam FSM_BITS=4;
    localparam [FSM_BITS-1:0] IDLE = 0;
    localparam [FSM_BITS-1:0] READ_COMMAND = 1;
    localparam [FSM_BITS-1:0] PARSE_COMMAND = 2;
    localparam [FSM_BITS-1:0] HOLDOFF = 3;
    localparam [FSM_BITS-1:0] UPDATE_RESPONSE = 4;
    localparam [FSM_BITS-1:0] WRITE_HEADER = 5;
    localparam [FSM_BITS-1:0] WRITE_PAYLOAD = 6;
    localparam [FSM_BITS-1:0] DUMP = 6;
    reg [FSM_BITS-1:0] state = IDLE;
            
    always @(posedge aclk) begin
        if (state == UPDATE_RESPONSE) begin
            if (cmd_match[OP_CMD] || cmd_match[CL_CMD])
                response <= s_udpdata_tdata;
            else if (cmd_match[ID_CMD])
                response <= { s_udpdata_tdata[48 +: 16], my_mac_address };
            else if (cmd_match[PR_CMD] || cmd_match[PW_CMD])
                response <= { s_udpdata_tdata[48 +: 16], MAX_FRAGMENT_LEN, MAX_ADDR, nfragment_as_bytes };
        end
        
        if (state == PARSE_COMMAND) begin
            if (cmd_match[OP_CMD]) begin
                event_is_open <= 1'b1;
                event_ip <= s_udpdata_tdata[16 +: 32];
                event_port <= s_udpdata_tdata[0 +: 16];
            end else if (cmd_match[CL_CMD])
                event_is_open <= 1'b0;
            if (cmd_match[PW_CMD])
                if (s_udpdata_tdata[0 +: 15] <= MAX_FRAGMENT_LEN) nfragment <= s_udpdata_tdata[ 3+: 10];
        end
    
        // toggle if we need to wait.
        if (state == PARSE_COMMAND && (|(cmd_match & needs_holdoff))) cur_val <= ~cur_val;    
        if (!aresetn) state <= IDLE;
        else begin
            case (state)
                IDLE: if (s_udphdr_tvalid) state <= READ_COMMAND;
                READ_COMMAND: if (s_udpdata_tvalid) begin
                    if (s_udpdata_tkeep == 8'hFF && cmd_match != {NUM_CMDS{1'b0}}) begin
                        state <= PARSE_COMMAND;                        
                    end else state <= DUMP;
                end
                PARSE_COMMAND:
                    if (|(cmd_match & needs_holdoff)) state <= UPDATE_RESPONSE; 
                    else state <= WRITE_HEADER;
                HOLDOFF: if (holdoff_done) state <= UPDATE_RESPONSE;
                UPDATE_RESPONSE: state <= WRITE_HEADER;
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

    assign nfragment_count_o = nfragment;
    assign event_ip_o = event_ip;
    assign event_port_o = event_port;
    assign event_open_o = event_is_open;
    
endmodule
