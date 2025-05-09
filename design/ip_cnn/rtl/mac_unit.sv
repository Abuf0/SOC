module mac_unit(
input                       clk         ,
input                       rstn        ,
input                       enable      ,
input [7:0]                 mult_a      ,
input [7:0]                 mult_b      ,
input [19:0]                c_in        , 
output logic signed [19:0]  mac_sum_out
);

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        mac_sum_out <= 'sd0;
    else if(enable)
        mac_sum_out <= $signed(mult_a)*$signed(mult_b) + $signed(c_in);
end

endmodule
