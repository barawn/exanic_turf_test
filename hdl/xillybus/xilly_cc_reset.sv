`timescale 1ns / 1ps
// this flings a reset every time the 'open' signal falls
module  xilly_cc_reset #(parameter LEN=16)(
        input xil_clk,
        input xil_open,
        input clk,
        output clk_reset,
        output xil_reset
    );
    
    reg xil_open_rereg = 0;
    reg xil_reset_ff = 0;
    wire xil_reset_int = !xil_open && xil_open_rereg;
    wire xil_reset_done;
    always @(posedge xil_clk) begin
        xil_open_rereg <= xil_open;
        if (xil_reset_int) xil_reset_ff <= 1;
        else if (xil_reset_done) xil_reset_ff <= 0;
    end
    
    wire cc_reset;
    flag_sync u_reset(.in_clkA(xil_reset_int),.out_clkB(cc_reset),
                      .clkA(xil_clk),.clkB(clk));
    reg cc_reset_out = 0;
    wire cc_reset_done;
    always @(posedge clk) begin
        if (cc_reset) cc_reset_out <= 1;
        else if (cc_reset_done) cc_reset_out <= 0;
    end

    SRLC32E u_delay(.D(cc_reset),.A(LEN),.CE(1'b1),.CLK(clk),.Q(cc_reset_done));
    SRLC32E u_xildelay(.D(xil_reset_int),.A(LEN),.CE(1'b1),.CLK(xil_clk),.Q(xil_reset_done));
    assign clk_reset = cc_reset_out;  
    assign xil_reset = xil_reset_ff;  
endmodule
