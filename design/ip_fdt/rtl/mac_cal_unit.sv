module mac_cal_unit(
    input               clk         ,
    input               rstn        ,
    input               in_valid    ,
    input [7:0][7:0]    A_in        ,
    input [7:0][7:0]    B_in        ,
    input [19:0]        p_sum_in    ,
    output logic [19:0] p_sum_out   ,
    output logic        out_valid
);

logic signed [14:0] mac_mult_0;
logic signed [14:0] mac_mult_1;
logic signed [14:0] mac_mult_2;
logic signed [14:0] mac_mult_3;
logic signed [14:0] mac_mult_4;
logic signed [14:0] mac_mult_5;
logic signed [14:0] mac_mult_6;
logic signed [14:0] mac_mult_7;

logic signed [15:0] mac_sum_st0_0;
logic signed [15:0] mac_sum_st0_1;
logic signed [15:0] mac_sum_st0_2;
logic signed [15:0] mac_sum_st0_3;
logic signed [16:0] mac_sum_st1_0;
logic signed [16:0] mac_sum_st1_1;
logic signed [17:0] mac_sum_st2  ;
logic signed [19:0] mac_sum      ;
logic signed [19:0] psum_out_p   ;

assign mac_mult_0 = in_valid?   $signed(A_in[0]) + $signed(B_in[0]) : 15'sd0;
assign mac_mult_1 = in_valid?   $signed(A_in[1]) + $signed(B_in[1]) : 15'sd0;
assign mac_mult_2 = in_valid?   $signed(A_in[2]) + $signed(B_in[2]) : 15'sd0;
assign mac_mult_3 = in_valid?   $signed(A_in[3]) + $signed(B_in[3]) : 15'sd0;
assign mac_mult_4 = in_valid?   $signed(A_in[4]) + $signed(B_in[4]) : 15'sd0;
assign mac_mult_5 = in_valid?   $signed(A_in[5]) + $signed(B_in[5]) : 15'sd0;
assign mac_mult_6 = in_valid?   $signed(A_in[6]) + $signed(B_in[6]) : 15'sd0;
assign mac_mult_7 = in_valid?   $signed(A_in[7]) + $signed(B_in[7]) : 15'sd0;

assign mac_sum_st0_0 = $signed(mac_mult_0) + $signed(mac_mult_1);
assign mac_sum_st0_1 = $signed(mac_mult_2) + $signed(mac_mult_3);
assign mac_sum_st0_2 = $signed(mac_mult_4) + $signed(mac_mult_5);
assign mac_sum_st0_3 = $signed(mac_mult_6) + $signed(mac_mult_7);
assign mac_sum_st1_0 = $signed(mac_sum_st0_0) + $signed(mac_sum_st0_1);
assign mac_sum_st1_1 = $signed(mac_sum_st0_2) + $signed(mac_sum_st0_4);
assign mac_sum_st2   = $signed(mac_sum_st1_0) + $signed(mac_sum_st1_1);
assign mac_sum       = {{2{mac_sum_st2[17]}}, mac_sum_st2[17:0]};
assign psum_out_p    = $signed(mac_sum) + $signed(psum_in);

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        psum_out <= 20'd0;
    else if(in_valid)
        psum_out <= psum_out_p;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        out_valid <= 1'b0;
    else 
        out_valid <= in_valid;
end

endmodule