module mul_unit(
    input               clk         ,
    input               rstn        ,
    input               scan_en     ,
    input               in_valid    ,
    input [7:0]         A_in        ,
    input [7:0]         B_in        ,
    output logic [14:0] mul_out     ,
    output logic        out_valid   
);

logic signed [14:0] mul_out_p;

assign mul_out_p = $signed(A_in) * $signed(B_in);

`ifdef USE_ICG
logic clk_gt;
logic in_valid_d1;
logic icg_enable;

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        in_valid_d1 <= 1'b0;
    else
        in_valid_d1 <= in_valid;
end

assign icg_enable = in_valid | in_valid_d1;

ckgate_cell u_clk_icg_mul (.clkin(clk),  .enable(icg_enable), .scan_en(scan_en), .clkout(clk_gt));

always@(posedge clk_gt or negedge rstn) begin
    if(~rstn)
        mul_out <= 15'd0;
    else
        mul_out <= mul_out_p;
end

always@(posedge clk_gt or negedge rstn) begin
    if(~rstn)
        out_valid <= 1'b0;
    else 
        out_valid <= in_valid;
end

`else

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        mul_out <= 15'd0;
    else if(in_valid)   // ?
        mul_out <= mul_out_p;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        out_valid <= 1'b0;
    else 
        out_valid <= in_valid;
end

`endif

`ifdef ASSERT_ON

logic signed [7:0] A_s,B_s;
logic signed [14:0] mul_s;
assign A_s = $signed(A_in);
assign B_s = $signed(B_in);
assign mul_s = A_s * B_s;

assert property(mul_value_assert)       
    //$display("mul value pass: A=%d, B=%d, ref=%d, real=%d",$signed(A_in),$signed(B_in), mul_s, $signed(mul_out),$time);           
    $display("mul value pass",$time);           
else
    $display("mul value error: A=%d, B=%d, ref=%d, real=%d",$signed(A_in),$signed(B_in), $signed($signed(A_in) * $signed(B_in)) , $signed(mul_out),$time);           

    

assert property(mul_valid_assert)       
    $display("mul valid pass",$time);      
else
    $display("mul valid error",$time);       

property mul_value_assert;
    longint tmp;
    @ (posedge clk) disable iff(!rstn)
    (in_valid, tmp= mul_s) |=> ##0  ($signed(mul_out) == tmp);
endproperty

property mul_valid_assert;
    @ (posedge clk) disable iff(!rstn) 
    $changed(in_valid) |-> ##1 (out_valid==$past(in_valid,1)) ;
endproperty

`endif

endmodule
