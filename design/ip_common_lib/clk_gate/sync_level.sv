module sync_level(
    input        clk       ,
    input        rstn      ,
    input        level_in  ,
    output logic level_out
);
logic level_d1;
always@(posedge clk or negedge rstn) begin
    if(~rstn)
        {level_out,level_d1} <= 2'b0;
    else
        {level_out,level_d1} <= {level_d1,level_in};
end
endmodule