`timescale 1ns / 1ps
`include "interfaces.vh"

import axi4stream_vip_pkg::*;
import m_ev_ctrl_vip_pkg::*;
import m_ev_data_vip_pkg::*;

module turf_fragment_gen_tb(

    );

    reg aresetn = 1;
    wire aclk;
    tb_rclk #(.PERIOD(10.0)) u_aclk(.clk(aclk));

    `DEFINE_AXI4S_MIN_IF( ctrl_ , 32 );
    `DEFINE_AXI4S_MIN_IF( data_ , 64 );
    wire [7:0] data_tkeep;
    wire data_tlast;
    
    `DEFINE_AXI4S_MIN_IF( hdr_ , 16 );
    assign hdr_tready = 1'b1;
    `DEFINE_AXI4S_MIN_IF( payload_ , 64 );
    assign payload_tready = 1'b1;
    wire [7:0] payload_tkeep;
    wire payload_tlast;
    // screw tuser

    m_ev_ctrl_vip ctrl_vip( .aclk(aclk),
                                 .aresetn(aresetn),
                                 `CONNECT_AXI4S_MIN_IF( m_axis_ , ctrl_ ));
    m_ev_data_vip data_vip( .aclk(aclk),
                              .aresetn(aresetn),
                              `CONNECT_AXI4S_MIN_IF( m_axis_ , data_ ),
                              .m_axis_tkeep(data_tkeep),
                              .m_axis_tlast(data_tlast));                                                                  
    
    // I dunno, set it to something small. 
    // Each fragment should be 152 bytes long with 144 payload bytes.
    turf_fragment_gen u_generator( .aclk(aclk),.aresetn(aresetn),
            .nfragment_count_i( 17 ),
            `CONNECT_AXI4S_MIN_IF( s_ctrl_ , ctrl_ ),
            `CONNECT_AXI4S_MIN_IF( s_data_ , data_ ),
            .s_data_tkeep(data_tkeep),
            .s_data_tlast(data_tlast),
            
            `CONNECT_AXI4S_MIN_IF( m_hdr_ , hdr_ ),
            `CONNECT_AXI4S_MIN_IF( m_payload_ , payload_ ),
            
            .m_payload_tkeep(payload_tkeep),
            .m_payload_tlast(payload_tlast));
    
    m_ev_ctrl_vip_mst_t ctrl_agent;
    m_ev_data_vip_mst_t data_agent;

    // I both simultaneously love and hate the VIPs.
    task write_event;
        input [11:0] addr;
        input [19:0] length;
        axi4stream_transaction ctrl_txn;
        axi4stream_transaction data_txn;
        reg [7:0] ctrl_data[3:0];
        reg [7:0] event_data[7:0];
        reg [7:0] event_keep;
        integer i,j;
        begin
            // pass addr/length to control
            // then feed length total bytes to data
            ctrl_txn = ctrl_agent.driver.create_transaction("ctrl_write");
            ctrl_txn.set_delay(0);
            // Goddamn VIP orders stuff big-endian, sigh.
            ctrl_data[3] = length[7:0];
            ctrl_data[2] = length[15:8];
            ctrl_data[1] = { addr[3:0], length[19:16] };
            ctrl_data[0] = addr[11:4];
            ctrl_txn.set_data(ctrl_data);
            ctrl_agent.driver.send(ctrl_txn);
            data_txn = data_agent.driver.create_transaction("data_write");
            data_txn.set_delay(0);
            // we send 8 bytes per beat
            for (i=0;i<length;i=i+8) begin
                for (j=0;j<8;j=j+1) begin
                    if (i+j < length) begin
                        event_keep[7-j] = 1'b1;
                        event_data[7-j] = $urandom_range(0, 255);
                    end else begin
                        event_keep[7-j] = 1'b0;
                        event_data[7-j] = 8'h00;
                    end
                end
                // check to see last beat
                // if this passes we will loop again
                if (i+8 < length) begin
                    data_txn.set_last(1'b0);
                // otherwise we will not
                end else begin
                    data_txn.set_last(1'b1);
                end
                data_txn.set_data(event_data);
                // I don't know what you're supposed to pass
                // to set_keep, but set_keep_beat works
                data_txn.set_keep_beat(event_keep);
                data_agent.driver.send(data_txn);
            end
        end
    endtask

    initial begin
        ctrl_agent = new("ctrl vip agent", ctrl_vip.inst.IF);
        data_agent = new("data vip agent", data_vip.inst.IF);
        ctrl_agent.start_master();
        data_agent.start_master();
        #100;
        aresetn = 0;
        #200;
        aresetn = 1;
        @(posedge aclk);
        write_event( 0, 1000 );
    end
        
endmodule
