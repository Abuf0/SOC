module crgu#(
    parameter DIV_WID = 4  // must >=1 && inter
)
(
    input                   hclk        ,
    input                   hresetn     ,
    input [DIV_WID-1:0]     div_factor  ,
    output logic            pclk        ,
    output logic            presetn     ,
    output logic            pclken      
);
logic clk_div;
logic [DIV_WID-1:0] div_cnt;
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)    
        div_cnt <= 'd0;
    else if(div_cnt >= div_factor-1)   
        div_cnt <= 'd0;
    else    
        div_cnt <= div_cnt+1'b1;
end

always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)    
        clk_div <= 1'b0;
    else if(div_cnt < (div_factor>>1))
        clk_div <= 1'b0;
    else
        clk_div <= 1'b1;
end
assign pclk = clk_div;

always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)    
        pclken <= 1'b0;
    else if(div_cnt == (div_factor>>1))   
        pclken <= 1'b1;
    else    
        pclken <= 1'b0;
end

// sync_reset TODO // 
logic presetn_tmp;
always_ff@(posedge pclk or negedge hresetn) begin
    if(~hresetn)    
        {presetn_tmp,presetn} <= 'd0;
    else
        {presetn_tmp,presetn} <= {1'b1,presetn_tmp};
end
endmodule