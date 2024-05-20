`timescale  1ns / 1ps

module ahb_top_tb;

// ahb_top Parameters
parameter PERIOD         = 10 ;
parameter ADDR_WIDTH     = 16 ;
parameter DATA_WIDTH     = 128;
parameter MAT_NUM        = 4  ;
parameter SLV_NUM        = 4  ;
parameter CMD_WIDTH      = 64 ;
parameter HBURST_WIDTH   = 3  ;
parameter HPROT_WIDTH    = 0  ;
parameter HMASTER_WIDTH  = 8  ;

// ahb_top Inputs
logic   hclk                                 = 0 ;
logic   hresetn                              = 0 ;
logic   [CMD_WIDTH-1:0]  cmd                 = 0 ;
logic   cmd_vld                              = 0 ;

// ahb_top Outputs

always #(PERIOD/2)  hclk=~hclk;

initial begin
    #(PERIOD*2) 
    @(negedge hclk);
    hresetn  =  1;
    #(PERIOD*5)
    @(negedge hclk);
    cmd = {4'h0,4'hf,8'd0,16'h0000,32'h00000000};  // 0x0 read
    cmd_vld = 1;
    @(negedge hclk);
    cmd_vld = 0;
    #(PERIOD*10)
    @(negedge hclk);
    cmd = {4'h0,4'hf,8'd1,16'h0000,32'h00000001};  // 0x0 write 1
    cmd_vld = 1;
    @(negedge hclk);
    cmd_vld = 0;
    #(PERIOD*10)
    @(negedge hclk);
    cmd = {4'h0,4'hf,8'd1,16'h0001,32'h00000001};  // 0x1 write 1
    cmd_vld = 1;
    @(negedge hclk);
    cmd_vld = 0;
    #(PERIOD*10)
    @(negedge hclk);
    cmd = {4'h0,4'hf,8'd0,16'h0000,32'h00000000};  // 0x0 read 
    cmd_vld = 1;
    @(negedge hclk);
    cmd_vld = 0;
    #(PERIOD*10)
    @(negedge hclk);
    cmd = {4'h0,4'hf,8'd0,16'h0001,32'h00000001};  // 0x1 read 
    cmd_vld = 1;
    @(negedge hclk);
    cmd_vld = 0;
    #(PERIOD*10)
    $finish(2);
end


ahb_top #(
    .ADDR_WIDTH    ( ADDR_WIDTH    ),
    .DATA_WIDTH    ( DATA_WIDTH    ),
    .MAT_NUM       ( MAT_NUM       ),
    .SLV_NUM       ( SLV_NUM       ),
    .CMD_WIDTH     ( CMD_WIDTH     ),
    .HBURST_WIDTH  ( HBURST_WIDTH  ),
    .HPROT_WIDTH   ( HPROT_WIDTH   ),
    .HMASTER_WIDTH ( HMASTER_WIDTH ))
 u_ahb_top (
    .hclk                    ( hclk         ),
    .hresetn                 ( hresetn      ),
    .cmd                     ( cmd          ),
    .cmd_vld                 ( cmd_vld      )
);

initial begin
    $fsdbDumpfile("ahb_top_tb.fsdb");
    $fsdbDumpvars();
    $fsdbDumpMDA();
end

endmodule