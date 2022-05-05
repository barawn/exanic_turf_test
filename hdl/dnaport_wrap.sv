`timescale 1ns / 1ps
// DNA port wrapper
// densify this later if we need to
module dnaport_wrap(
        input clk,
        input rst,
        output [95:0] dna_o
    );
    parameter [95:0] SIM_DNA = {96{1'b0}};
        
    localparam FSM_BITS=2;
    localparam [FSM_BITS-1:0] RESET = 0;
    localparam [FSM_BITS-1:0] LOAD = 1;
    localparam [FSM_BITS-1:0] SHIFT = 2;
    localparam [FSM_BITS-1:0] DONE = 3;
    reg [FSM_BITS-1:0] state = RESET;
    
    reg [95:0] dna_reg = {96{1'b0}};
    wire [2:0] dlychn;
    SRLC32E u_dly0(.D(state == SHIFT),.CE(state != DONE),.CLK(clk),.Q31(dlychn[0]));
    SRLC32E u_dly1(.D(dlychn[0]),.CE(state != DONE),.CLK(clk),.Q31(dlychn[1]));
    SRLC32E u_dly2(.D(dlychn[1]),.CE(state != DONE),.CLK(clk),.Q31(dlychn[2]));
    
    wire dna_out;
    always @(posedge clk) begin
        if (rst) state <= RESET;
        else begin
            case (state)
                RESET: if (!dlychn[2]) state <= LOAD;
                LOAD: state <= SHIFT;
                SHIFT: if (dlychn[2]) state <= DONE;
                DONE: state <= DONE;
            endcase
        end
        if (!dlychn[2]) dna_reg <= {dna_out, dna_reg[95:1]};
    end
    DNA_PORTE2 #(.SIM_DNA_VALUE(SIM_DNA))
        u_dna(.DIN(1'b0),.READ(state == LOAD),.SHIFT(state == SHIFT),.CLK(clk),.DOUT(dna_out));
    assign dna_o = dna_reg;
endmodule
