module divider_u32 #(
    parameter DATA_WD = 32
)(
    input                       clk                 ,
    input                       rstn                ,
    input                       div_in_vld          ,
    input [DATA_WD-1:0]         dividend            ,
    input [DATA_WD-1:0]         divisor             ,
    output logic [DATA_WD-1:0]  div_result          ,
    output logic [DATA_WD-1:0]  remainder           ,
    output logic                div_out_vld
);
logic [$clog2(DATA_WD)+1:0] cnt;
logic [2*DATA_WD-1:0] data_tmp;
logic signed [2*DATA_WD-1:0] add_sum;
logic signed [2*DATA_WD-1:0] add_sum_r;

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        cnt <= DATA_WD;
    else if(div_in_vld)
        cnt <= 'd0;
    else 
        cnt <= (cnt >= DATA_WD)?  (DATA_WD+1) : (cnt + 1);
end

assign add_sum = div_in_vld?    ((dividend << 1) - (divisor <<< DATA_WD)) : ((data_tmp << 1) - (divisor <<< DATA_WD));

assign hit = ~add_sum[2*DATA_WD-1];

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_tmp <= 'd0;
    else if(div_in_vld)
        data_tmp <= hit?    ({add_sum[2*DATA_WD-1:1], 1'b1} ) : ({dividend[DATA_WD-1:1], 1'b0} );
    else if((cnt != 0))
        data_tmp <= hit?    ({add_sum[2*DATA_WD-1:1], 1'b1} ) : ({data_tmp[2*DATA_WD-2:0], 1'b0} );
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        div_out_vld <= 1'b0;
    else if(cnt == DATA_WD)
        div_out_vld <= 1'b1;
    else 
        div_out_vld <= 1'b0;
end

assign div_result = data_tmp[DATA_WD-1:0];
assign remainder = data_tmp[DATA_WD*2-1:DATA_WD];

endmodule