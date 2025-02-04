module mul_unit_nonvld(
    input               clk         ,
    input               rstn        ,
    input               scan_en     ,
    input               enable      ,
    input [7:0]         A_in        ,
    input [7:0]         B_in        ,
    output logic [14:0] mul_out     
);

logic signed [14:0] mul_out_p;

assign mul_out_p = $signed(A_in) * $signed(B_in);

`ifdef USE_ICG
logic clk_gt;

ckgate_cell u_clk_icg_mul (.clkin(clk),  .enable(enable), .scan_en(scan_en), .clkout(clk_gt));

always@(posedge clk_gt or negedge rstn) begin
    if(~rstn)
        mul_out <= 15'd0;
    else
        mul_out <= mul_out_p;
end

`else

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        mul_out <= 15'd0;
    else 
        mul_out <= mul_out_p;
end

`endif

`ifdef ASSERT_ON

logic signed [7:0] A_s,B_s;
logic signed [14:0] mul_s;
assign A_s = $signed(A_in);
assign B_s = $signed(B_in);
assign mul_s = A_s * B_s;

assert property(mul_nonvld_value_assert)       
    //$display("mul value pass: A=%d, B=%d, ref=%d, real=%d",$signed(A_in),$signed(B_in), mul_s, $signed(mul_out),$time);           
    $display("mul nonvld value pass",$time);           
else
    $display("mul nonvld value error: A=%d, B=%d, ref=%d, real=%d",$signed(A_in),$signed(B_in), $signed($signed(A_in) * $signed(B_in)) , $signed(mul_out),$time);           


property mul_nonvld_value_assert;
    longint tmp;
    @ (posedge clk) disable iff(!rstn)
    (enable, tmp= mul_s) |=> ##0  ($signed(mul_out) == tmp);
endproperty

`endif

endmodule
