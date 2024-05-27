module arbiter #(
    parameter HSLV_NUM = 5
)(
    input [HSLV_NUM-1:0]            req,
    output logic [HSLV_NUM-1:0]     grant
);

// fixed priority 
assign grant = req & (~req+1'b1);

endmodule