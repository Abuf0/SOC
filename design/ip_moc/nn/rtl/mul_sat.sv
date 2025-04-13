module mul_sat #(
    parameter DATA_WD = 32
)(
    input                              clk         ,
    input                              rstn        ,
    input                              enable      ,
    input signed [DATA_WD-1:0]         m1          ,
    input signed [DATA_WD-1:0]         m2          ,
    output logic signed [DATA_WD-1:0]  result      ,
    /* MULT interface */
    output logic signed [DATA_WD-1:0]  mult_a      ,
    output logic signed [DATA_WD-1:0]  mult_b      ,
    input logic signed [2*DATA_WD-1:0] mult_res
);

parameter Q31_MIN = 32'h80000000;
parameter Q31_MAX = 32'h7fffffff;

logic mult_sign;

assign mult_a = m1;
assign mult_b = m2;
assign mult_sign = m1[DATA_WD-1] ^ m2[DATA_WD-1];
/*
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        result <= 'd0;
    else if(enable) begin
        if((m1 == m2) && (m1 == Q31_MIN))
            result <= Q31_MAX;
        else if(mult_sign)
            result <= mult_res[30]?  (mult_res >>> 31) + 1'b1 : (mult_res >>> 31);
        else 
            result <= mult_res[30]?  (mult_res >>> 31) + 1'b1 : (mult_res >>> 31);
    end
end
*/
always@(*) begin
    if(~enable)
        result = 'sd0;
    else begin
        if((m1 == m2) && (m1 == Q31_MIN))
            result = Q31_MAX;
        else
            result = mult_res[30]?  (mult_res >>> 31) + 1'b1 : (mult_res >>> 31);
    end
end

endmodule