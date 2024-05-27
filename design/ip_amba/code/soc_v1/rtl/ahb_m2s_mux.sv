module ahb_m2s_mux #(
    parameter HADDR_WIDTH = 32  ,   
    parameter DATA_WIDTH = 32   ,   
    parameter HSLV_NUM = 5      ,
    parameter HSLV_LEN = 32     ,
    parameter HBURST_WIDTH = 3  
)
(
    input [HSLV_NUM-1:0]            grant                   ,
    input [HADDR_WIDTH-1:0]         haddr_i [0:HSLV_LEN-1]  ,
    input [HBURST_WIDTH-1:0]        hburst_i [0:HSLV_LEN-1] ,
    input [2:0]                     hsize_i [0:HSLV_LEN-1]  ,
    input [1:0]                     htrans_i [0:HSLV_LEN-1] ,
    input [DATA_WIDTH-1:0]          hwdata_i [0:HSLV_LEN-1] ,
    input [DATA_WIDTH/8-1:0]        hwstrb_i [0:HSLV_LEN-1] ,
    input                           hwrite_i [0:HSLV_LEN-1] ,
    output logic [HADDR_WIDTH-1:0]  haddr_o                 ,
    output logic [HBURST_WIDTH-1:0] hburst_o                ,
    output logic [2:0]              hsize_o                 ,
    output logic [1:0]              htrans_o                ,
    output logic [DATA_WIDTH-1:0]   hwdata_o                ,
    output logic [DATA_WIDTH/8-1:0] hwstrb_o                ,
    output logic                    hwrite_o
);

assign haddr_o = haddr_i[grant];
assign hburst_o = hburst_i[grant];
assign hsize_o = hsize_i[grant];
assign htrans_o = htrans_i[grant];
assign hwdata_o = hwdata_i[grant];
assign hwstrb_o = hwstrb_i[grant];
assign hwrite_o = hwrite_i[grant];

endmodule