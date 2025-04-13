module mult_int32_unit (
    input signed [31:0]         mult_a      ,
    input signed [31:0]         mult_b      ,
    output logic signed [63:0]  mult_out
);
    assign mult_out = mult_a * mult_b;
endmodule