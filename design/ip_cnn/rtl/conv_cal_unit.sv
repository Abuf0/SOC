module conv_cal_unit#(
    parameter KSIZE     = 3     ,
    parameter IN_WMAX   = 224       // include padding
)(
    input                       clk                      ,
    input                       rstn                     ,
    input        [9:0]          in_width                 ,  // 不包含pad
    input        [9:0]          in_height                ,  // 不包含pad
    input        [2:0]          stride                   ,
    input        [1:0]          padding                  ,
    input                       conv_cal_enable          ,  // 需要保证enable之前config ready
    input signed [7:0]          weight [0:KSIZE*KSIZE-1] ,  // from weight buffer
    input signed [7:0]          data                     ,  // from input fifo
    input                       data_in_vld              ,  // from input fifo
    output logic signed [19:0]  conv_out                 ,  // to output fifo
    output logic                conv_out_vld             ,  // to output fifo
    output logic                fetch_data                  // to input fifo
);



// 单通道
logic signed [19:0] mac_sum_tmp [0:KSIZE*KSIZE-1];
logic mac_sum_tmp_out_vld [0:KSIZE*KSIZE-1];
assign mac_sum_tmp[0] = 'sd0;
logic mac_cal_enable;
logic signed [7:0] data_with_padding;

genvar i;
generate 
    for(i=0;i<KSIZE*KSIZE;i=i+1) begin
        if((i+1)%KSIZE == 0 && i!=KSIZE*KSIZE-1) begin  // 每行最后一个且非最后一行
            logic signed [19:0] mac_sum_tmp_shift_in;
            mac_unit mac_uint_inst(
                .clk            (clk                    ),
                .rstn           (rstn                   ),
                .enable         (mac_cal_enable         ),
                .mult_a         (data_with_padding      ),
                .mult_b         (weight[i]              ),
                .c_in           (mac_sum_tmp[i]         ),
                .mac_sum_out    (mac_sum_tmp_shift_in   )
            );
            variable_shift_reg #(.WIDTH(20), .LEN(IN_WMAX)) variable_shift_reg_inst(
                .clk            (clk                        ),
                .rstn           (rstn                       ),
                .enable         (mac_cal_enable             ),
                .addr           (in_width+2*padding-KSIZE-1 ),
                .din            (mac_sum_tmp_shift_in       ),
                .dout           (mac_sum_tmp[i+1]           )
            );
        end
        else begin
            if(i==KSIZE*KSIZE-1) begin  //最后一个
                mac_unit mac_uint_inst(
                    .clk            (clk                    ),
                    .rstn           (rstn                   ),
                    .enable         (mac_cal_enable         ),
                    .mult_a         (data_with_padding      ),
                    .mult_b         (weight[i]              ),
                    .c_in           (mac_sum_tmp[i]         ),
                    .mac_sum_out    (conv_out               )
                );
            end
            else begin
                mac_unit mac_uint_inst(
                    .clk            (clk                    ),
                    .rstn           (rstn                   ),
                    .enable         (mac_cal_enable         ),
                    .mult_a         (data_with_padding      ),
                    .mult_b         (weight[i]              ),
                    .c_in           (mac_sum_tmp[i]         ),
                    .mac_sum_out    (mac_sum_tmp[i+1]       )
                );
            end
        end
    end
endgenerate

logic [9:0] v_cnt;
logic [9:0] h_cnt;

logic v_end;
logic h_end;

logic padding_duration;
logic last_padding;
logic last_fetch;
logic [9:0] v_times;
logic [9:0] h_times;

assign v_times = (in_width  + (padding<<1));
assign h_times = (in_height + (padding<<1));

assign v_end = (v_cnt == v_times - 1);
assign h_end = (h_cnt == h_times - 1);

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        v_cnt <= 'd0;
    else if(mac_cal_enable)
        v_cnt <= v_end?    'd0 : (v_cnt+stride);
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        h_cnt <= 'd0;
    else if(mac_cal_enable && v_end)
        h_cnt <= h_end?    'd0 : (h_cnt+stride);
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        conv_out_vld <= 1'b0;
    else if(conv_cal_enable) begin
        if(v_cnt >= KSIZE-1 && h_cnt >= KSIZE-1)
            conv_out_vld <= 1'b1;
        else
            conv_out_vld <= 1'b0;
    end
    else
        conv_out_vld <= 1'b0;
end

assign mac_cal_enable = conv_cal_enable && (padding_duration | data_in_vld);
assign data_with_padding = padding_duration?    'sd0 : data;

assign padding_duration = (padding==0)?  1'b0 : (v_cnt < padding) | (v_cnt > in_width+padding-1) | (h_cnt < padding) | (h_cnt > in_height+padding-1);
assign last_padding = (padding==0)?  1'b0 : (v_cnt == padding-1) && (h_cnt > padding-1 && h_cnt < in_height+padding);
assign last_fetch = (padding==0)?  (v_cnt == in_width-1 && h_cnt == in_height-1) && data_in_vld : 
                                   (v_cnt == in_width+padding-1) && (h_cnt > padding-1 && h_cnt < in_height+padding) && data_in_vld;

assign fetch_data = conv_cal_enable && ((~padding_duration || last_padding) && ~last_fetch);


endmodule