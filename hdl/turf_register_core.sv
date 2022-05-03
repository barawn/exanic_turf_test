`timescale 1ns / 1ps
// beginnings of a register space for the TURF (and access points for the other outputs)
module turf_register_core(
        input clk,
        input rst,
        
        input en_i,
        input wr_i,
        output ack_o,
        input [27:0] adr_i,
        input [31:0] dat_i,
        output [31:0] dat_o,
        
        output [31:0] ctrl_o,
        input [31:0] stat_i
        
    );

    // We'll do address space partitioning later.
    // For that we want brains, I think.
    parameter [31:0] IDENT = {32{1'b0}};
    parameter [31:0] DATEVERSION = {32{1'b0}};;

    reg [31:0] ctrl_reg = {32{1'b0}};
    reg [31:0] stat_reg = {32{1'b0}};
    reg ctrl_ack = 0;
    wire sel_ctrl = 1'b1;
    wire [31:0] ctrl_registers[3:0];
    assign ctrl_registers[0] = IDENT;
    assign ctrl_registers[1] = DATEVERSION;
    assign ctrl_registers[2] = ctrl_reg;
    assign ctrl_registers[3] = stat_reg;
    
    always @(posedge clk) begin
        if (en_i && wr_i && sel_ctrl && adr_i[1:0] == 2) ctrl_reg <= dat_i;
        ctrl_ack <= sel_ctrl && en_i;
    end
    
    assign dat_o = ctrl_registers[adr_i[1:0]];        
    
endmodule
