`timescale 1ns / 1ps


module dna_port_wrap_tb;

    // we need 12 bytes
    parameter [95:0] sim_val = 96'h112233445566778899AABBCC;
    wire clk;
    tb_rclk #(.PERIOD(10.0)) u_clk(.clk(clk));

    reg rst = 1;
    
    wire [95:0] dna;
    dnaport_wrap #(.SIM_DNA(sim_val)) uut(.clk(clk),.rst(rst),
                                          .dna_o(dna));
    initial begin
        #100;
        @(posedge clk);
        #1 rst = 0;
    end                                  
endmodule
