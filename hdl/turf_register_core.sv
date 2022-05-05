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

    // *real* address space partitioning happens later    
    
    parameter [31:0] IDENT = {32{1'b0}};
    parameter [31:0] DATEVERSION = {32{1'b0}};;

    reg [31:0] ctrl_reg = {32{1'b0}};
    reg [31:0] stat_reg = {32{1'b0}};
    reg ctrl_ack = 0;
    wire sel_turf = !adr_i[27];
    
    wire [31:0] ctrl_registers[3:0];
    assign ctrl_registers[0] = IDENT;
    assign ctrl_registers[1] = DATEVERSION;
    assign ctrl_registers[2] = ctrl_reg;
    assign ctrl_registers[3] = stat_reg;

    wire [95:0] dna;
    wire [31:0] dna_reg[3:0];
    assign dna_reg[0] = dna[0 +: 32];
    assign dna_reg[1] = dna[32 +: 32];
    assign dna_reg[2] = dna[64 +: 32];    
    assign dna_reg[3] = dna_reg[1];
    dnaport_wrap u_wrap(.clk(clk),.rst(rst),
                        .dna_o(dna));
    
    reg [31:0] dat_reg = {32{1'b0}};
    always @(posedge clk) begin
        if (en_i && wr_i && sel_turf && adr_i[2:0] == 3'h2) ctrl_reg <= dat_i;
        ctrl_ack <= sel_turf && en_i;
        
        if (en_i && sel_turf) begin
            if (adr_i[2]) dat_reg <= dna_reg[adr_i[1:0]];
            else dat_reg <= ctrl_registers[adr_i[1:0]];
        end
    end
    
    assign dat_o = (sel_turf) ? dat_reg : {32{1'b1}};        
    assign ack_o = (sel_turf) ? ctrl_ack : en_i;
endmodule
