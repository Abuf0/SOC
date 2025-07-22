module time_ctrl # (
    parameter AW = 16,
    parameter FIFO_DEEPTH = 256
)(
    input   clk_tim,
    input   rstn_tim,
    input   clk_afe,
    input   rstn_afe,
    input   cmd_img,
    input   rg_fifo_chk_en,
    input   [15:0] rg_fifo_enough_th,
    input   [AW-1:0] fifo_used   ,
    input   [7:0] rg_setup_time,
    input   rg_frame_mode,  // 0: contin, 1: multi
    input   [3:0] rg_multi_frame_num,
    /* hand with isp*/
    output logic isp_sta_trig,
    input   isp_done,
    /* hand with afe*/
    output logic adc_sta_trig,
    input   afe_adc_read_done,
    output logic da_pixel_bias_en, 
    output logic da_pixel_vref_en  
);
logic setup_done;
logic fifo_space_enough;
logic afe_adc_read_done_sync;
logic frame_loop_done;
logic [7:0] tcnt;
logic [3:0] frame_loop_cnt;
logic first_frame_flag;
logic one_frame_done;
logic [1:0] pp_flag;

typedef enum logic [2:0] {IDLE, SETUP, FIFO_CHK, READ, HOLD, LAST} state_t;
state_t state_c, state_n;
always_ff @( posedge clk_tim or negedge rstn_tim ) begin
    if(~rstn_tim)
        state_c <= IDLE;
    else 
        state_c <= state_n;
end
always @(*) begin
    state_n = state_c;
    case(state_c)
        IDLE:   state_n = cmd_img?  SETUP : IDLE;
        SETUP:  state_n = setup_done?   (rg_fifo_chk_en?    FIFO_CHK : READ) : SETUP;
        FIFO_CHK:   state_n = fifo_space_enough?    READ : FIFO_CHK;
        READ:   state_n =  afe_adc_read_done_sync?  HOLD : READ;
        HOLD:   state_n =  frame_loop_done?  LAST : 
                           one_frame_done?  FIFO_CHK : HOLD;
        LAST:   state_n = isp_done?  IDLE : LAST;
        default: state_n = state_c;
    endcase
end

assign fifo_space_enough = (fifo_used <= rg_fifo_enough_th);
sync_pulse afe_adc_read_done_sync_inst (.src_clk(clk_afe), .src_rstn(rstn_afe), .src_data(afe_adc_read_done), .dest_clk(clk_tim), .dest_rstn(rstn_tim), .dest_data(afe_adc_read_done_sync));
assign setup_done = (state_c == SETUP) && (tcnt == rg_setup_time-1);
always_ff@(posedge clk_tim or negedge rstn_tim) begin
    if(~rstn_tim)
        tcnt <= 'd0;
    else if(state_c == SETUP)
        tcnt <= setup_done?  'd0 : (tcnt + 1);
end

assign frame_loop_done = one_frame_done && (frame_loop_cnt == rg_multi_frame_num-1);
always_ff@(posedge clk_tim or negedge rstn_tim) begin
    if(~rstn_tim)
        frame_loop_cnt <= 'd0;
    else if(rg_frame_mode && one_frame_done)
        frame_loop_cnt <= frame_loop_done?  'd0 : (frame_loop_cnt + 1);
end

assign one_frame_done = (first_frame_flag | (pp_flag == 2'd2));
always_ff@(posedge clk_tim or negedge rstn_tim) begin
    if(~rstn_tim)
        pp_flag <= 2'd0;
    else if(one_frame_done)
        pp_flag <= 2'd0;
    else if(afe_adc_read_done_sync && isp_done)
        pp_flag <= 2'd2;
    else if(afe_adc_read_done_sync | isp_done)
        pp_flag <= pp_flag + 1;
end

always_ff@(posedge clk_tim or negedge rstn_tim) begin
    if(~rstn_tim)
        adc_sta_trig <= 1'b0;
    else if(state_c != READ && state_n == READ)
        adc_sta_trig <= 1'b1;
    else 
        adc_sta_trig <= 1'b0;
end

always_ff@(posedge clk_tim or negedge rstn_tim) begin
    if(~rstn_tim)
        first_frame_flag <= 1'b0;
    else if(state_c == IDLE && cmd_img)
        first_frame_flag <= 1'b1;
    else if(afe_adc_read_done_sync && frame_loop_cnt == 0)
        first_frame_flag <= 1'b0;
end

always_ff@(posedge clk_tim or negedge rstn_tim) begin
    if(~rstn_tim)
        isp_sta_trig <= 1'b0;
    else if((state_c != READ && state_n == READ) && ~first_frame_flag)
        isp_sta_trig <= 1'b1;
    else if(frame_loop_done)
        isp_sta_trig <= 1'b1;
    else
        isp_sta_trig <= 1'b0;
end

always_ff@(posedge clk_tim or negedge rstn_tim) begin
    if(~rstn_tim)
        da_pixel_bias_en <= 1'b0;
    else if(cmd_idle)
        da_pixel_bias_en <= 1'b1;
    else if(setup_done)
        da_pixel_bias_en <= 1'b0;
end

always_ff@(posedge clk_tim or negedge rstn_tim) begin
    if(~rstn_tim)
        da_pixel_vref_en <= 1'b0;
    else if(setup_done)
        da_pixel_vref_en <= 1'b1;
    else if(frame_loop_done)
        da_pixel_vref_en <= 1'b0;
end
endmodule