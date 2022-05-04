`timescale 1ns / 1ps
// 2-port arbiter to the TURF generic interface
// super generic arbiter
module turf_generic_arb( input clk,
                         input rst,
                         input [1:0] s_en_i,
                         input [1:0] s_wr_i,
                         output [1:0] s_ack_o,
                         input [55:0] s_adr_i,
                         input [63:0] s_dat_i,
                         output [63:0] s_dat_o,
                         
                         output m_en_o,
                         output m_wr_o,
                         input m_ack_i,
                         output [27:0] m_adr_o,
                         input [31:0] m_dat_i,
                         output [31:0] m_dat_o
    );
    wire grant_valid;
    wire [1:0] grant;
    assign s_ack_o = {2{m_ack_i}} & grant & {2{grant_valid}};
    wire grant_encoded;
    arbiter #(.PORTS(2), .ARB_TYPE_ROUND_ROBIN(1),.ARB_BLOCK(1),.ARB_BLOCK_ACK(1))
        u_arbiter( .clk(clk),.rst(rst),
                   .request( s_en_i ),                   
                   .acknowledge( s_ack_o ),
                   .grant( grant ),
                   .grant_valid(grant_valid),
                   .grant_encoded(grant_encoded));
    assign m_en_o = s_en_i[grant_encoded] & grant_valid;
    assign m_wr_o = s_wr_i[grant_encoded];
    assign m_adr_o = (grant_encoded) ?
                        s_adr_i[28 +: 28] :
                        s_adr_i[0 +: 28];
    assign m_dat_o = (grant_encoded) ?
                        s_dat_i[32 +: 32] :
                        s_dat_i[0 +: 32];
endmodule
