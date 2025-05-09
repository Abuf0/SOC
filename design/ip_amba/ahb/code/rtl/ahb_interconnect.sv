module ahb_interconnect 
#(
    parameter ADDR_WIDTH    = 16    ,
    parameter DATA_WIDTH    = 32    ,
    parameter MAT_NUM       = 4     ,
    parameter SLV_NUM       = 4
)
(
    // ------ From/To masters ------ //
    input [ADDR_WIDTH-1:0]          haddr           ,
    output logic                    hready_o        ,
    output logic                    hresp_o         ,
    output logic [DATA_WIDTH-1:0]   hrdata_o        ,
    // ------ From/To slaves ------ //
    input [SLV_NUM-1:0]             hready_i        ,
    input [SLV_NUM-1:0]             hresp_i         ,
    input [DATA_WIDTH-1:0]          hrdata_i[0:SLV_NUM-1],
    output logic [SLV_NUM-1:0]      hsel         
);
logic [1:0] bus_sel;
logic [1:0] slv_sel;
assign bus_sel = haddr[15:14];
assign slv_sel = haddr[11:10];
always@(*) begin
    if(bus_sel==2'd0)  begin
        if(haddr[13:12]==2'd0) begin
                hready_o = hready_i[slv_sel];
                hresp_o = hresp_i[slv_sel];
                hrdata_o = hrdata_i[slv_sel];
                hsel = ({{SLV_NUM-1{1'b0}},1'b1}<<slv_sel);
        end
        else begin
            hready_o    =  1'b1    ;
            hresp_o     =  1'b0    ;
            hrdata_o    =  'd0     ;
            hsel        =  'd0     ;
        end
    end
    else  begin
        hready_o    =  1'b1    ;
        hresp_o     =  1'b0    ;
        hrdata_o    =  'd0     ;
        hsel        =  'd0     ;
    end
end

endmodule