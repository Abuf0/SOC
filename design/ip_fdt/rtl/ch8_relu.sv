module ch8_relu #(
    parameter DW = 8
)(
    input        [7:0][DW-1:0]    A_in    ,
    output logic [7:0][DW-1:0]    Z_out
);

assign Z_out[0] = $signed(A_in[0] < 0)?  $signed({DW{1'b0}}) : $signed(A_in[0]);
assign Z_out[1] = $signed(A_in[1] < 0)?  $signed({DW{1'b0}}) : $signed(A_in[1]);
assign Z_out[2] = $signed(A_in[2] < 0)?  $signed({DW{1'b0}}) : $signed(A_in[2]);
assign Z_out[3] = $signed(A_in[3] < 0)?  $signed({DW{1'b0}}) : $signed(A_in[3]);
assign Z_out[4] = $signed(A_in[4] < 0)?  $signed({DW{1'b0}}) : $signed(A_in[4]);
assign Z_out[5] = $signed(A_in[5] < 0)?  $signed({DW{1'b0}}) : $signed(A_in[5]);
assign Z_out[6] = $signed(A_in[6] < 0)?  $signed({DW{1'b0}}) : $signed(A_in[6]);
assign Z_out[7] = $signed(A_in[7] < 0)?  $signed({DW{1'b0}}) : $signed(A_in[7]);

endmodule