module apb_top #(
    parameter CMD_WIDTH  = 64,
    parameter ADDR_WIDTH = 16,  // max = 32
    parameter DATA_WIDTH = 32,  // 8,16,32
    parameter SLV_NUM    = 4
)
(
    input pclk,
    input presetn,
    input [CMD_WIDTH-1:0] cmd,
    input cmd_vld
);

logic [ADDR_WIDTH-1:0] paddr;
logic  pprot;
logic pnse;
logic [SLV_NUM-1:0] psel;
logic penable;
logic pwrite;
logic [DATA_WIDTH-1:0] pwdata;
logic [DATA_WIDTH/8-1:0] pstrb;
logic pready;
logic [DATA_WIDTH-1:0] prdata;
logic pslverr;
logic pwakeup;

apb_master 
#(
    .CMD_WIDTH(CMD_WIDTH), 
    .ADDR_WIDTH(ADDR_WIDTH), 
    .DATA_WIDTH(DATA_WIDTH), 
    .SLV_NUM(SLV_NUM)
) apb_bridge_inst
(
    .pclk    ( pclk    ),
    .presetn ( presetn ),
    .cmd     ( cmd     ),
    .cmd_vld ( cmd_vld ),
    .paddr   ( paddr   ),
    .pprot   ( pprot   ),
    .pnse    ( pnse    ),
    .psel    ( psel    ),
    .penable ( penable ),
    .pwrite  ( pwrite  ),
    .pwdata  ( pwdata  ),
    .pstrb   ( pstrb   ),
    .pready  ( pready  ),
    .prdata  ( prdata  ),
    .pslverr ( pslverr ),
    .pwakeup ( pwakeup )
);

apb_slave 
#( 
    .ADDR_WIDTH(ADDR_WIDTH), 
    .DATA_WIDTH(DATA_WIDTH)
) apb_memory_inst
(
    .pclk    ( pclk    ),
    .presetn ( presetn ),
    .paddr   ( paddr   ),
    .pprot   ( pprot   ),
    .pnse    ( pnse    ),
    .psel    ( psel==4'd0 ),
    .penable ( penable ),
    .pwrite  ( pwrite  ),
    .pwdata  ( pwdata  ),
    .pstrb   ( pstrb   ),
    .pready  ( pready  ),
    .prdata  ( prdata  ),
    .pslverr ( pslverr ),
    .pwakeup ( pwakeup )
);
endmodule