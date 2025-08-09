module int_ctrl #(
    parameter INN = 6
)(
    input scan_enable,
    input clk_32k,
    input rstn_32k,
    input clk_sys,
    input rstn_sys,
    input [INN-1:0] rg_int_enable,
    input [INN-1:0] rg_int_clr,
    input one_frame_done,
    input fifo_spaceov_flag,
    input fifo_upov_flag,
    input fifo_downov_flag,
    input bus_error,
    output logic int_req,
    output logic [INN-1:0] ro_int_status
);

logic reset_irq;
logic reset_irq_d1;
logic reset_irq_flag;
logic fifo_spaceov_flag_d1;
logic fifo_spaceov_flag_pos;
logic bus_error_d1;
logic bus_error_pos;
logic [INN-1:0] int_source;
logic [INN-1:0] int_source_sync;
logic int_on;

assign int_source = {reset_irq_flag, one_frame_done, fifo_spaceov_flag_pos, fifo_upov_flag, fifo_downov_flag, bus_error_pos};

lp_pulse_sync #(
    .NUM(INN)
) int_source_sync_inst(
    .clk_src           (clk_sys) ,
    .rstn_src          (rstn_sys) ,
    .clk_dst           (clk_32k) ,
    .rstn_dst          (rstn_32k) ,
    .scan_en           (scan_enable) ,
    .pulse_async_in    (int_source) ,
    .pulse_sync_out    (int_source_sync)  
);


always_ff@(posedge clk_sys or negedge rstn_sys) begin
    if(~rstn_sys)
        {reset_irq, reset_irq_d1} <= 2'd0;
    else 
        {reset_irq, reset_irq_d1} <= {1'b1, reset_irq};
end

assign reset_irq_flag = reset_irq && ~reset_irq_d1;

always_ff@(posedge clk_sys or negedge rstn_sys) begin
    if(~rstn_sys)
        fifo_spaceov_flag_d1 <= 1'd0;
    else 
        fifo_spaceov_flag_d1 <= fifo_spaceov_flag;
end

assign fifo_spaceov_flag_pos = fifo_spaceov_flag & ~fifo_spaceov_flag_d1;

always_ff@(posedge clk_sys or negedge rstn_sys) begin
    if(~rstn_sys)
        bus_error_d1 <= 1'd0;
    else 
        bus_error_d1 <= bus_error;
end

assign bus_error_pos = bus_error & ~bus_error_d1;

assign int_on = |(int_source_sync & rg_int_enable & ~rg_int_clr);
always_ff@(posedge clk_32k or negedge rstn_32k) begin
    if(~rstn_32k)
        ro_int_status <= 'd0;
    else
        ro_int_status <= (ro_int_status | int_source_sync) & ~rg_int_clr;
end

always_ff@(posedge clk_32k or negedge rstn_32k) begin
    if(~rstn_32k)
        int_req <= 1'b0;
    else 
        int_req <= int_on;
end
endmodule