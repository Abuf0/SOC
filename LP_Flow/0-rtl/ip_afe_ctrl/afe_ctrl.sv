module afe_ctrl(
    input   clk_afe,
    input   rstn_afe,
    input   clk_tim,
    input   rstn_tim,
    input   clk_fifo,
    input   rstn_fifo,
    input   [7:0] rg_pixel_width,
    input   [7:0] rg_pixel_height,
    input   [2:0] rg_adc_sample_prd,
    input   [7:0] ad_data,
    output logic [7:0] data_out,
    output logic data_out_vld,
    output logic da_pixadc_ck,
    input   adc_sta_trig,
    output logic   afe_adc_read_done
);
logic adc_sta_trig_sync;
logic adc_one_frame_done;
logic adc_row_end;
logic adc_one_pixel_end;
logic [7:0] adc_row_cnt;
logic [7:0] adc_pixel_cnt;
logic [3:0] adc_smp_cnt;
logic adc_smp_en_p;
logic [7:0] adc_data_p;

typedef enum logic [1:0] {ADC_IDLE, ADC_ROW, ADC_HOLD} adc_state_t;
adc_state_t adc_state_c, adc_state_n;
always_ff@(posedge clk_afe or negedge rstn_afe) begin
    if(~rstn_afe)
        adc_state_c <= ADC_IDLE;
    else
        adc_state_c <= adc_state_n;
end

always@(*) begin
    adc_state_n = adc_state_c;
    case(adc_state_c)
        ADC_IDLE:   adc_state_n = adc_sta_trig_sync?    ADC_ROW : ADC_IDLE;
        ADC_ROW:    adc_state_n = adc_one_frame_done?   ADC_IDLE :
                                  adc_row_end?  ADC_HOLD : ADC_ROW;
        ADC_HOLD:   adc_state_n = ADC_ROW;
        default:    adc_state_n = adc_state_c;
    endcase
end

sync_level adc_sta_trig_sync_inst(.clk(clk_afe), .rstn(rstn_afe), .level_in(adc_sta_trig), .level_out(adc_sta_trig_sync));
assign adc_one_frame_done = adc_row_end && (adc_row_cnt == rg_pixel_width-1);
assign adc_row_end = adc_one_pixel_end && (adc_pixel_cnt == rg_pixel_height-1);
assign adc_one_pixel_end = (adc_smp_cnt == rg_adc_sample_prd);

assign afe_adc_read_done = adc_one_frame_done;

always_ff@(posedge clk_afe or negedge rstn_afe) begin
    if(~rstn_afe)
        adc_row_cnt <= 'd0;
    else if(adc_row_end)
        adc_row_cnt <= adc_one_frame_done?  'd0 : (adc_row_cnt + 1);
end

always_ff@(posedge clk_afe or negedge rstn_afe) begin
    if(~rstn_afe)
        adc_pixel_cnt <= 'd0;
    else if(adc_one_pixel_end)
        adc_pixel_cnt <= adc_row_end?  'd0 : (adc_pixel_cnt + 1);
end

always_ff@(posedge clk_afe or negedge rstn_afe) begin
    if(~rstn_afe)
        adc_smp_cnt <= 'd0;
    else if(adc_state_c == ADC_ROW)
        adc_smp_cnt <= adc_one_pixel_end?  'd0 : (adc_smp_cnt + 1);
end

always_ff@(posedge clk_afe or negedge rstn_afe) begin
    if(~rstn_afe)
        adc_smp_en_p <= 1'b0;
    else if(adc_state_c == ADC_ROW && adc_smp_cnt == ((1+rg_adc_sample_prd) >> 1))
        adc_smp_en_p <= 1'b1;
    else if(adc_state_c == ADC_ROW && adc_smp_cnt == ((1+rg_adc_sample_prd) >> 1) + 1)
        adc_smp_en_p <= 1'b0;
end

always_ff@(posedge clk_afe or negedge rstn_afe) begin
    if(~rstn_afe)
        adc_data_p <= 'd0;
    else if(adc_state_c == ADC_ROW && adc_smp_cnt == ((1+rg_adc_sample_prd) >> 1))
        adc_data_p <= ad_data;
end

pingpong_buffer adc_ppbuff_inst(
    .src_clk(clk_afe),
    .src_rstn(rstn_afe),
    .src_vld(adc_smp_en_p),
    .src_data(adc_data_p),
    .dest_clk(clk_fifo),
    .dest_rstn(rstn_fifo),
    .dest_vld(data_out_vld),
    .dest_data(data_out),
);

always_ff@(posedge clk_afe or negedge rstn_afe) begin
    if(~rstn_afe)
        da_pixadc_ck <= 1'b0;
    else if(adc_state_c == ADC_ROW && adc_smp_cnt == 1)
        da_pixadc_ck <= 1'b1;
    else if(adc_state_c == ADC_ROW && adc_smp_cnt == ((1+rg_adc_sample_prd) >> 1))
        da_pixadc_ck <= 1'b0;
end

endmodule