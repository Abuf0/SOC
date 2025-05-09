module ahb_top
#(
    parameter ADDR_WIDTH = 16   ,   // 10~64
    parameter DATA_WIDTH = 128  ,   // 8,16,32,64,128,256,512,1024
    parameter MAT_NUM = 4   ,
    parameter SLV_NUM = 4   ,   // hsel
    parameter CMD_WIDTH = 64    ,   // 
    parameter HBURST_WIDTH = 3  ,   // 0,3
    parameter HPROT_WIDTH = 0   ,   // 0,4,7
    parameter HMASTER_WIDTH = 8     // 0~8
)
(
    // ------ From system ------ //
    input                                  hclk        ,
    input                                  hresetn     ,
    input [CMD_WIDTH-1:0]                  cmd         ,
    input                                  cmd_vld         
);
//master
logic [HBURST_WIDTH-1:0]        hburst      ;
logic                           hmasterlock ;
logic [HPROT_WIDTH-1:0]         hprot       ;
logic [2:0]                     hsize       ;
logic                           hnonsec     ;
logic [HMASTER_WIDTH-1:0]       hmaster     ;
logic [1:0]                     htrans      ;
logic [DATA_WIDTH-1:0]          hwdata      ;
logic [DATA_WIDTH/8-1:0]        hwstrb      ;
logic                           hwrite      ;
logic                           hready      ;   
logic [DATA_WIDTH-1:0]          hrdata      ;   
logic                           hresp       ;  
logic [ADDR_WIDTH-1:0]          haddr       ;
// slave
logic                           hreadyout_0 ;
logic                           hresp_0     ;
logic                           hrdata_0    ;
// interface
logic [SLV_NUM-1:0]             hsel        ;
logic [DATA_WIDTH-1:0]          hrdata_i [0:SLV_NUM-1];

assign hrdata_i[0] = hrdata_0;
assign hrdata_i[1] = 'd0;
assign hrdata_i[2] = 'd0;
assign hrdata_i[3] = 'd0;

ahb_master 
#(
    .ADDR_WIDTH   ( ADDR_WIDTH   ),
    .DATA_WIDTH   ( DATA_WIDTH   ),
    .SLV_NUM      ( SLV_NUM      ),
    .CMD_WIDTH    ( CMD_WIDTH    ),
    .HBURST_WIDTH ( HBURST_WIDTH ),
    .HPROT_WIDTH  ( HPROT_WIDTH  ),
    .HMASTER_WIDTH( HMASTER_WIDTH)
) ahb_master_inst_0
(
    .hclk         ( hclk         ),
    .hresetn      ( hresetn      ),
    .cmd          ( cmd          ),
    .cmd_vld      ( cmd_vld      ),
    .hburst       ( hburst       ),
    .hmasterlock  ( hmasterlock  ),
    .hprot        ( hprot        ),
    .hsize        ( hsize        ),
    .hnonsec      ( hnonsec      ),
    .hmaster      ( hmaster      ),
    .htrans       ( htrans       ),
    .hwdata       ( hwdata       ),
    .hwstrb       ( hwstrb       ),
    .hwrite       ( hwrite       ),
    .hready       ( hready       ),
    .hrdata       ( hrdata       ),
    .hresp        ( hresp        ),
    .haddr        ( haddr        )
);

ahb_slave 
#(
    .ADDR_WIDTH    ( ADDR_WIDTH    ),
    .DATA_WIDTH    ( DATA_WIDTH    ),
    .HBURST_WIDTH  ( HBURST_WIDTH  ),
    .HPROT_WIDTH   ( HPROT_WIDTH   ),
    .HMASTER_WIDTH ( HMASTER_WIDTH )
) ahb_slave_inst_0
(
    .hclk          ( hclk          ),
    .hresetn       ( hresetn       ),
    .haddr         ( haddr         ),
    .hburst        ( hburst        ),
    .hmasterlock   ( hmasterlock   ),
    .hprot         ( hprot         ),
    .hsize         ( hsize         ),
    .hnonsec       ( hnonsec       ),
    .hmaster       ( hmaster       ),
    .htrans        ( htrans        ),
    .hwdata        ( hwdata        ),
    .hwstrb        ( hwstrb        ),
    .hwrite        ( hwrite        ),
    .hsel          ( hsel[0]       ),
    .hready        ( hready        ),
    .hrdata        ( hrdata_0      ),
    .hreadyout     ( hreadyout_0   ),
    .hresp         ( hresp_0       ),
    .hexokay       ( hexokay       )
);

ahb_interconnect 
#(
    .ADDR_WIDTH    ( ADDR_WIDTH    ),
    .DATA_WIDTH    ( DATA_WIDTH    ),
    .MAT_NUM       ( MAT_NUM       ),
    .SLV_NUM       ( SLV_NUM       )
) ahb_interconnect_inst
(
    .haddr          ( haddr         ),
    .hready_o       ( hready        ),
    .hresp_o        ( hresp         ),
    .hrdata_o       ( hrdata        ),
    .hready_i       ( {3'd0,hreadyout_0} ),
    .hresp_i        ( {3'd0,hresp_0}     ),
    .hrdata_i       ( hrdata_i     ),
    .hsel           ( hsel          )
);
endmodule