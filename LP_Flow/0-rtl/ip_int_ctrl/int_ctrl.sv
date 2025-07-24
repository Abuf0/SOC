module int_ctrl #(
    parameter INN = 5
)(
    input clk,
    input rstn,
    input [INN-1:0] rg_int_clr,
    input reset_irq,
    input one_frame_done,
    input fifo_waterline_flag,
    input fifo_upov_flag,
    input fifo_downov_flag,
    output logic int_req,
    output logic [INN-1:0] ro_int_status
);
// todo
assign int_req = 1'b0;
assign ro_int_status = 'd0;
endmodule