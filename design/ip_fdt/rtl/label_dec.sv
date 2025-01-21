module label_dec(
    input               clk                         ,
    input               rstn                        ,
    input               soft_clr                    ,
    /* 配置信号 */
    input               rg_label_seq_init_en        ,
    input               rg_label_dec_mode           ,
    input [4:0]         rg_label_up_memcnt_th       ,
    input [4:0]         rg_label_dn_memcnt_th       ,
    input [3:0]         rg_label_memseq_len         ,
    /* FC LAYER max result */
    input [1:0]         fc_max_index                ,
    input               fc_max_index_vld            ,
    /* dec output */
    output logic        dec_result                  ,   // 0: up, 1: down
    output logic        dec_result_vld              ,
    /* 判别结束信号 */
    output logic        label_dec_done              ,
    output logic        ro_fdt_result_up            ,
    output logic        ro_fdt_result_down
);

localparam UP_IDX           = 2'd0;
localparam DN_IDX           = 2'd1;
localparam MAINTAIN_IDX     = 2'd2;

localparam UP_VAL           = 1'b0;
localparam DN_VAL           = 1'b1;

// MemSeq 决策方式 //
assign mem_seq_len = {1'b0.rg_label_memseq_len} + 5'd1; //设定的要往前追溯的MemSeq的长度
assign mem_dn_num = mem_seq[0] + mem_seq[1] + mem_seq[2] + mem_seq[3] + mem_seq[4] + mem_seq[5] + mem_seq[6] + mem_seq[7] +
                    mem_seq[8] + mem_seq[9] + mem_seq[10] + mem_seq[11] + mem_seq[12] + mem_seq[13] + mem_seq[14] + mem_seq[15] ;
assign mem_up_num = mem_seq_len - mem_dn_num;
// mem_seq只用到最近的mem_seq_len个判定结果 //
assign mem_seq_nxt0 = {dec_result, mem_seq[15:1]};
assign mem_seq_nxt1 = mem_seq_nxt0 >> (16-mem_seq_len);
assign mem_seq_nxt2 = mem_seq_nxt1 << (16-mem_seq_len);

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem_seq <= 16'b0;
    else if(soft_clr || rg_label_seq_init_en)
        mem_seq <= 16'b0;
    else if(dec_result_vld)
        mem_seq <= mem_seq_nxt2;
end

// Count 决策方式 //
// 连续判决N次 //
always@(posedge clk or negedge rstn) begin
    if(~rstn)
        up_cnt <= 5'd0;
    else if(soft_clr)
        up_cnt <= 4'd0;
    else if(rg_label_dec_mode == 1'b1 && fc_max_index_vld) begin
        if(fc_max_index == DN_IDX || fc_max_index == MAINTAIN_IDX)
            up_cnt <= 5'd0;
        else if(fc_max_index == UP_IDX)
            up_cnt <= (up_cnt >= rg_label_up_memcnt_th)?    up_cnt : up_cnt + 5'd1;
    end
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        dn_cnt <= 5'd0;
    else if(soft_clr)
        dn_cnt <= 4'd0;
    else if(rg_label_dec_mode == 1'b1 && fc_max_index_vld) begin
        if(fc_max_index == UP_IDX || fc_max_index == MAINTAIN_IDX)
            dn_cnt <= 5'd0;
        else if(fc_max_index == DN_IDX)
            dn_cnt <= (dn_cnt >= rg_label_dn_memcnt_th)?    dn_cnt : dn_cnt + 5'd1;
    end
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        updn_cnt_vld <= 1'b0;
    else
        updn_cnt_vld <= fc_max_index_vld;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        fc_max_index_d1 <= 1'b0;
    else
        fc_max_index_d1 <= fc_max_index;
end


always@(posedge clk or negedge rstn) begin
    if(~rstn)
        dec_result <= UP_VAL;
    else if(soft_clr)
        dec_result <= UP_VAL;
    // MemSeq用的是当前即时or历史判决结果，无需delay //
    else if(rg_label_dec_mode==1'b0 && fc_max_index_vld) begin
        if(fc_max_index == MAINTAIN_IDX) begin  // 如果当前判定MAINTAIN，上一次判决为UP，则保持UP；否则需要考虑MemSeq down是否>up
            if(mem_seq[15] == UP_VAL)
                dec_result <= UP_VAL;
            else if(mem_dn_num > mem_up_num)
                dec_result <= DN_VAL;
            else 
                dec_result <= UP_VAL;
        end
        else if(fc_max_index == UP_IDX)     // 如果当前判定UP/DN，则认定此次为UP/DN
            dec_result <= UP_VAL;
        else if(fc_max_index == DN_IDX)
            dec_result <= DN_VAL;
    end
    // Count判决会包含当前判决结果counter，需要delay //
    else if(rg_label_dec_mode==1'b1 && updn_cnt_vld) begin
        if(fc_max_index_d1 == UP_IDX) begin // 如果当前判决是UP，且上一次为DN，此时根据up_cnt是否达到阈值来决定此次判决结果；否则此次为UP
            if(mem_seq[15] == DN_VAL && up_cnt<rg_label_up_memcnt_th)
                dec_result <= DN_VAL;
            else
                dec_result <= UP_VAL;
        end
        else if(fc_max_index_d1 == DN_IDX) begin // 如果当前判决是DN，且上一次为UP，此时根据dn_cnt是否达到阈值来决定此次判决结果；否则此次为DN
            if(mem_seq[15] == UP_VAL && dn_cnt<rg_label_dn_memcnt_th)
                dec_result <= UP_VAL;
            else
                dec_result <= DN_IDX;
        end
        else if(fc_max_index_d1 == MAINTAIN_IDX)    // 如果当前是MAINTAIN，则当前保持前一次判决结果
            dec_result <= mem_seq[15];
    end
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        dec_result_vld <= 1'b0;
    else if(rg_label_dec_mode==1'b0 && fc_max_index_vld)
        dec_result_vld <= 1'b1;
    else if(rg_label_dec_mode==1'b1 && updn_cnt_vld)
        dec_result_vld <= 1'b1;
    else
        dec_result_vld <= 1'b0;
end

assign label_dec_done = dec_result_vld;

always@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        ro_fdt_result_up <= 1'b0;
        ro_fdt_result_down <= 1'b0;
    end
    else if(dec_result_vld) begin
        ro_fdt_result_up <= (dec_result == UP_VAL);
        ro_fdt_result_down <= (dec_result == DN_VAL);
    end

end

endmodule