module sync_reset(
    input  clk,
    input  async_reset,
    output sync_rstn
);
logic [1:0] din_d;
always_ff @( posedge clk or posedge async_reset ) begin
    if(async_reset)
        din_d <= 2'd0;
    else 
        din_d <= {din_d[0], 1'b1};
end
    
assign sync_rstn = din_d[1];

endmodule