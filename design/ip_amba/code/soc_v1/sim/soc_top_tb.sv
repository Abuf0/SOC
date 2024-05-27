`timescale  1ns / 10ps        

module soc_top_tb;

// soc_top Parameters        
parameter HCLK_PERIOD   = 10;
parameter PCLK_PERIOD   = 50;

parameter HADDR_WIDTH   = 32;
parameter PADDR_WIDTH   = 16;
parameter DATA_WIDTH    = 32;
parameter ITCM_DEEPTH   = 64;
parameter DTCM_DEEPTH   = 64;
parameter PSLV_NUM      = 5 ;
parameter PSLV_LEN      = 32;
parameter HSLV_NUM      = 5 ;
parameter HSLV_LEN      = 32;
parameter HMAS_NUM      = 5 ;
parameter HMAS_LEN      = 32;
parameter HBURST_WIDTH  = 3 ;
parameter IRQ_LEN       = 16;

// soc_top Inputs
logic   hclk                                 = 0 ;
logic   hresetn                              = 0 ;
logic   pclk                                 = 0 ;
logic   presetn                              = 0 ;

// soc_top Outputs


always #(HCLK_PERIOD/2)  hclk=~hclk;
always #(PCLK_PERIOD/2)  pclk=~pclk;


initial
begin
    #(PCLK_PERIOD*2) 
    hresetn  =  1;
    presetn  =  1;
    repeat(1000) begin
        @(posedge pclk);
    end
    $finish(2);
end

soc_top #(
    .HADDR_WIDTH  ( HADDR_WIDTH  ),
    .PADDR_WIDTH  ( PADDR_WIDTH  ),
    .DATA_WIDTH   ( DATA_WIDTH   ),
    .ITCM_DEEPTH  ( ITCM_DEEPTH  ),
    .DTCM_DEEPTH  ( DTCM_DEEPTH  ),
    .PSLV_NUM     ( PSLV_NUM     ),
    .PSLV_LEN     ( PSLV_LEN     ),
    .HSLV_NUM     ( HSLV_NUM     ),
    .HSLV_LEN     ( HSLV_LEN     ),
    .HMAS_NUM     ( HMAS_NUM     ),
    .HMAS_LEN     ( HMAS_LEN     ),
    .HBURST_WIDTH ( HBURST_WIDTH ),
    .IRQ_LEN      ( IRQ_LEN      ))
 u_soc_top (
    .hclk         ( hclk         ),
    .hresetn      ( hresetn      ),
    .pclk         ( pclk         ),
    .presetn      ( presetn      )
);

initial begin
    $fsdbDumpfile("soc_top_tb.fsdb");
    $fsdbDumpvars();
    $fsdbDumpMDA();
end
endmodule