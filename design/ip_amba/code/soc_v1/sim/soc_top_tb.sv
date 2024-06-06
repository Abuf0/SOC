`timescale  1ns / 10ps        

module soc_top_tb;

// soc_top Parameters        
parameter HCLK_PERIOD   = 10;
parameter CLK_FREQ      = 10000000;
parameter DIV_WID       = 4 ;
parameter HADDR_WIDTH   = 32;
parameter PADDR_WIDTH   = 16;
parameter DATA_WIDTH    = 32;
parameter ITCM_DEEPTH   = 65536;
parameter DTCM_DEEPTH   = 65536;
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
logic [DIV_WID-1:0] div_factor ;
logic   uart_txd                                 ;
logic   uart_rxd                             = 0 ;

// soc_top Outputs


always #(HCLK_PERIOD/2)  hclk=~hclk;


initial
begin
    #(HCLK_PERIOD*20) 
    div_factor = 'd10;
    hresetn  =  1;
    repeat(3000) begin
        @(posedge hclk);
    end
    $finish(2);
end

soc_top #(
    .CLK_FREQ     ( CLK_FREQ    ),
    .DIV_WID      ( DIV_WID      ),
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
 soc_top_inst (
    .hclk         ( hclk         ),
    .hresetn      ( hresetn      ),
    .div_factor   ( div_factor   ),
    .uart_txd     ( uart_txd     ),
    .uart_rxd     ( uart_rxd     )
);

initial begin
    $fsdbDumpfile("soc_top_tb.fsdb");
    $fsdbDumpvars();
    $fsdbDumpMDA();
end
endmodule