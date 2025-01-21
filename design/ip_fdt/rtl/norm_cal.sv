module norm_cal(
    input               clk                 ,
    input               rstn                ,
    input [2:0]         rg_norm_data_ratio  ,
    input [1:0]         rg_fdt_tseq_num     ,    // tseq_num = (rg+1)*4
    input               norm_enable         ,
    input               soft_clr            ,
    /* AMP input */
    input [1:0]         amp_mean            ,
    input               amp_mean_vld        ,
    /* Norm output */
    output logic        norm_done           ,
    output logic        norm_trig_NN        ,
    /* cache接口 */
    output logic        cache_ena           ,
    output logic [3:0]  cache_wena          ,
    output logic [4:0]  cache_addr          ,
    output logic [63:0] cache_wdata         ,
    input [63:0]        cache_rdata
);

typedef enum logic [2:0] {STORE_MEAN, PTP_PRE, SEARCH_PTP, NORM_PRE, CAL_NORM, WORK_DONE} norm_state_t;
norm_state_t norm_state_s, norm_state_n;

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        norm_state_s <= STORE_MEAN;
    else if(soft_clr)
        norm_state_s <= STORE_MEAN;
    else
        norm_state_s <= norm_state_n;
end
/*
//  STORE_MEAN: 默认状态，存储AMP MEAN值到cache中
//  PTP_PRE:    如果使能归一化且已经get一定的AMP MEAN数量，读cache，等待读数据
//  SEARCH_PTP: 遍历已经存储的AMP MEAN数据（不足做padding），
//              寻找max和min，计算PTP=MAX-MIN，以及寻找ptp最高位1的位置，N = lzc（PTP）
//              同时累加求平均（AMPmean）
//  NORM_PRE:   按先后顺序读出cache中的AMP MEAN，等待数据
//  CAL_NORM:   根据NORM_PRE读出的AMP MEAN数据，计算NORM = （（AMP - mean）x data_ratio）/ 2^N，写入cache
//  WORK_DONE:  结束NORM功能（有可能是AMP数据量不够，或者NORM计算完成）
*/
always@(*) begin
    norm_state_n = norm_state_s;
    case(norm_state_s)
        STORE_MEAN: norm_state_n = (norm_enable && store_mean_done)?    (norm_data_enough?  PTP_PRE : WORK_DONE) : STORE_MEAN;
        PTP_PRE:    norm_state_n = ptp_pre_done?    SEARCH_PTP : PTP_PRE;
        SEARCH_PTP: norm_state_n = search_ptp_done? NORM_PRE : SEARCH_PTP;
        NORM_PRE:   norm_state_n = norm_pre_done?   CAL_NORM : NORM_PRE;
        CAL_NORM:   norm_state_n = cal_norm_done?   WORK_DONE : CAL_NORM;
        WORK_DONE:  norm_state_n = STORE_MEAN;
        default:;
    endcase
end

assign store_slice_cnt_ov = (norm_state_s == STORE_MEAN) && (store_slice_cnt == 2'd3) && amp_mean_vld;  // 每拿到4个amp_mean，就ov
assign store_line_cnt_ov = (store_line_cnt == rg_fdt_tseq_num) && store_slice_cnt_ov;   // 每拿到4*rg个amp mean，就ov
assign comm_slice_cnt_ov = (comm_slice_cnt == (padding_duration?  2'd3 : store_slice_cnt-2'd1));
assign rdata_line_cnt_ov = (rdata_line_cnt == 2'd3) && comm_slice_cnt_ov;

assign norm_data_enough = (norm_state_s == STORE_MEAN) && (fdt_first_norm?  store_line_cnt_ov : amp_mean_vld);
assign store_mean_done = (norm_state_s == STORE_MEAN) && amp_mean_vld;
assign ptp_pre_done = (norm_state_s == PTP_PRE) && comm_slice_cnt_ov;
assign search_ptp_done = (norm_state_s == SEARCH_PTP) && rdata_line_cnt_ov;
assign norm_pre_done = (norm_state_s == NORM_PRE) && comm_slice_cnt_ov;
assign cal_norm_done = (norm_state_s == CAL_NORM) && rdata_line_cnt_ov;

assign state_all_ptp = (norm_state_s == PTP_PRE) || (norm_state_s == SEARCH_PTP);
assign state_all_norm = (norm_state_s == NORM_PRE) && (norm_state_s == CAL_NORM);

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        store_slice_cnt <= 'd0;
    else if(soft_clr)
        store_slice_cnt <= 'd0;
    else if(norm_state_s == STORE_MEAN && amp_mean_vld) // amp mean vld，slice +1
        store_slice_cnt <= store_slice_cnt + 2'd1;
end


always@(posedge clk or negedge rstn) begin
    if(~rstn)
        store_line_cnt <= 'd0;
    else if(soft_clr)
        store_line_cnt <= 'd0;
    else if(store_slice_cnt_ov) // slice到点后，line +1
        store_line_cnt <= store_line_cnt + 2'd1;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        comm_slice_cnt <= 'd0;
    else if(soft_clr)
        comm_slice_cnt <= 'd0;
    else if(store_mean_done)
        comm_slice_cnt <= padding_duration? 2'd2 : store_slice_cnt-2'd1;
    else if(search_ptp_done || cal_norm_done)
        comm_slice_cnt <= padding_duration? 2'd2 : store_slice_cnt-2'd2;
    else if(state_all_ptp || state_all_norm)
        comm_slice_cnt <= comm_slice_cnt + 2'd1;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        read_line_cnt <= 'd0;
    else if(store_mean_done && store_slice_cnt_ov)
        read_line_cnt <= padding_duration? 2'd0 : store_line_cnt+2'd1;
    else if(search_mean_done || search_ptp_done)
        read_line_cnt <= padding_duration? 2'd0 : store_line_cnt;
    else if((state_all_ptp || state_all_norm) && comm_slice_cnt == 2'd1)
        read_line_cnt <= read_line_cnt + 2'd1;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        rdata_line_cnt <= 'd0;
    else if(cal_norm_done)
        rdata_line_cnt <= 'd0;
    else if((norm_state_s == SEARCH_PTP || norm_state_s == CAL_NORM) && slice_cnt_for_norm_cache==2'd3)
        rdata_line_cnt <= rdata_line_cnt + 2'd1;
end

assign padding_last_data = (padding_duration && {rdata_line_cnt, comm_slice_cnt}>={store_line_cnt, store_slice_cnt});
assign line_cnt_for_cache = (padding_duration && read_line_cnt>=store_line_cnt)?    (store_line_cnt==2'd0)?  (store_line_cnt-2'd1) : store_line_cnt : read_line_cnt;
assign slice_cnt_for_norm_cache = padding_duration?  comm_slice_cnt : (comm_slice_cnt-store_slice_cnt);
assign slice_cnt_for_cache = amp_data_from_norm_cache?  comm_slice_cnt : padding_last_data?  (store_line_cnt-2'd1) : comm_slice_cnt;

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        fdt_first_norm <= 1'b1;
    else if(soft_clr)
        fdt_first_norm <= 1'b1;
    else if(store_line_cnt_ov)
        fdt_first_norm <= 1'b0;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        padding_duration <= 1'b1;
    else if(soft_clr)
        padding_duration <= 1'b1;
    else if(store_line_cnt == 2'd3 && store_slice_cnt==2'd3 && norm_done)
        padding_duration <= 1'b0;
end

assign amp_mean_16b = {4'b0, amp_mean[11:0]};

assign norm_result_vld = (norm_state_s == CAL_NORM);
always@(posedge clk or negedge rstn) begin
    if(~rstn)
        norm_result_8b_d <= 8'd0;
    else if(norm_result_vld)
        norm_result_8b_d <= norm_result_8b;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        norm_cache <= 64'd0;
    else if(norm_trig_NN)
        norm_cache <= 64'd0;
    else if(norm_state_s == STORE_MEAN && amp_mean_vld)
        norm_cache[store_slice_cnt] <= amp_mean_16b;
    else if(norm_result_vld) begin
        if(slice_cnt_for_norm_cache[0] == 1'b0) begin
            if(norm_state_s == CAL_NORM && cache_wr)
                norm_cache <= {cache_rdata_gather[3:1], 8'b0, norm_result_8b};
            else if(~(cache_rw_conflict && cache_rd && norm_result_one_line_vld))
                norm_cache[{rdata_line_cnt[0], slice_cnt_for_norm_cache[1]}][7:0] <= norm_result_8b;
        end
        else if(slice_cnt_for_norm_cache[0] == 1'b1) begin
            if(norm_state_s == CAL_NORM && cache_wr)
                norm_cache <= {cache_rdata_gather[3:1], norm_result_8b, norm_result_8b_d};
            else if(~(cache_rw_conflict && cache_rd && norm_result_one_line_vld))
                norm_cache[{rdata_line_cnt[0], slice_cnt_for_norm_cache[1]}][7:0] <= norm_result_8b;
        end
    end
end

assign amp_store_one_group_done = fdt_first_norm?   store_slice_cnt_ov : amp_mean_vld;

// cache ctrl
assign ptp_read_cache_flag = (padding_duration? 1'b0 : (norm_state_s==PTP_PRE && comm_slice_cnt==store_line_cnt-2'd2)) || ((norm_state_s==PTP_PRE || norm_state_s==SEARCH_PTP) && comm_slice_cnt==2'd2);
assign norm_read_cache_flag = (padding_duration? 1'b0 : (norm_state_s==NORM_PRE && comm_slice_cnt==store_line_cnt-2'd2)) || ((norm_state_s==NORM_PRE || norm_state_s==CAL_NORM) && comm_slice_cnt==2'd2);

always@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        cache_ena <= 1'b0;
        cache_wena <= 4'd0;
        cache_addr <= 5'd0;
    end
    else if(norm_state_s == STORE_MEAN && amp_store_one_group_done) begin   // cache中存储AMP MEAN，按slice写入
        cache_ena <= 1'b1;
        cache_wena <= fdt_first_norm?   4'b1111 : {4'b0001<<store_slice_cnt};
        cache_addr <= `DATA_AMP_BASE_ADDR + {3'b0, store_line_cnt};
    end
    else if(norm_state_s == CAL_NORM && norm_result_one_line_vld) begin   // 归一化计算时，按line更新cache
        cache_ena <= 1'b1;
        cache_wena <= 4'b1111;
        cache_addr <= `DATA_NORM_BASE_ADDR + 5'd0;
    end
    else if(cal_norm_done) begin   // 归一化计算完成，更新cache
        cache_ena <= 1'b1;
        cache_wena <= 4'b1111;
        cache_addr <= `DATA_NORM_BASE_ADDR + 5'd1;
    end
    else if(ptp_read_cache_flag || norm_read_cache_flag) begin   // 从cache中按序读数据计算PTP和NORM时，按行读cache
        cache_ena <= 1'b1;
        cache_wena <= 4'b0;
        cache_addr <= `DATA_AMP_BASE_ADDR + {3'b0, line_cnt_for_cache};
    end
    else begin
        cache_ena <= 1'b0;
        cache_wena <= 4'b0;
    end
end

assign cache_wr = cache_ena && (cache_wena!=4'b0);
assign cache_rd = cache_ena && (cache_wena==4'b0);
assign cache_wdata = cache_wr?  norm_cache : 64'h0;

always@(*) begin
    cache_rdata_gather = cache_rdata;
    if(padding_duration && rdata_line_cnt>=store_line_cnt) begin
        case(store_slice_cnt)
            2'd1: cache_rdata_gather = {cache_rdata[15:0], cache_rdata[15:0], cache_rdata[15:0], cache_rdata[15:0]};
            2'd2: cache_rdata_gather = {cache_rdata[31:16], cache_rdata[31:16], cache_rdata[31:16], cache_rdata[15:0]};
            2'd3: cache_rdata_gather = {cache_rdata[47:32], cache_rdata[47:32], cache_rdata[31:16], cache_rdata[15:0]};
            2'd4: cache_rdata_gather = {cache_rdata[63:48], cache_rdata[47:32], cache_rdata[31:16], cache_rdata[15:0]};
    end
end

always@(posedge clk or negedge rstn) begin  // 从cache中读出AMP MEAN做归一化计算
    if(~rstn) 
        amp_data_from_norm_cache <= 1'b0;
    else if(norm_state_s == CAL_NORM && cache_rd)
        amp_data_from_norm_cache <= 1'b0;
    else if(norm_state_s == CAL_NORM && cache_wr)
        amp_data_from_norm_cache <= 1'b1;
end

assign amp_data_from_cache_16b = (norm_state_s == SEARCH_PTP || norm_state_s == CAL_NORM)? amp_data_from_norm_cache?   norm_cache[slice_cnt_for_cache] : cache_rdata_gather[slice_cnt_for_cache] : 16'd0;
assign amp_data_from_cache_12b = amp_data_from_cache_16b[11:0];

// search ptp
always@(posedge clk or negedge rstn) begin
    if(~rstn) 
        max_buff <= 12'h0;
    else if(cal_norm_done)
        max_buff <= 12'h0;
    else if(norm_state_s == SEARCH_PTP && (amp_data_from_cache_12b > max_buff))
        max_buff <= amp_data_from_cache_12b;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn) 
        min_buff <= 12'hfff;
    else if(cal_norm_done)
        min_buff <= 12'hfff;
    else if(norm_state_s == SEARCH_PTP && (amp_data_from_cache_12b < min_buff))
        min_buff <= amp_data_from_cache_12b;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn) 
        amp_mean_acc <= 16'd0;
    else if(cal_norm_done)
        amp_mean_acc <= 16'd0;
    else if(norm_state_s == SEARCH_PTP)
        amp_mean_acc <= amp_mean_acc + {4'd0, amp_data_from_cache_12b};
end

assign ptp_buf = max_buff - min_buff;
assign amp_mean_mean = amp_mean_acc[15:4];  // div 16

lzc lzc_unit(
    .mode       (1'b1           ),
    .lead       (1'b1           ),
    .trail      (1'b0           ),
    .data_in    ({4'd0, ptp_buf}),
    .cnt_out    (rang_N_index   )
);

// cal NORM
assign amp_diff = (norm_state_s == CAL_NORM)?   ($signed(amp_data_from_cache_12b) - $signed(amp_mean_mean)) : 13'sd0;
assign amp_diff_ratio_20b = $signed(amp_diff) <<< rg_norm_data_ratio;

int_sat_proc #(
    .SIGNED_IN  ( 1  ),
    .DW_IN      ( 20 ),
    .DW_OUT     ( 16 )
) amp_diff_ratio_sat(
    .data_in    ( amp_diff_ratio_20b ),
    .data_out   ( amp_diff_ratio_16b )
);

assign norm_result_16b = $signed(amp_diff_ratio_16b)>>>rang_N_index;

int_sat_proc #(
    .SIGNED_IN  ( 1  ),
    .DW_IN      ( 16 ),
    .DW_OUT     ( 8  )
) norm_result_ratio_sat(
    .data_in    ( norm_result_16b ),
    .data_out   ( norm_result_8b  )
);

assign norm_result_one_line_vld_p = norm_result_vld && comm_slice_cnt_ov && (rdata_line_cnt==2'd1);
assign cache_rw_conflict = ~padding_duration && (store_line_cnt==2'd3);

always@(posedge clk or negedge rstn) begin
    if(~rstn) 
        norm_result_one_line_vld_pd <= 1'b0;
    else if(cache_rw_conflict)
        norm_result_one_line_vld_pd <= norm_result_one_line_vld_p;
end

assign norm_result_one_line_vld = cache_rw_conflict?    norm_result_one_line_vld_pd : norm_result_one_line_vld_p;

assign norm_done = (norm_state_s == WORK_DONE);

always@(posedge clk or negedge rstn) begin
    if(~rstn) 
        norm_trig_NN <= 1'b0;
    else if(norm_done)
        norm_trig_NN <= 1'b0;
    else if(cal_norm_done)
        norm_trig_NN <= 1'b1;
end

endmodule