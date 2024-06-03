module soc_top#(
    parameter CLK_FREQ = 20000000,
    parameter DIV_WID = 4       ,
    parameter HADDR_WIDTH = 32  ,   
    parameter PADDR_WIDTH = 16  ,
    parameter DATA_WIDTH = 32   ,   
    parameter ITCM_DEEPTH = 64  ,
    parameter DTCM_DEEPTH = 64  ,
    parameter PSLV_NUM = 5      , 
    parameter PSLV_LEN = 32     , 
    parameter HSLV_NUM = 5      ,
    parameter HSLV_LEN = 32     ,
    parameter HMAS_NUM = 5      ,
    parameter HMAS_LEN = 32     ,
    parameter HBURST_WIDTH = 3  ,
    parameter HPROT_WIDTH = 1   ,
    parameter HMASTER_WIDTH = 8 ,
    parameter IRQ_LEN = 16
)
(
    input               hclk        ,
    input               hresetn     ,
    input [DIV_WID-1:0] div_factor  ,
    input               uart_rxd    ,
    output logic        uart_txd
);
/* AHB Master List */
// 0. ICODE                             0x00000000~0x1fffffff
// 1. DCODE                             0x00000000~0x1fffffff
// 2. SYS                               0x20000000~0xdfffffff/0xe0100000~0xffffffff
// 3. DMA
// 4. ACC
// Reserved
/* AHB Slave List */
// 0. High-speed On-chip Memory (ITCM)   0x00000000~0x0000ffff
// 1. High-speed On-chip Memory (DTCM)   0x20000000~0x2000ffff
// 2. AHB2APB Bridge                     0x40000000~0x4fffffff
// 3. DDR                                0x60000000~x9ffffffff
// 4. AHB2AHB Bridge (Reserved)          0x50000000~0x5fffffff
// Reserved
/* APB Master List */
// AHB2APB Bridge
/* APB Slave List */
// 0. UART                               0x40000000~0x4000ffff
// 1. SPI                                0x40010000~0x4001ffff
// 2. I2C                                0x40020000~0x4002ffff  
// 3. Memory                             0x40030000~0x4003ffff  
// 4. LED                                0x40040000~0x4004ffff   
// Reserved

// ahb2apb_bridge Inputs
//logic                       hclk                        ;
//logic                       hresetn                     ;
logic [HSLV_NUM-1:0]        req                         ;
logic [HSLV_NUM-1:0]        hsel                        ;
logic [HMAS_NUM-1:0]        grant                       ;
logic                       hready_mux                  ;
logic                       hresp_mux                   ;
logic                       hexokay_mux                 ;
logic [DATA_WIDTH-1:0]      hrdata_mux                  ;

logic                       pclk                        ;
logic                       presetn                     ;
logic                       pclken                      ;
logic                       pready_s2m [0:PSLV_LEN-1]   ;
logic [DATA_WIDTH-1:0]      prdata_s2m [0:PSLV_LEN-1]   ;

// ahb2apb_bridge Outputs
logic                       hready_s2m [0:HSLV_LEN-1]   ;
logic                       hresp_s2m [0:HSLV_LEN-1]    ;
logic                       hexokay_s2m [0:HSLV_LEN-1]  ;
logic [DATA_WIDTH-1:0]      hrdata_s2m [0:HSLV_LEN-1]   ;
logic [PADDR_WIDTH-1:0]     paddr                       ;
logic [PSLV_NUM-1:0]        psel                        ;
logic                       penable                     ;
logic                       pwrite                      ;
logic [DATA_WIDTH-1:0]      pwdata                      ;
logic [DATA_WIDTH/8-1:0]    pstrb                       ;

logic [HADDR_WIDTH-1:0]     haddr                       ;
logic [HBURST_WIDTH-1:0]    hburst                      ;
logic [2:0]                 hsize                       ;
logic [1:0]                 htrans                      ;
logic [DATA_WIDTH-1:0]      hwdata                      ;
logic [DATA_WIDTH/8-1:0]    hwstrb                      ;
logic                       hwrite                      ;

logic [HADDR_WIDTH-1:0]     haddr_i   [0:HSLV_LEN-1]    ;
logic [HBURST_WIDTH-1:0]    hburst_i  [0:HSLV_LEN-1]    ;
logic [2:0]                 hsize_i   [0:HSLV_LEN-1]    ;
logic [1:0]                 htrans_i  [0:HSLV_LEN-1]    ;
logic [DATA_WIDTH-1:0]      hwdata_i  [0:HSLV_LEN-1]    ;
logic [DATA_WIDTH/8-1:0]    hwstrb_i  [0:HSLV_LEN-1]    ;
logic                       hwrite_i  [0:HSLV_LEN-1]    ;

crgu #(
    .DIV_WID ( DIV_WID ))
crgu_inst (
    .hclk        ( hclk          ),
    .hresetn     ( hresetn       ),
    .div_factor  ( div_factor    ),
    .pclk        ( pclk          ),
    .presetn     ( presetn       ),
    .pclken      ( pclken        )
);

//----------------------------------------------
// CORE BUS
//----------------------------------------------

// CPU I-Code 
logic    [31:0]  HADDRI;
logic    [1:0]   HTRANSI;
logic    [2:0]   HSIZEI;
logic    [2:0]   HBURSTI;
logic    [3:0]   HPROTI;
logic    [31:0]  HRDATAI;
logic            HREADYI;
logic    [1:0]   HRESPI;

// CPU D-Code 
logic    [31:0]  HADDRD;
logic    [1:0]   HTRANSD;
logic    [2:0]   HSIZED;
logic    [2:0]   HBURSTD;
logic    [3:0]   HPROTD;
logic    [31:0]  HWDATAD;
logic            HWRITED;
logic    [31:0]  HRDATAD;
logic            HREADYD;
logic    [1:0]   HRESPD;
logic    [1:0]   HMASTERD;

// CPU System bus 
logic    [31:0]  HADDRS;
logic    [1:0]   HTRANSS;
logic            HWRITES;
logic    [2:0]   HSIZES;
logic    [31:0]  HWDATAS;
logic    [2:0]   HBURSTS;
logic    [3:0]   HPROTS;
logic            HREADYS;
logic    [31:0]  HRDATAS;
logic    [1:0]   HRESPS;
logic    [1:0]   HMASTERS;
logic            HMASTERLOCKS;


//------------------------------------------------------------------------------
// DEBUG IOBUF 
//------------------------------------------------------------------------------

logic            SWDO;
logic            SWDOEN;
logic            SWDI;
logic            SWDIO;
logic            SYSRESETREQ;
logic            cpuresetn;
logic            CDBGPWRUPREQ;
logic            CDBGPWRUPACK;
logic    [239:0] IRQ;

/*
generate
    if(SimPresent) begin : SimIOBuf

        assign SWDI = SWDIO;
        assign SWDIO = (SWDOEN) ?  SWDO : 1'bz;

    end else begin : SynIOBuf

        IOBUF SWIOBUF(
            .datain                 (SWDO),
            .oe                     (SWDOEN),
            .dataout                (SWDI),
            .dataio                 (SWDIO)
        );

    end
endgenerate
*/

assign SWDI = SWDIO;
assign SWDIO = (SWDOEN) ?  SWDO : 1'bz;

//------------------------------------------------------------------------------
// RESET
//------------------------------------------------------------------------------


always @(posedge hclk or negedge hresetn)begin
    if (~hresetn) 
        cpuresetn <= 1'b0;
    else if (SYSRESETREQ) 
        cpuresetn <= 1'b0;
    else 
        cpuresetn <= 1'b1;
end

logic        SLEEPing;

//------------------------------------------------------------------------------
// DEBUG CONFIG
//------------------------------------------------------------------------------


always @(posedge hclk or negedge hresetn)begin
    if (~hresetn) 
        CDBGPWRUPACK <= 1'b0;
    else 
        CDBGPWRUPACK <= CDBGPWRUPREQ;
end


//----------------------------------------------------
// Instantiate Cortex-M3 processor 
//----------------------------------------------------

cortexm3ds_logic ulogic(
    // PMU
    .ISOLATEn                           (1'b1),
    .RETAINn                            (1'b1),

    // RESETS
    .PORESETn                           (hresetn),
    .SYSRESETn                          (cpuresetn),
    .SYSRESETREQ                        (SYSRESETREQ),
    .RSTBYPASS                          (1'b0),
    .CGBYPASS                           (1'b0),
    .SE                                 (1'b0),

    // CLOCKS
    .FCLK                               (hclk),
    .HCLK                               (hclk),
    .TRACECLKIN                         (1'b0),

    // SYSTICK
    .STCLK                              (1'b0),
    .STCALIB                            (26'b0),
    .AUXFAULT                           (32'b0),

    // CONFIG - SYSTEM
    .BIGEND                             (1'b0),
    .DNOTITRANS                         (1'b1),
    
    // SWJDAP
    .nTRST                              (1'b1),
    .SWDITMS                            (SWDI),
    .SWCLKTCK                           (1'b0),
    .TDI                                (1'b0),
    .CDBGPWRUPACK                       (CDBGPWRUPACK),
    .CDBGPWRUPREQ                       (CDBGPWRUPREQ),
    .SWDO                               (SWDO),
    .SWDOEN                             (SWDOEN),

    // IRQS
    .INTISR                             (IRQ),
    .INTNMI                             (1'b0),
    
    // I-CODE BUS
    .HREADYI                            (hready_mux),
    .HRDATAI                            (hrdata_mux),
    .HRESPI                             ( {1'b0,hresp_mux} ),
    .IFLUSH                             (1'b0),
    .HADDRI                             (haddr_i[1] ),
    .HTRANSI                            (htrans_i[1]),
    .HSIZEI                             (hsize_i[1] ),
    .HBURSTI                            (hburst_i[1]),
    .HPROTI                             (),

    // D-CODE BUS
    .HREADYD                            (hready_mux),
    .HRDATAD                            (hrdata_mux),
    .HRESPD                             ({1'b0,hresp_mux} ),
    .EXRESPD                            (1'b0   ),
    .HADDRD                             (haddr_i[2] ),
    .HTRANSD                            (htrans_i[2]),
    .HSIZED                             (hsize_i[2] ),
    .HBURSTD                            (hburst_i[2]),
    .HPROTD                             ( ),
    .HWDATAD                            (hwdata_i[2]),
    .HWRITED                            (hwrite_i[2]),
    .HMASTERD                           (),

    // SYSTEM BUS
    .HREADYS                            (hready_mux ),          //(HREADYS),
    .HRDATAS                            (hrdata_mux ),          //(HRDATAS),
    .HRESPS                             ({1'b0,hresp_mux}  ),           //(HRESPS),
    .EXRESPS                            (1'b0       ),             //(1'b0),
    .HADDRS                             (haddr_i[4] ),           //(HADDRS),
    .HTRANSS                            (htrans_i[4]),          //(HTRANSS),
    .HSIZES                             (hsize_i[4] ),           //(HSIZES),
    .HBURSTS                            (hburst_i[4]),          //(HBURSTS),
    .HPROTS                             (           ),           //(HPROTS),
    .HWDATAS                            (hwdata_i[4]),          //(HWDATAS),
    .HWRITES                            (hwrite_i[4]),          //(HWRITES),
    .HMASTERS                           (),         //(HMASTERS),
    .HMASTLOCKS                         (),     //(HMASTERLOCKS),

    // SLEEP
    .RXEV                               (1'b0),
    .SLEEPHOLDREQn                      (1'b1),
    .SLEEPING                           (SLEEPing),
    
    // EXTERNAL DEBUG REQUEST
    .EDBGRQ                             (1'b0),
    .DBGRESTART                         (1'b0),
    
    // DAP HMASTER OVERRIDE
    .FIXMASTERTYPE                      (1'b0),

    // WIC
    .WICENREQ                           (1'b0),

    // TIMESTAMP INTERFACE
    .TSVALUEB                           (48'b0),

    // CONFIG - DEBUG
    .DBGEN                              (1'b1),
    .NIDEN                              (1'b1),
    .MPUDISABLE                         (1'b0)
);


// DMA MASTER
logic    [31:0]  HADDRDM;
logic    [1:0]   HTRANSDM;
logic            HWRITEDM;
logic    [2:0]   HSIZEDM;
logic    [31:0]  HWDATADM;
logic    [2:0]   HBURSTDM;
logic    [3:0]   HPROTDM;
logic            HREADYDM;
logic    [31:0]  HRDATADM;
logic    [1:0]   HRESPDM;
logic    [1:0]   HMASTERDM;
logic            HMASTERLOCKDM;

assign  HADDRDM         =   32'b0;
assign  HTRANSDM        =   2'b0;
assign  HWRITEDM        =   1'b0;
assign  HSIZEDM         =   3'b0;
assign  HWDATADM        =   32'b0;
assign  HBURSTDM        =   3'b0;
assign  HPROTDM         =   4'b0;
assign  HMASTERDM       =   2'b0;
assign  HMASTERLOCKDM   =   1'b0;

// RESERVED MASTER 
logic    [31:0]  HADDRR;
logic    [1:0]   HTRANSR;
logic            WRITER;
logic    [2:0]   HSIZER;
logic    [31:0]  HWDATAR;
logic    [2:0]   HBURSTR;
logic    [3:0]   HPROTR;
logic            HREADYR;
logic    [31:0]  HRDATAR;
logic    [1:0]   HRESPR;
logic    [1:0]   HMASTERR;
logic            HMASTERLOCKR;

assign  HADDRR          =   32'b0;
assign  HTRANSR         =   2'b0;
assign  HWRITER         =   1'b0;
assign  HSIZER          =   3'b0;
assign  HWDATAR         =   32'b0;
assign  HBURSTR         =   3'b0;
assign  HPROTR          =   4'b0;
assign  HMASTERR        =   2'b0;
assign  HMASTERLOCKR    =   1'b0;
/*
core_v0 #(
    .HADDR_WIDTH  ( HADDR_WIDTH  ),
    .DATA_WIDTH   ( DATA_WIDTH   ),
    .HBURST_WIDTH ( HBURST_WIDTH ),
    .HPROT_WIDTH  ( HPROT_WIDTH  ),
    .IRQ_LEN      ( IRQ_LEN      ))
core_v0_inst (
    .hclk         ( hclk         ),
    .hresetn      ( hresetn      ),
    .hready       ( hready_mux   ),
    .hrdata       ( hrdata_mux   ),
    .hresp        ( hresp_mux    ),
    .nmi          (              ),
    .irq          (              ),
    .rx_ev        (              ),
    .haddr        ( haddr_i[4]   ),
    .hburst       ( hburst_i[4]  ),
    .hmasterlock  (              ),
    .hprot        (              ),
    .hsize        ( hsize_i[4]   ),
    .htrans       ( htrans_i[4]  ),
    .hwdata       ( hwdata_i[4]  ),
    .hwstrb       ( hwstrb_i[4]  ),
    .hwrite       ( hwrite_i[4]  ),
    .lockup       (              ),
    .sleeping     (              ),
    .sysresetreq  (              ),
    .tx_ev        (              )
);
*/
arbiter #(
    .HSLV_NUM   ( HSLV_NUM  ))
arbiter_inst(
    .req        ( req       ),
    .grant      ( grant     )
);

ahb_m2s_mux #(
    .HADDR_WIDTH  ( HADDR_WIDTH  ),
    .DATA_WIDTH   ( DATA_WIDTH   ),
    .HSLV_NUM     ( HSLV_NUM     ),
    .HSLV_LEN     ( HSLV_LEN     ),
    .HBURST_WIDTH ( HBURST_WIDTH ))
ahb_m2s_mux_inst (
    .grant      ( grant          ),
    .haddr_i    ( haddr_i        ),
    .hburst_i   ( hburst_i       ),
    .hsize_i    ( hsize_i        ),
    .htrans_i   ( htrans_i       ),
    .hwdata_i   ( hwdata_i       ),
    .hwstrb_i   ( hwstrb_i       ),
    .hwrite_i   ( hwrite_i       ),
    .haddr_o    ( haddr          ),
    .hburst_o   ( hburst         ),
    .hsize_o    ( hsize          ),
    .htrans_o   ( htrans         ),
    .hwdata_o   ( hwdata         ),
    .hwstrb_o   ( hwstrb         ),
    .hwrite_o   ( hwrite         )
);
/* according to haddr --> pick hsel */
assign hsel[0] = (haddr[HADDR_WIDTH-1:HADDR_WIDTH-4]==4'h0);
assign hsel[1] = (haddr[HADDR_WIDTH-1:HADDR_WIDTH-4]==4'h2);
assign hsel[2] = (haddr[HADDR_WIDTH-1:HADDR_WIDTH-4]==4'h4);
assign hsel[3] = (haddr[HADDR_WIDTH-1:HADDR_WIDTH-4]>=4'h6 && haddr[HADDR_WIDTH-1:HADDR_WIDTH-4]<=4'h9);
assign hsel[4] = (haddr[HADDR_WIDTH-1:HADDR_WIDTH-4]==4'h5);

assign req[0] = 0;
assign req[1] = 0;
assign req[2] = 1;
assign req[3] = 0;
assign req[4] = 0;


ahb_s2m_mux #(
    .DATA_WIDTH ( DATA_WIDTH ),
    .HSLV_NUM   ( HSLV_NUM   ),
    .HSLV_LEN   ( HSLV_LEN   ))
ahb_s2m_mux_inst (
    .hsel       ( hsel        ),
    .hready_i   ( hready_s2m  ),
    .hresp_i    ( hresp_s2m   ),
    .hexokay_i  ( hexokay_s2m ),
    .hrdata_i   ( hrdata_s2m  ),
    .hready_o   ( hready_mux  ),
    .hresp_o    ( hresp_mux   ),
    .hexokay_o  ( hexokay_mux ),
    .hrdata_o   ( hrdata_mux  )
);

ahb_sram 
#(
    .HADDR_WIDTH   ( HADDR_WIDTH   ),
    .DATA_WIDTH    ( DATA_WIDTH    ),
    .MEM_DEEPTH    ( ITCM_DEEPTH   ),
    .HBURST_WIDTH  ( HBURST_WIDTH  ),
    .HPROT_WIDTH   ( HPROT_WIDTH   ),
    .HMASTER_WIDTH ( HMASTER_WIDTH )
) ahb_itcm_inst
(
    .hclk          ( hclk          ),
    .hresetn       ( hresetn       ),
    .haddr         ( haddr         ),
    .hburst        ( hburst        ),
    .hmasterlock   (    ),
    .hprot         (          ),
    .hsize         ( hsize         ),
    .hnonsec       (        ),
    .hmaster       (               ),
    .htrans        ( htrans        ),
    .hwdata        ( hwdata        ),
    .hwstrb        ( hwstrb        ),
    .hwrite        ( hwrite        ),
    .hsel          ( hsel[0]       ),
    .hready        ( hready_mux    ),
    .hrdata        ( hrdata_s2m[1] ),   // bin(1)-->onehot(0)
    .hreadyout     ( hready_s2m[1]),
    .hresp         ( hresp_s2m[1]  ),
    .hexokay       ( hexokay_s2m[1])
);

ahb_sram 
#(
    .HADDR_WIDTH   ( HADDR_WIDTH   ),
    .DATA_WIDTH    ( DATA_WIDTH    ),
    .MEM_DEEPTH    ( DTCM_DEEPTH   ),
    .HBURST_WIDTH  ( HBURST_WIDTH  ),
    .HPROT_WIDTH   ( HPROT_WIDTH   ),
    .HMASTER_WIDTH ( HMASTER_WIDTH )
) ahb_dtcm_inst
(
    .hclk          ( hclk          ),
    .hresetn       ( hresetn       ),
    .haddr         ( haddr         ),
    .hburst        ( hburst        ),
    .hmasterlock   (    ),
    .hprot         (          ),
    .hsize         ( hsize         ),
    .hnonsec       (        ),
    .hmaster       (               ),
    .htrans        ( htrans        ),
    .hwdata        ( hwdata        ),
    .hwstrb        ( hwstrb        ),
    .hwrite        ( hwrite        ),
    .hsel          ( hsel[1]       ),   
    .hready        ( hready_mux    ),
    .hrdata        ( hrdata_s2m[2] ),   // bin(2)-->onehot(1)
    .hreadyout     ( hready_s2m[2]),
    .hresp         ( hresp_s2m[2]  ),
    .hexokay       ( hexokay_s2m[2])
);


// AHB2APB Bridge
ahb2apb_bridge #(
    .HADDR_WIDTH  ( HADDR_WIDTH  ),
    .PADDR_WIDTH  ( PADDR_WIDTH  ),
    .DATA_WIDTH   ( DATA_WIDTH   ),
    .HBURST_WIDTH ( HBURST_WIDTH ),
    .PSLV_NUM     ( PSLV_NUM     ),
    .PSLV_LEN     ( PSLV_LEN     ))
 ahb2apb_bridge_inst (
    .hclk         ( hclk         ),
    .hresetn      ( hresetn      ),
    .haddr        ( haddr        ),
    .hburst       ( hburst       ),
    .hsize        ( hsize        ),
    .htrans       ( htrans       ),
    .hwdata       ( hwdata       ),
    .hwstrb       ( hwstrb       ),
    .hwrite       ( hwrite       ),
    .hsel_i       ( hsel[2]      ),
    .hready_i     ( hready_mux   ),
    .pclk         ( pclk         ),
    .presetn      ( presetn      ),
    .pclken       ( pclken       ),
    .pready_i     ( pready_s2m   ),
    .prdata_i     ( prdata_s2m   ),
    .hready_o     ( hready_s2m[4] ),    // bin(4)-->onehot(2)
    .hresp_o      ( hresp_s2m[4]  ),
    .hexokay_o    ( hexokay_s2m[4]),
    .hrdata_o     ( hrdata_s2m[4] ),
    .paddr        ( paddr        ),
    .psel         ( psel         ),
    .penable      ( penable      ),
    .pwrite       ( pwrite       ),
    .pwdata       ( pwdata       ),
    .pstrb        ( pstrb        )
);
// APB Slaves
apb_uart #(
    .CLK_FREQ    ( CLK_FREQ    ),
    .ADDR_WIDTH  ( PADDR_WIDTH ),
    .DATA_WIDTH  ( DATA_WIDTH  ))
 apb_uart_inst (
    .pclk         ( pclk         ),
    .presetn      ( presetn      ),
    .paddr        ( paddr        ),
    .psel         ( psel[0]      ),
    .penable      ( penable      ),
    .pwrite       ( pwrite       ),
    .pwdata       ( pwdata       ),
    .pstrb        ( pstrb        ),
    .pready_o     ( pready_s2m[1]),
    .prdata_o     ( prdata_s2m[1]),
    .uart_txd     ( uart_txd     ),
    .uart_rxd     ( uart_rxd     )
);
apb_sram #(
    .PADDR_WIDTH ( PADDR_WIDTH ),
    .DATA_WIDTH  ( DATA_WIDTH  ))
 apb_sram_inst (
    .pclk         ( pclk         ),
    .presetn      ( presetn      ),
    .paddr        ( paddr        ),
    .psel         ( psel[3]      ),
    .penable      ( penable      ),
    .pwrite       ( pwrite       ),
    .pwdata       ( pwdata       ),
    .pstrb        ( pstrb        ),
    .pready_o     ( pready_s2m[8]),
    .prdata_o     ( prdata_s2m[8])
);

endmodule