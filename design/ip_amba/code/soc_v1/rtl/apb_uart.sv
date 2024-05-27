module apb_uart#(
    parameter PADDR_WIDTH = 16  ,
    parameter DATA_WIDTH  = 32
)
(
    input                           pclk        ,
    input                           presetn     ,
    input [PADDR_WIDTH-1:0]         paddr       ,
    input                           psel        ,
    input                           penable     ,
    input                           pwrite      ,
    input [DATA_WIDTH-1:0]          pwdata      ,
    input [DATA_WIDTH/8-1:0]        pstrb       ,
    output logic                    pready_o    ,
    output logic [DATA_WIDTH-1:0]   prdata_o
);

endmodule