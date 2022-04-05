`timescale 1ns / 1ps

module turf_fragment_gen(
        input aclk,
        input aresetn,
        input [31:0] s_ctrl_tdata,
        input        s_ctrl_tvalid,
        input        s_ctrl_tready
    );

    // This takes an AXI-Stream input and splits it into UDP fragments.
    // States are IDLE, HEADER, TAG, and STREAM
    // We receive an AXI4-Stream for the event generation which consists
    // of the address + length (status output of the S2MM data mover
    // after going through control logic).
    // This is functionally 32-bit (and generates our header).
     
endmodule
