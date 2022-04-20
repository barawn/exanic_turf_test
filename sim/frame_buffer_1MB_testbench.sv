`timescale 1ps / 1ps
// Testbench for the frame buffer. Need the DDR sim stuff for this.
`include "interfaces.vh"

module frame_buffer_1MB_testbench;
    
    wire aclk;
    reg aresetn = 1'b0;  
    tb_rclk #(.PERIOD(10.0)) u_aclk(.clk(aclk));

    reg fast_rst = 0;

    reg sys_clk_i;
    // diff buffer outside the module
//    wire c0_sys_clk_p;
//    wire c0_sys_clk_n;
    reg sys_rst;
        
    bit en_model;
    

  //**************************************************************************//
  // Clock Generation
  //**************************************************************************//

  initial
    sys_clk_i = 1'b0;
  always
    sys_clk_i = #(5997/2.0) ~sys_clk_i;

  // diff buffer outside the module   
//  assign c0_sys_clk_p = sys_clk_i;
//  assign c0_sys_clk_n = ~sys_clk_i;


  //**************************************************************************//
  // Reset Generation
  //**************************************************************************//
  initial begin
     sys_rst = 1'b0;
     #200
     sys_rst = 1'b1;
     en_model = 1'b0; 
     #5 en_model = 1'b1;
     #200;
     sys_rst = 1'b0;
     #100;
     aresetn = 1'b1;
  end

  // DDR stuff
  wire ddr_act_n;
  wire [16:0] ddr_adr;
  wire [1:0] ddr_ba;
  wire [1:0] ddr_bg;
  wire [0:0] ddr_ck_c;
  wire [0:0] ddr_ck_t;
  wire [0:0] ddr_cke;
  wire ddr_clk;
  wire [0:0] ddr_cs_n;
  wire [3:0] ddr_dm_n;
  wire [31:0] ddr_dq;
  wire [3:0] ddr_dqs_c;
  wire [3:0] ddr_dqs_t;
  wire [0:0] ddr_odt;
  wire ddr_reset_n;
  wire ddr_ready;
  
  wire ddr_ref_clk = sys_clk_i;

  wire [255:0] m_ddrev_tdata;
  wire [31:0] m_ddrev_tkeep;
  wire m_ddrev_tlast;
  wire m_ddrev_tready = 1'b1;
  wire m_ddrev_tvalid;
  
  wire [31:0] m_event_tdata;
  wire        m_event_tready = 1'b1;
  wire        m_event_tvalid;
  
  wire [7:0] m_mm2s_sts_tdata;
  wire       m_mm2s_sts_tvalid;
  wire       m_mm2s_sts_tready = 1'b1;
  
  wire [31:0] m_s2mm_sts_tdata;
  wire        m_s2mm_sts_tvalid;
  wire        m_s2mm_sts_tready = 1'b1;
  
  reg [15:0] s_ack_tdata = {16{1'b0}};
  reg        s_ack_tvalid = 0;
  wire       s_ack_tready;
  
  reg [255:0] s_ddrev_tdata = {256{1'b0}};
  reg [31:0] s_ddrev_tkeep = {32{1'b1}};
  reg s_ddrev_tvalid = 0;
  reg s_ddrev_tlast = 0;
  wire s_ddrev_tready;
  
  reg [31:0] s_nack_tdata = {32{1'b0}};
  reg        s_nack_tvalid = 0;
  wire s_nack_tready;
  
  sim_tb_top u_ddr(
    .en_model(en_model),
    .c0_ddr4_act_n(ddr_act_n),
    .c0_ddr4_adr(ddr_adr),
    .c0_ddr4_ba(ddr_ba),
    .c0_ddr4_bg(ddr_bg),
    .c0_ddr4_cke(ddr_cke),
    .c0_ddr4_ck_c(ddr_ck_c),
    .c0_ddr4_ck_t(ddr_ck_t),
    .c0_ddr4_reset_n(ddr_reset_n),
    .c0_ddr4_dm_dbi_n(ddr_dm_n),
    .c0_ddr4_dq(ddr_dq),
    .c0_ddr4_dqs_t(ddr_dqs_t),
    .c0_ddr4_dqs_c(ddr_dqs_c),
    .c0_ddr4_cs_n(ddr_cs_n),
    .c0_ddr4_odt(ddr_odt));

  wire [8:0] allow_count;
  wire allow = (s_ack_tdata[15] && s_ack_tvalid && s_ack_tready);
  wire allow_ddrclk;
    
  flag_sync u_allow_sync(.in_clkA(allow),.out_clkB(allow_ddrclk),
                        .clkA(aclk),.clkB(ddr_clk));

  wire ddr_clk;
  wire ddr_ready;
  
  task write_event;
    input [7:0] nwords;
    input [31:0] tag;
    integer i,j;
    begin
        for (i=0;i<nwords;i=i+1) begin
            @(posedge ddr_clk);
            #100;
            s_ddrev_tvalid = 1;
            if (i+1 == nwords) s_ddrev_tlast = 1;
            else s_ddrev_tlast = 0;
            if (i==0) begin
                s_ddrev_tdata[31:0] <= tag;
                for (j=4;j<32;j=j+1) begin : FILL
                    s_ddrev_tdata[8*j +: 8] <= 8'h20;
                end
            end else begin
                s_ddrev_tdata <= i;
            end
            while (!s_ddrev_tready) begin
                @(posedge ddr_clk);
                #100;
            end            
        end
        @(posedge ddr_clk);
        s_ddrev_tvalid = 0;
    end
  endtask
  
  task write_ack;
    input [11:0] addr;
    input allow;
    begin
        @(posedge aclk);
        #100;
        s_ack_tvalid = 1;
        s_ack_tdata = { allow, 3'b000, addr };
        while (!s_ack_tready) begin
            @(posedge aclk);
            #100;
        end
        @(posedge aclk);
        #100;
        s_ack_tvalid = 0;
    end
  endtask
    
  task write_nack;
    input [11:0] addr;
    input [19:0] len;
    begin
        @(posedge aclk);
        #100;
        s_nack_tvalid = 1;
        s_nack_tdata = { addr, len };
        while (!s_nack_tready) begin
            @(posedge aclk);
            #100;
        end
        @(posedge aclk);
        #100;
        s_nack_tvalid = 0;
    end
   endtask
    
  
  // We split off sys_rst and the aresetn for ddr-side (fast_rst).
  // We only let sys_rst happen once, but whenever we close the stream
  // port, we hold aclk/ddr_clk sides in reset.
  //
  //
  frame_buffer_1MB_wrapper u_buf(
    .aclk(aclk),
    .aresetn(aresetn),
    .sys_rst(sys_rst),
    .reset_i(fast_rst),
    .allow_i(allow_ddrclk),
    .allow_count_o(allow_count),
    .ddr_act_n(ddr_act_n),
    .ddr_adr(ddr_adr),
    .ddr_ba(ddr_ba),
    .ddr_bg(ddr_bg),
    .ddr_ck_c(ddr_ck_c),
    .ddr_ck_t(ddr_ck_t),
    .ddr_cke(ddr_cke),
    .ddr_clk(ddr_clk),
    .ddr_cs_n(ddr_cs_n),
    .ddr_dm_n(ddr_dm_n),
    .ddr_dq(ddr_dq),
    .ddr_dqs_c(ddr_dqs_c),
    .ddr_dqs_t(ddr_dqs_t),
    .ddr_odt(ddr_odt),
    .ddr_ready(ddr_ready),
    .ddr_ref_clk(sys_clk_i),
    .ddr_reset_n(ddr_reset_n),
    
    // event data flow
    `CONNECT_AXI4S_IF( m_ddrev_ , m_ddrev_ ),
    `CONNECT_AXI4S_IF( s_ddrev_ , s_ddrev_ ),
    // completed events ready for readout
    `CONNECT_AXI4S_MIN_IF(m_event_ , m_event_),
    // status output of the datamover
    `CONNECT_AXI4S_MIN_IF(m_mm2s_sts_ , m_mm2s_sts_ ),
    // status output of the datamover
    `CONNECT_AXI4S_MIN_IF(m_s2mm_sts_ , m_s2mm_sts_ ),
    // ack port
    `CONNECT_AXI4S_MIN_IF(s_ack_ , s_ack_ ),
    // nack port
    `CONNECT_AXI4S_MIN_IF(s_nack_ , s_nack_ ));
    
    initial begin
        #20000000;
        
        @(posedge ddr_clk);
        #10; fast_rst <= 1'b1;
        @(posedge aclk);
        #10; aresetn <= 1'b0;
        #100000;
        @(posedge aclk);
        #10; aresetn <= 1'b1;
        @(posedge ddr_clk);
        #10; fast_rst <= 1'b0;
        
        // Coming out of reset needs time:
        // this is handled in application by the
        // turf_event_ctrl_port directly.
        #500000;
        
        // prep ack.
        // Allow for 4 events.
        write_ack( 0, 0);
        write_ack( 1, 0);
        write_ack( 2, 0);
        // last one gets 1 allow to start things flowing.
        write_ack( 3, 1);
        // push an event... (readout will flow through automatically)
        write_event(100, "Ev00");
        // and another one
        write_event(120, "Ev01");
        
        // event flow is really quick, like a microsecond
        // (ddr is fast)
        #10000000;
        
        // nack the first one: it should show up again
        write_nack( 0, 3200 );
             
        #10000000;
        // now ack the first one, and the second event should flow
        write_ack( 0, 1);        
    end
    
    
endmodule
