module ahb_s2m_mux
#(   
    parameter DATA_WIDTH = 32   ,   
    parameter HSLV_NUM = 5      ,
    parameter HSLV_LEN = 32
)
(
    input [HSLV_NUM-1:0] hsel                       ,
    input hready_i [0:HSLV_LEN-1]                   ,
    input hresp_i [0:HSLV_LEN-1]                    ,
    input hexokay_i [0:HSLV_LEN-1]                  ,
    input [DATA_WIDTH-1:0] hrdata_i [0:HSLV_LEN-1]  ,
    output logic hready_o                           ,
    output logic hresp_o                            ,
    output logic hexokay_o                          ,
    output logic [DATA_WIDTH-1:0] hrdata_o
);
assign hready_o = hready_i[hsel];
assign hresp_o   = hresp_i   [hsel];
assign hexokay_o = hexokay_i [hsel];
assign hrdata_o  = hrdata_i  [hsel];
endmodule