module reset_sync(
    input clk,
    input rstn_a,
    output logic rstn_s
);
logic [1:0] data;
always_ff @( posedge clk or negedge rstn_a) begin : reset_sync_block
    if(~rstn_a)
        data <= 2'd0;
    else
        data <= {data[0],1'b1};
end
assign rstn_s = data[1];
endmodule