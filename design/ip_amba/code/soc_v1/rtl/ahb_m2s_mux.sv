module ahb_m2s_mux #(
    parameter ADDR_MIN = 22'h000000 ,
    parameter ADDR_MAX = 22'h00003f ,
    parameter HADDR_WIDTH = 32      ,   
    parameter DATA_WIDTH = 32       ,
    parameter HMAS_NUM =5           ,
    parameter HMAS_LEN = 32         ,   
    parameter HBURST_WIDTH = 3  
)
(
    input                           hclk                  ,
    input                           hresetn               ,
    input [HADDR_WIDTH-1:0]         haddr_m  [0:HMAS_LEN] ,
    input [HBURST_WIDTH-1:0]        hburst_m [0:HMAS_LEN] ,
    input [2:0]                     hsize_m  [0:HMAS_LEN] ,
    input [1:0]                     htrans_m [0:HMAS_LEN] ,
    input [DATA_WIDTH-1:0]          hwdata_m [0:HMAS_LEN] ,
    input [DATA_WIDTH/8-1:0]        hwstrb_m [0:HMAS_LEN] ,
    input                           hwrite_m [0:HMAS_LEN] ,
    output logic [HADDR_WIDTH-1:0]  haddr_s                 ,
    output logic [HBURST_WIDTH-1:0] hburst_s                ,
    output logic [2:0]              hsize_s                 ,
    output logic [1:0]              htrans_s                ,
    output logic [DATA_WIDTH-1:0]   hwdata_s                ,
    output logic [DATA_WIDTH/8-1:0] hwstrb_s                ,
    output logic                    hwrite_s                ,
    output logic [HMAS_NUM-1:0]     req_m                   ,
    output logic [HMAS_NUM-1:0]     grant                   ,
    output logic                    hsel_s
);
logic [HMAS_NUM-1:0] req_m_old;
logic [HMAS_NUM-1:0] req_m_tmp;
//logic [HMAS_LEN:0] grant;
genvar i;
generate 
    for(i=0;i<HMAS_NUM;i=i+1) begin
        logic [HMAS_LEN:0] index;
        assign index = 1'b1 << i;
        assign req_m_tmp [i] = (haddr_m[index][HADDR_WIDTH-1:HADDR_WIDTH-22]>=ADDR_MIN && haddr_m[index][HADDR_WIDTH-1:HADDR_WIDTH-22]<=ADDR_MAX)?  1'b1:1'b0;
    end
endgenerate
assign req_m = |req_m_tmp?  req_m_tmp:req_m_old;
arbiter #(.HSLV_NUM(HMAS_NUM)) arbiter_inst(.req(req_m),.grant(grant));

always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        req_m_old <= 'd0;
    else
        req_m_old <= req_m;
end

assign haddr_s = haddr_m[grant];
assign hburst_s = hburst_m[grant];
assign hsize_s = hsize_m[grant];
assign htrans_s = htrans_m[grant];
assign hwdata_s = hwdata_m[grant];
assign hwstrb_s = hwstrb_m[grant];
assign hwrite_s = hwrite_m[grant];
assign hsel_s = |grant;
endmodule