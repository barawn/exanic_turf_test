`timescale 1ns / 1ps
`include "interfaces.vh"

import axi4stream_vip_pkg::*;
import m_udpdata_vip_pkg::*;
import m_udphdr_vip_pkg::*;

// testbench for TURF UDP readwrite
module turf_udp_rdwr_tb;

    reg aresetn=1;
    wire aclk;
    tb_rclk #(.PERIOD(10.0)) u_aclk(.clk(aclk));
    
    `DEFINE_AXI4S_MIN_IF( hdr_ , 64);
    wire [0:0] hdr_tuser;
    `DEFINE_AXI4S_MIN_IF( data_ , 64);
    wire [7:0] data_tkeep;
    wire data_tlast;
    
    `DEFINE_AXI4S_MIN_IF( hdrout_ , 64 );
    wire [0:0] hdrout_tuser;
    assign hdrout_tready = 1'b1;
    `DEFINE_AXI4S_MIN_IF( dataout_ , 64 );
    wire [7:0] dataout_tkeep;
    wire dataout_tlast;
    assign dataout_tready = 1'b1;
    
    wire en;
    wire wr;
    wire ack = en;
    wire [27:0] adr;
    wire [31:0] dat_out;
    wire [31:0] dat_in = 32'h12345678;
    
    m_udphdr_vip hdr_vip(.aclk(aclk),.aresetn(aresetn),
                         `CONNECT_AXI4S_MIN_IF( m_axis_ , hdr_ ),
                         .m_axis_tuser(hdr_tuser));
    m_udpdata_vip data_vip(.aclk(aclk),.aresetn(aresetn),
                           `CONNECT_AXI4S_MIN_IF( m_axis_ , data_ ),
                           .m_axis_tkeep( data_tkeep ),
                           .m_axis_tlast( data_tlast ));

    m_udphdr_vip_mst_t hdr_agent;
    m_udpdata_vip_mst_t data_agent;
    
    turf_udp_rdwr u_rdwr( .aclk(aclk),.aresetn(aresetn),
                            `CONNECT_AXI4S_MIN_IF( s_hdr_ , hdr_ ),
                            .s_hdr_tuser( hdr_tuser ),
                            `CONNECT_AXI4S_MIN_IF( s_payload_ , data_ ),
                            .s_payload_tkeep( data_tkeep ),
                            .s_payload_tlast( data_tlast ),
                            `CONNECT_AXI4S_MIN_IF( m_hdr_ , hdrout_ ),
                            .m_hdr_tuser( hdrout_tuser ),
                            `CONNECT_AXI4S_MIN_IF( m_payload_ , dataout_ ),
                            .m_payload_tkeep( dataout_tkeep ),
                            .m_payload_tlast( dataout_tlast ),
                            
                            .en_o(en),
                            .wr_o(wr),
                            .ack_i(ack),
                            .adr_o(adr),
                            .dat_o(dat_out),
                            .dat_i(dat_in));

    wire [31:0] source_ip;
    assign source_ip[0 +: 8] = 8'd1;
    assign source_ip[8 +: 8] = 8'd1;
    assign source_ip[16 +: 8] = 8'd168;
    assign source_ip[24 +: 8] = 8'd192;
    
    wire [15:0] source_port = 16'd20000;
    
    task write_single;
        input [3:0] tag;
        input [27:0] addr;
        input [31:0] data;
        axi4stream_transaction hdr_txn;
        axi4stream_transaction data_txn;
        reg [7:0] hdr_data[7:0];
        reg [7:0] data_data[7:0];
        reg [7:0] data_tkeep;
        integer i, j;
        begin
            // this is a single write, so length is just 8
            hdr_txn = hdr_agent.driver.create_transaction("hdr_write");
            hdr_txn.set_delay(0);
            hdr_data[7] = 8'd8;
            hdr_data[6] = 8'd0;
            hdr_data[5] = source_port[0 +: 8];
            hdr_data[4] = source_port[8 +: 8];
            hdr_data[3] = source_ip[0 +: 8];
            hdr_data[2] = source_ip[8 +: 8];
            hdr_data[1] = source_ip[16 +: 8];
            hdr_data[0] = source_ip[24 +: 8];
            hdr_txn.set_data(hdr_data);
            hdr_txn.set_user_beat( 1'b0 );
            hdr_agent.driver.send( hdr_txn );
            data_txn = data_agent.driver.create_transaction("data_write");
            data_txn.set_delay(0);
            // ICD v0.3, addr/tag comes first
            data_data[3] = data[0 +: 8];
            data_data[2] = data[8 +: 8];
            data_data[1] = data[16 +: 8];
            data_data[0] = data[24 +: 8];
            data_data[7] = addr[0 +: 8];
            data_data[6] = addr[8 +: 8];
            data_data[5] = addr[16 +: 8];
            data_data[4] = { tag, addr[24 +: 4] };
            data_txn.set_data(data_data);
            data_txn.set_last(1'b1);
            data_txn.set_keep_beat( 8'hFF );
            data_agent.driver.send(data_txn);
        end
    endtask

    task read_single;
        input [3:0] tag;
        input [27:0] addr;
        axi4stream_transaction hdr_txn;
        axi4stream_transaction data_txn;
        reg [7:0] hdr_data[7:0];
        reg [7:0] data_data[7:0];
        reg [7:0] data_tkeep;
        integer i, j;
        begin
            // this is a single read, so length is just 4
            hdr_txn = hdr_agent.driver.create_transaction("hdr_write");
            hdr_txn.set_delay(0);
            hdr_data[7] = 8'd4;
            hdr_data[6] = 8'd0;
            hdr_data[5] = source_port[0 +: 8];
            hdr_data[4] = source_port[8 +: 8];
            hdr_data[3] = source_ip[0 +: 8];
            hdr_data[2] = source_ip[8 +: 8];
            hdr_data[1] = source_ip[16 +: 8];
            hdr_data[0] = source_ip[24 +: 8];
            hdr_txn.set_data(hdr_data);
            hdr_txn.set_user_beat( 1'b1 );
            hdr_agent.driver.send( hdr_txn );
            data_txn = data_agent.driver.create_transaction("data_write");
            data_txn.set_delay(0);
            data_data[7] = addr[0 +: 8];
            data_data[6] = addr[8 +: 8];
            data_data[5] = addr[16 +: 8];
            data_data[4] = { tag, addr[24 +: 4] };
            data_data[3] = 8'd0;
            data_data[2] = 8'd0;
            data_data[1] = 8'd0;
            data_data[0] = 8'd0;
            data_txn.set_data(data_data);
            data_txn.set_last(1'b1);
            data_txn.set_keep_beat( 8'h0F );
            data_agent.driver.send(data_txn);
        end
    endtask

    // read 2 at a time
    task read_double;
        input [3:0] tag;
        input [27:0] addr;
        input [27:0] addr2;
        axi4stream_transaction hdr_txn;
        axi4stream_transaction data_txn;
        reg [7:0] hdr_data[7:0];
        reg [7:0] data_data[7:0];
        reg [7:0] data_tkeep;
        integer i, j;
        begin
            // this is a single read, so length is just 4
            hdr_txn = hdr_agent.driver.create_transaction("hdr_write");
            hdr_txn.set_delay(0);
            hdr_data[7] = 8'd8;
            hdr_data[6] = 8'd0;
            hdr_data[5] = source_port[0 +: 8];
            hdr_data[4] = source_port[8 +: 8];
            hdr_data[3] = source_ip[0 +: 8];
            hdr_data[2] = source_ip[8 +: 8];
            hdr_data[1] = source_ip[16 +: 8];
            hdr_data[0] = source_ip[24 +: 8];
            hdr_txn.set_data(hdr_data);
            hdr_txn.set_user_beat( 1'b1 );
            hdr_agent.driver.send( hdr_txn );
            data_txn = data_agent.driver.create_transaction("data_write");
            data_txn.set_delay(0);
            data_data[7] = addr[0 +: 8];
            data_data[6] = addr[8 +: 8];
            data_data[5] = addr[16 +: 8];
            data_data[4] = { tag, addr[24 +: 4] };
            data_data[3] = addr2[0 +: 8];
            data_data[2] = addr2[8 +: 8];
            data_data[1] = addr2[16 +: 8];
            data_data[0] = { tag, addr2[24 +: 4] };
            data_txn.set_data(data_data);
            data_txn.set_last(1'b1);
            data_txn.set_keep_beat( 8'hFF );
            data_agent.driver.send(data_txn);
        end
    endtask

    // read 2 at a time but include an extra byte
    task read_double_broken;
        input [3:0] tag;
        input [27:0] addr;
        input [27:0] addr2;
        axi4stream_transaction hdr_txn;
        axi4stream_transaction data_txn;
        reg [7:0] hdr_data[7:0];
        reg [7:0] data_data[7:0];
        reg [7:0] data_tkeep;
        integer i, j;
        begin
            // this is a single read, so length is just 4
            hdr_txn = hdr_agent.driver.create_transaction("hdr_write");
            hdr_txn.set_delay(0);
            hdr_data[7] = 8'd9;
            hdr_data[6] = 8'd0;
            hdr_data[5] = source_port[0 +: 8];
            hdr_data[4] = source_port[8 +: 8];
            hdr_data[3] = source_ip[0 +: 8];
            hdr_data[2] = source_ip[8 +: 8];
            hdr_data[1] = source_ip[16 +: 8];
            hdr_data[0] = source_ip[24 +: 8];
            hdr_txn.set_data(hdr_data);
            hdr_txn.set_user_beat( 1'b1 );
            hdr_agent.driver.send( hdr_txn );
            data_txn = data_agent.driver.create_transaction("data_write");
            data_txn.set_delay(0);
            data_data[7] = addr[0 +: 8];
            data_data[6] = addr[8 +: 8];
            data_data[5] = addr[16 +: 8];
            data_data[4] = { tag, addr[24 +: 4] };
            data_data[3] = addr2[0 +: 8];
            data_data[2] = addr2[8 +: 8];
            data_data[1] = addr2[16 +: 8];
            data_data[0] = { tag, addr2[24 +: 4] };
            data_txn.set_data(data_data);
            data_txn.set_last(1'b0);
            data_txn.set_keep_beat( 8'hFF );
            data_agent.driver.send(data_txn);
            data_data[7] = 8'hba;
            data_txn.set_data(data_data);
            data_txn.set_keep_beat( 8'h01 );
            data_txn.set_last(1'b1);
            data_agent.driver.send(data_txn);
        end
    endtask

    
    initial begin
        hdr_agent = new("hdr vip agent", hdr_vip.inst.IF);
        data_agent = new("data vip agent", data_vip.inst.IF);
        hdr_agent.start_master();
        data_agent.start_master();
        #100;
        aresetn = 0;
        #200;
        aresetn = 1;
        @(posedge aclk);
        write_single( 0, 28'habbccdd, 32'h12345678 );
        read_single( 1, 28'd0 );
        read_double( 2, 28'd0, 28'd1 );
        read_double_broken(3, 28'd2, 28'd3);
        
    end
    
    
endmodule
