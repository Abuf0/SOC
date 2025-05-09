//~ `New testbench
`timescale  1ns / 1ps

module apb_top_tb;

// apb_top Parameters
parameter PERIOD      = 10;
parameter CMD_WIDTH   = 64;
parameter ADDR_WIDTH  = 16;
parameter DATA_WIDTH  = 32;
parameter SLV_NUM     = 4 ;

// apb_top Inputs
logic   pclk                                 = 0 ;
logic   presetn                              = 0 ;
logic   [CMD_WIDTH-1:0]  cmd                 = 0 ;
logic   cmd_vld                              = 0 ;

// apb_top Outputs

always #(PERIOD/2)  pclk=~pclk;

initial begin
    #(PERIOD*2) 
    @(negedge pclk);
    presetn  =  1;
    #(PERIOD*5)
    @(negedge pclk);
    cmd = {4'h0,4'hf,8'd0,16'h4000,32'h00000000};  // 0x0 read
    cmd_vld = 1;
    @(negedge pclk);
    cmd_vld = 0;
    #(PERIOD*10)
    @(negedge pclk);
    cmd = {4'h0,4'hf,8'd1,16'h4000,32'h00000001};  // 0x0 write 1
    cmd_vld = 1;
    @(negedge pclk);
    cmd_vld = 0;
    #(PERIOD*10)
    @(negedge pclk);
    cmd = {4'h0,4'hf,8'd1,16'h4001,32'h00000001};  // 0x1 write 1
    cmd_vld = 1;
    @(negedge pclk);
    cmd_vld = 0;
    #(PERIOD*10)
    @(negedge pclk);
    cmd = {4'h0,4'hf,8'd0,16'h4000,32'h00000000};  // 0x0 read 
    cmd_vld = 1;
    @(negedge pclk);
    cmd_vld = 0;
    #(PERIOD*10)
    @(negedge pclk);
    cmd = {4'h0,4'hf,8'd0,16'h4001,32'h00000000};  // 0x1 read 
    cmd_vld = 1;
    @(negedge pclk);
    cmd_vld = 0;
    #(PERIOD*10)
    $finish(2);
end

apb_top #(
    .CMD_WIDTH  ( CMD_WIDTH  ),
    .ADDR_WIDTH ( ADDR_WIDTH ),
    .DATA_WIDTH ( DATA_WIDTH ),
    .SLV_NUM    ( SLV_NUM    ))
 u_apb_top (
    .pclk                    ( pclk      ),
    .presetn                 ( presetn   ),
    .cmd                     ( cmd       ),
    .cmd_vld                 ( cmd_vld   )
);

initial begin
    $fsdbDumpfile("apb_top_tb.fsdb");
    $fsdbDumpvars();
    $fsdbDumpMDA();
end

endmodule