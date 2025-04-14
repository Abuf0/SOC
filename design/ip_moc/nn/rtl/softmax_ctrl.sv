module softmax_ctrl #(
    parameter DATA_WB = 8           ,
    parameter DATA_WD = DATA_WB * 8 ,
    parameter ADDR_WD = 16          ,
    parameter INT32_WD = 32         ,
    parameter INT64_WD = 64         ,
    parameter N = 8     
)(
    input                       clk             ,
    input                       rstn            ,
    /* config */
    input [ADDR_WD-1:0]         rg_src_base     ,
    input [ADDR_WD-1:0]         rg_dest_base    ,
    input [1:0]                 rg_dim          ,   // 1:C, 2:H, 3:W
    input [63:0]                rg_llmulbzp     ,
    input [63:0]                rg_llmultsc     ,
    input [7:0]                 rg_llshift      ,   // 0-64
    input [31:0]                rg_inmultsc     ,
    input [7:0]                 rg_inshift      ,   // 0-64
    input [7:0]                 rg_batch        ,
    input [15:0]                rg_inh          ,
    input [15:0]                rg_inw          ,
    input [15:0]                rg_inc          ,
    input [15:0]                rg_outh         ,
    input [15:0]                rg_outw         ,
    input [15:0]                rg_outc         ,

    output logic                add_sel         ,
    output logic                mult_sel        ,
    output logic                add64_sel       ,
    output logic                mult64_sel      ,

    output logic                mul_sat_sel     ,

    input logic signed [INT32_WD-1:0]    add_sum [0:N-1]      ,
    output logic signed [INT32_WD-1:0]   add_a   [0:N-1]      ,
    output logic signed [INT32_WD-1:0]   add_b   [0:N-1]      ,
    input signed [2*INT32_WD-1:0]        mult_res [0:N-1]     ,
    output logic signed [INT32_WD-1:0]   mult_a  [0:N-1]      ,
    output logic signed [INT32_WD-1:0]   mult_b  [0:N-1]      ,

    input logic signed [INT64_WD-1:0]    add64_sum [0:N-1]      ,
    output logic signed [INT64_WD-1:0]   add64_a   [0:N-1]      ,
    output logic signed [INT64_WD-1:0]   add64_b   [0:N-1]      ,
    input signed [2*INT64_WD-1:0]        mult64_res [0:N-1]     ,
    output logic signed [INT64_WD-1:0]   mult64_a  [0:N-1]      ,
    output logic signed [INT64_WD-1:0]   mult64_b  [0:N-1]      ,


    output logic signed [INT32_WD-1:0]   mul_sat_m1 [0:N-1]   ,
    output logic signed [INT32_WD-1:0]   mul_sat_m2 [0:N-1]   ,
    input signed [INT32_WD-1:0]          mul_sat_res [0:N-1]  ,

    output logic                         exp_start            ,
    output logic signed [INT32_WD-1:0]   exp_in_val  [0:N-1]  ,
    input signed [INT32_WD-1:0]          exp_result  [0:N-1]  ,
    input                                exp_result_vld       ,

    output logic                         one_start            ,
    output logic signed [INT32_WD-1:0]   one_in_val  [0:N-1]  ,
    input signed [INT32_WD-1:0]          one_result  [0:N-1]  ,
    input                                one_result_vld       ,

    output logic [INT32_WD-1:0]          clz_in [0:N-1]       ,
    input [$clog2(INT32_WD):0]           zero_cnt[0:N-1]      ,
    output logic                         clz_start            ,
    input                                clz_vld              ,
    /* Source memory interface */
    output logic                mem_src_rd      ,
    output logic                mem_src_wr      ,
    output logic [DATA_WB-1:0]  mem_src_wmask   ,
    output logic [ADDR_WD-1:0]  mem_src_addr    ,
    output logic [DATA_WD-1:-0] mem_src_wdata   ,
    input [DATA_WD-1:0]         mem_src_rdata   ,
    /* Dest memory interface */
    output logic                mem_dest_rd     ,
    output logic                mem_dest_wr     ,
    output logic [DATA_WB-1:0]  mem_dest_wmask  ,
    output logic [ADDR_WD-1:0]  mem_dest_addr   ,
    output logic [DATA_WD-1:-0] mem_dest_wdata  ,
    input [DATA_WD-1:0]         mem_dest_rdata  ,
    /* control */
    input                       softmax_start   ,
    output logic                softmax_done    
);
parameter OFFSET = $clog2(DATA_WB);
parameter Q31_MIN = 32'h80000000;
parameter Q31_MAX = 32'h7fffffff;
parameter ACCUM_BITS = 12;
parameter STAGE_PRD = 12;

logic signed [INT32_WD-1:0] data_max [0:N-1];

logic softmax_on;
logic init_done;
logic first_fd_loop_end;
logic diff_sum_end;   
logic get_shift_end;  
logic cal_res_end;    
logic last_loop;

logic dim_c_flag;

logic [15:0] dim_cnt;
logic [15:0] x_cnt;
logic [15:0] y_cnt;
logic [15:0] batch_cnt;
logic [15:0] dim_num;
logic [15:0] x_num;
logic [15:0] y_num;
logic [15:0] batch_num; 
logic dim_loop_end;
logic x_loop_end;
logic y_loop_end;
logic batch_loop_end; 
logic frame_end;

logic state_find_max;
logic state_diff_sum;
logic state_cal_res;
logic state_shift;

logic find_max_on;
logic [4:0]find_max_on_d;
logic find_max_delay;
logic find_max_d1;
logic find_max_d2;
logic find_max_d3;
logic find_max_d4;

logic [7:0] data_max_tmp1;
logic [7:0] data_max_tmp2;
logic [7:0] data_max_tmp3;
logic [7:0] data_max_tmp4;
logic [7:0] data_max_tmp12;
logic [7:0] data_max_tmp34;

logic [4:0] stage_cnt;
logic [4:0] stage_time;
logic stage_end;

logic add_diff_sel;
logic add_sum_sel;
logic add_param_sel;
logic add_data_sel;

logic mul_sat_diff_sel;
logic mul_sat_cal_sel;

logic [7:0] data_in [0:DATA_WB-1];
logic data_in_vld;
logic [15:0] c8_num;
logic signed [INT32_WD-1:0] result_tmp [0:N-1];
logic [INT32_WD-1:0] sum [0:N-1];
logic [INT32_WD-1:0] bitsover [0:N-1];  // todo width
logic signed [INT32_WD-1:0] shift_scale [0:N-1];    // todo data type
logic [$clog2(INT32_WD):0] headroom [0:N-1];

logic signed [INT64_WD-1:0] result64_tmp [0:N-1];
logic [7:0] data_out [0:N-1];
logic [N-1:0] data_out_vld;
logic [N-1:0] mask; // todo
logic [N-1:0] mask_d1; // todo

logic dim_vld;
logic last_dim_c;
logic last_x_c;
logic cal_res_skip;
logic last_xy;

typedef enum logic [3:0] {IDLE, INIT, FIND_MAX, DIFF_SUM, GET_SHIFT, CAL_RES, DONE, WAIT} state_t;
state_t state_c,state_n;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        state_c <= IDLE;
    else 
        state_c <= state_n;
end
always@(*) begin
    state_n = IDLE;
    case(state_c)
        IDLE:       state_n = softmax_start?        INIT : IDLE;
        INIT:       state_n = init_done?            FIND_MAX : INIT;
        FIND_MAX:   state_n = first_fd_loop_end?    WAIT : FIND_MAX;
        DIFF_SUM:   state_n = diff_sum_end?         GET_SHIFT : DIFF_SUM;
        GET_SHIFT:  state_n = get_shift_end?        CAL_RES : GET_SHIFT;
        //CAL_RES:    state_n = cal_res_end?          (batch_loop_end?  DONE : DIFF_SUM) : CAL_RES;
        CAL_RES:    state_n = cal_res_end?          (batch_loop_end?  DONE : FIND_MAX) : CAL_RES;   // simple version
        WAIT:       state_n = (find_max_d4)?        DIFF_SUM : WAIT;
        default:    state_n = IDLE;
    endcase
end

assign state_find_max = (state_c == FIND_MAX);
assign state_diff_sum = (state_c == DIFF_SUM);
assign state_cal_res = (state_c == CAL_RES);
assign state_shift = (state_c == GET_SHIFT);

assign first_fd_loop_end = dim_loop_end && state_find_max;
assign diff_sum_end = state_diff_sum && dim_loop_end;   // todo sum latency
assign get_shift_end = state_shift && one_result_vld;    // todo
assign cal_res_end = state_cal_res && dim_loop_end; // todo cal latency

assign cal_res_skip = 1'b0; // todo
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        init_done <= 1'b0;
    else if(softmax_start)
        init_done <= 1'b1;
    else 
        init_done <= 1'b0;
end

assign softmax_done = (state_c == DONE);

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        softmax_on <= 1'b0;
    else if(softmax_start)
        softmax_on <= 1'b1;
    else if(softmax_done)
        softmax_on <= 1'b0;
end

assign batch_num = rg_batch;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        dim_num <= 'd0;
        x_num <= 'd0;
        y_num <= 'd0;
        dim_c_flag <= 1'b0;
    end
    else if(softmax_start) begin
        if(rg_dim == 1) begin   // C dim
            dim_num <= rg_inc[15:OFFSET] + (|rg_inc[OFFSET-1:0]);
            x_num   <= rg_inw;
            y_num   <= rg_inh;
            dim_c_flag <= 1'b1;
        end
        else if(rg_dim == 2) begin  // H dim
            dim_num <= rg_inh;
            x_num   <= rg_inc[15:OFFSET] + (|rg_inc[OFFSET-1:0]);
            y_num   <= rg_inw;
            dim_c_flag <= 1'b0;
        end
        else if(rg_dim == 3) begin  // W dim
            dim_num <= rg_inw;
            x_num   <= rg_inc[15:OFFSET] + (|rg_inc[OFFSET-1:0]);
            y_num   <= rg_inh;
            dim_c_flag <= 1'b0;
        end
    end
end

assign dim_vld = ((state_find_max) || (state_diff_sum && stage_end) || (state_cal_res && stage_end));
assign dim_loop_end = (dim_cnt == dim_num-1) && dim_vld;   // todo state latency
assign last_dim_c = (dim_cnt == dim_num-1);
assign last_x_c = (x_cnt == x_num-1);
assign last_xy = (y_cnt == y_num-1) && last_x_c;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        dim_cnt <= 'd0;
    else if(dim_vld)
        dim_cnt <= dim_loop_end?    'd0 : dim_cnt+1;
end

assign x_loop_end = cal_res_end && (x_cnt == x_num-1);
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        x_cnt <= 'd0;
    else if(cal_res_end)
        x_cnt <= x_loop_end?    'd0 : x_cnt + 1;
end

assign y_loop_end = x_loop_end && (y_cnt == y_num-1);
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        y_cnt <= 'd0;
    else if(x_loop_end)
        y_cnt <= y_loop_end?    'd0 : y_cnt + 1;
end

assign frame_end = x_loop_end && y_loop_end;

assign batch_loop_end = frame_end && (batch_cnt == batch_num-1);
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        batch_cnt <= 'd0;
    else if(frame_end)
        batch_cnt <= batch_loop_end?    'd0 : batch_cnt + 1;
end


always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        find_max_on_d <= 'd0;
    else if(softmax_on)
        find_max_on_d <= {find_max_on_d[3:0], find_max_on};
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mask_d1 <= 8'hff;
    else if(softmax_on)
        mask_d1 <= mask;
end

assign find_max_d1 = ~find_max_on_d[0] & find_max_on_d[1];
assign find_max_d2 = ~find_max_on_d[1] & find_max_on_d[2];
assign find_max_d3 = ~find_max_on_d[2] & find_max_on_d[3];
assign find_max_d4 = ~find_max_on_d[3] & find_max_on_d[4];

assign find_max_clr = init_done || cal_res_end;
assign find_max_on = state_find_max;    // todo add condition
assign c8_num = rg_inc[15:OFFSET] + |rg_inc[OFFSET-1:0];

assign data_max_tmp1 = (data_max[0] > data_max[1])? data_max[0] : data_max[1];
assign data_max_tmp2 = (data_max[2] > data_max[3])? data_max[2] : data_max[3];
assign data_max_tmp3 = (data_max[4] > data_max[5])? data_max[4] : data_max[5];
assign data_max_tmp4 = (data_max[6] > data_max[7])? data_max[6] : data_max[7];

// todo with mask //
genvar i;
generate
    for(i=0; i<N; i=i+1) begin
        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                mask[i] <= 1'b1;
            else if(softmax_on && (|rg_inc[OFFSET-1:0])) begin
                if(rg_dim == 1 && (i >= rg_inc[OFFSET-1:0]) && last_dim_c)
                    mask[i] <= 1'b0;
                else if(rg_dim != 1 &&(i >= rg_inc[OFFSET-1:0]) && last_x_c)
                    mask[i] <= 1'b0;
                else
                    mask[i] <= 1'b1;
            end
            else
                mask[i] <= 1'b1;
        end


        assign data_in[i] = mem_src_rdata[i*8+7 : i*8];
        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                data_max[i] <= 'sd0;
            else if(find_max_clr)
                data_max[i] <= 'd0;
            else if(find_max_on_d[1] && data_in_vld)
                data_max[i] <= mask_d1[i]?   ((data_in[i] > data_max[i])?  data_in[i] : data_max[i]) : data_max[i];
            else if(find_max_d2 && dim_c_flag && i==0)
                data_max[i] <= (data_max_tmp1 > data_max_tmp2)?  data_max_tmp1 : data_max_tmp2;
            else if(find_max_d3 && dim_c_flag && i==0)
                data_max[i] <= (data_max[i] > data_max_tmp3)?  data_max[i] : data_max_tmp3;
            else if(find_max_d4 && dim_c_flag)
                data_max[i] <= (data_max[0] > data_max_tmp4)?  data_max[0] : data_max_tmp4;
        end

        assign add_a[i] =   add_diff_sel?   data_in[i] :
                            add_sum_sel?    sum[i] :          // todo
                            add_param_sel?  'sd0 :          // todo 
                            add_data_sel?   'sd0 : 'sd0;    // todo

        assign add_b[i] =   add_diff_sel?   -data_max[i] :
                            add_sum_sel?    result_tmp[i] :          // todo
                            add_param_sel?  'sd0 :          // todo 
                            add_data_sel?   'sd0 : 'sd0;    // todo

        assign mul_sat_m1[i] = mul_sat_diff_sel?    (result_tmp[i] <<< (57 - rg_inshift)) : // todo pre cal
                               mul_sat_cal_sel?     exp_result[i] : 'sd0;    // todo

        assign mul_sat_m2[i] = mul_sat_diff_sel?    rg_inmultsc : 
                               mul_sat_cal_sel?     shift_scale[i] : 'sd0;    // todo

        assign mult_a[i] = mult_sel?    'sd0 : 'sd0;    // todo
        assign mult_b[i] = mult_sel?    'sd0 : 'sd0;    // todo

        assign add64_a[i] = add64_sel?    result64_tmp[i] : 'sd0;   
        assign add64_b[i] = add64_sel?    rg_llmulbzp : 'sd0;   

        assign mult64_a[i] = mult64_sel?    {{32{result_tmp[i][31]}},result_tmp[i]} : 'sd0;   
        assign mult64_b[i] = mult64_sel?    rg_llmultsc : 'sd0;   

        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                result_tmp[i] <= 'sd0;
            else if(state_diff_sum) begin
                if(stage_cnt == 0)  //Diff = puch - Max
                    result_tmp[i] <= add_sum[i];
                else if(stage_cnt == 1) // mul_sat = MUL_SAT(Diff * Mask, InMult)
                    result_tmp[i] <= mul_sat_res[i];
                else if(stage_cnt == 2 && exp_result_vld)   // sum_delta = DIV_POW2(exp, ACCUM_BITS)
                    result_tmp[i] <= mask[i]?   (exp_result[i][ACCUM_BITS-1]?  (exp_result[i][INT32_WD-1]?  (exp_result[i] >>> ACCUM_BITS)-1 : (exp_result[i] >>> ACCUM_BITS)+1) : (exp_result[i] >>> ACCUM_BITS)) : 'sd0;
                else if(stage_cnt >= 4 && stage_cnt < 11 && dim_c_flag && last_dim_c && i==0)
                    result_tmp[i] <= sum[stage_cnt-3];
            end
            else if(state_cal_res && ~cal_res_skip) begin
                if(stage_cnt == 1)  //Diff = puch - Max
                    result_tmp[i] <= add_sum[i];
                else if(stage_cnt == 3) // Data_temp = DIV_POW2(shifted_mul_sat, BitsOverUnit)
                    result_tmp[i] <= mul_sat_res[i][bitsover[i]-1]?  (mul_sat_res[i][INT32_WD-1]?  (mul_sat_res[i] >>> bitsover[i])-1 : (mul_sat_res[i] >>> bitsover[i])+1) : (mul_sat_res[i] >>> bitsover[i]);
            end
            // todo with skip
        end

        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                result64_tmp[i] <= 'sd0;
            else if(state_cal_res && ~cal_res_skip) begin
                if(stage_cnt == 4)  // Data_temp*llMultSc(without latch)
                    result64_tmp[i] <= mult64_res[i];
                else if(stage_cnt == 5)
                    result64_tmp[i] <= add64_sum[i];                
                else if(stage_cnt == 6)
                    result64_tmp[i] <= (result64_tmp[i] >>> rg_llshift);
            end
            // todo with skip
        end

        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                data_out[i] <= 'd0;
            else if(state_cal_res && stage_end)
                data_out[i] <=  (result64_tmp[i] > 255)?   8'd255 :
                                (result64_tmp[i] < 0)?     8'd0 : (result64_tmp[i][7:0]);
        end

        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                data_out_vld[i] <= 1'b0;
            else if(state_cal_res && stage_end && mask[i])
                data_out_vld[i] <=  1'b1;
            else
                data_out_vld[i] <= 1'b0;                 
        end

        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                sum[i] <= 'd0;
            else if(cal_res_end)
                sum[i] <= 'd0;
            else if(add_sum_sel) begin
                if(stage_cnt == 3)
                    sum[i] <= add_sum[i];
                else if(dim_c_flag && last_dim_c && stage_cnt>=5 && i==0)
                    sum[i] <= add_sum[i];
                else if(~dim_c_flag && stage_cnt == 3)
                    sum[i] <= add_sum[i];
            end

        end
        
        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                exp_in_val[i] <= 'sd0;
            else if(state_diff_sum && stage_cnt==1) begin
                exp_in_val[i] <= mul_sat_res[i];
            end
            else if(state_cal_res && ~cal_res_skip && stage_cnt==2) begin
                exp_in_val[i] <= mul_sat_res[i];
            end
            // todo cal_res
        end

        assign clz_in[i] = (state_shift && (~dim_c_flag || (dim_c_flag && i==0)))?   sum[i] : 'd0;
        assign headroom[i] = zero_cnt[i];

        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                bitsover[i] <= 'd0;
            else if(state_shift && clz_vld)
                bitsover[i] <= (dim_c_flag)?  (35 - headroom[0]) : (35 - headroom[i]);
        end        

        assign one_in_val[i] = (sum[i] << headroom[i]) - (1 << 31);

        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                shift_scale[i] <= 'd0;
            else if(state_shift && one_result_vld) 
                shift_scale[i] <= (dim_c_flag)?  one_result[0] : one_result[i];
        end        

    end
endgenerate

logic exp_on;

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        exp_on <= 1'b0;
    else if(exp_start)
        exp_on <= 1'b1;
    else if(exp_result_vld)
        exp_on <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        exp_start <= 1'b0;
    else if(((state_diff_sum && stage_cnt==2) || (state_cal_res && ~cal_res_skip && stage_cnt==2)) && ~exp_on) 
        exp_start <= 1'b1;
    else
        exp_start <= 1'b0;
    // todo cal_res
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        clz_start <= 1'b0;
    else if(diff_sum_end)
        clz_start <= 1'b1;
    else 
        clz_start <= 1'b0;
end

assign one_start = (state_shift && clz_vld);

// source memory interface //
logic [ADDR_WD-1:0] mem_src_addr_next;
logic [ADDR_WD-1:0] mem_src_addr_head;
logic [ADDR_WD-1:0] mem_src_addr_head_next;

assign mem_src_addr_next = (rg_dim == 1)?   (mem_src_addr + 1) :
                           (rg_dim == 2)?   (mem_src_addr + c8_num * rg_inw) :  // todo pre-cal
                           (rg_dim == 3)?   (mem_src_addr + c8_num) : 'd0;

assign mem_src_addr_head_next = (rg_dim == 1)?   (mem_src_addr_head + c8_num) :
                                (rg_dim == 2)?   (mem_src_addr_head + 1) :  // todo pre-cal
                                (rg_dim == 3)?   (last_x_c?  (mem_src_addr_head + 1 - c8_num + c8_num * rg_inw) : (mem_src_addr_head + 1)) : 'd0;

always_ff@(posedge clk or negedge rstn) begin   // todo
    if(~rstn)
        mem_src_addr_head <= 'd0;
    else if(init_done)
        mem_src_addr_head <= rg_src_base;
    else if(get_shift_end) begin
        if(last_xy)
            mem_src_addr_head <= mem_src_addr + 1;
        else 
            mem_src_addr_head <= mem_src_addr_head_next;
    end
end

always_ff@(posedge clk or negedge rstn) begin   // todo
    if(~rstn)
        mem_src_addr <= 'd0;
    else if(init_done)
        mem_src_addr <= rg_src_base;
    else if(find_max_on_d[0] & state_find_max)
        mem_src_addr <= mem_src_addr_next;
    else if(find_max_d3 || (get_shift_end && ~cal_res_skip) || (cal_res_end))    // todo
        mem_src_addr <= mem_src_addr_head;
    else if(((state_diff_sum && exp_result_vld && ~last_dim_c)) || (state_cal_res && ~cal_res_skip && exp_result_vld && ~last_dim_c))   // todo
        mem_src_addr <= mem_src_addr_next;
end

always_ff@(posedge clk or negedge rstn) begin   // todo
    if(~rstn)
        mem_src_rd <= 1'b0;
    else if(state_find_max)
        mem_src_rd <= 1'b1;
    else if(find_max_d3 || (get_shift_end && ~cal_res_skip))// || (cal_res_end))    // todo 
        mem_src_rd <= 1'b1;
    else if(((state_diff_sum && exp_result_vld && ~last_dim_c)) || (state_cal_res && ~cal_res_skip && exp_result_vld && ~last_dim_c))  // todo 
        mem_src_rd <= 1'b1;
    else
        mem_src_rd <= 1'b0;
end

assign mem_src_wr = 1'b0;
assign mem_src_wmask = 'd0;
assign mem_src_wdata = 'd0;

always_ff@(posedge clk or negedge rstn) begin   // todo
    if(~rstn)
        data_in_vld <= 1'b0;
    else if(mem_src_rd)
        data_in_vld <= 1'b1;
    else
        data_in_vld <= 1'b0;
end

// dest memory interface //
logic [ADDR_WD-1:0] mem_dest_addr_next;
logic [ADDR_WD-1:0] mem_dest_addr_head;
logic [ADDR_WD-1:0] mem_dest_addr_head_next;

assign mem_dest_addr_next = (rg_dim == 1)?   (mem_dest_addr + 1) :
                            (rg_dim == 2)?   (mem_dest_addr + c8_num * rg_inw) :  // todo pre-cal
                            (rg_dim == 3)?   (mem_dest_addr + c8_num) : 'd0;

assign mem_dest_addr_head_next = (rg_dim == 1)?   (mem_dest_addr_head + c8_num) :
                                 (rg_dim == 2)?   (last_x_c?  (mem_dest_addr_head + 1) : (mem_dest_addr_head + 1)) :  // todo pre-cal
                                 (rg_dim == 3)?   (last_x_c?  (mem_dest_addr_head + 1 - c8_num + c8_num * rg_inw) : (mem_dest_addr_head + 1)) : 'd0;

always_ff@(posedge clk or negedge rstn) begin   // todo
    if(~rstn)
        mem_dest_addr_head <= 'd0;
    else if(init_done)
        mem_dest_addr_head <= rg_dest_base;
    else if(cal_res_end) begin
        if(last_xy)
            mem_dest_addr_head <= mem_dest_addr + 1;
        else
            mem_dest_addr_head <= mem_dest_addr_head_next;
    end
end

always_ff@(posedge clk or negedge rstn) begin   // todo
    if(~rstn)
        mem_dest_addr <= 'd0;
    else if(init_done)
        mem_dest_addr <= rg_dest_base;
    else if(get_shift_end)    // todo
        mem_dest_addr <= mem_dest_addr_head;
    else if(|data_out_vld)   // todo
        mem_dest_addr <= mem_dest_addr_next;
end

assign mem_dest_wr = |data_out_vld;
assign mem_dest_wdata = {data_out[7], data_out[6], data_out[5], data_out[4], data_out[3], data_out[2], data_out[1], data_out[0]};
assign mem_dest_wmask = data_out_vld;
assign mem_dest_rd = 1'b0;

assign stage_time = state_diff_sum?  STAGE_PRD :
                    (state_cal_res && cal_res_skip)?    8 : 8; // todo
assign stage_end = (stage_cnt == stage_time-1);
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        stage_cnt <= 'd0;
    else if(softmax_start)
        stage_cnt <= 'd0;
    else if(state_diff_sum) begin
        if(stage_cnt < 2)
            stage_cnt <= stage_cnt + 1;
        else if(stage_cnt == 2)
            stage_cnt <= exp_result_vld?  (stage_cnt + 1) : stage_cnt;
        else 
            stage_cnt <= stage_end?   'd0 : (stage_cnt+1);
    end
    else if(state_cal_res) begin
        if(cal_res_skip) begin
            stage_cnt <= stage_end?   'd0 : (stage_cnt+1);
        end
        else begin
            if(stage_cnt < 3)
                stage_cnt <= stage_cnt + 1;
            else if(stage_cnt == 3)
                stage_cnt <= exp_result_vld?  (stage_cnt + 1) : stage_cnt;
            else 
                stage_cnt <= stage_end?   'd0 : (stage_cnt+1);
        end
    end
end

assign add_diff_sel  = (state_diff_sum && stage_cnt==0) || (state_cal_res && ~cal_res_skip && stage_cnt==1);
assign add_sum_sel   = (state_diff_sum && stage_cnt>2);
assign add_param_sel = (state_shift && stage_cnt==1);
assign add_data_sel  = (state_cal_res && stage_cnt>4);

assign add_sel = (add_diff_sel || add_sum_sel || add_param_sel || add_data_sel);

assign mul_sat_diff_sel = (state_diff_sum && stage_cnt==1) || (state_cal_res && ~cal_res_skip && stage_cnt ==2); 
assign mul_sat_cal_sel = (state_cal_res && ~cal_res_skip && stage_cnt ==3 && exp_result_vld) || (state_cal_res && cal_res_skip && stage_cnt ==2);   // todo cal skip

assign mul_sat_sel = (mul_sat_diff_sel || mul_sat_cal_sel);

assign mult64_sel = (state_cal_res && ~cal_res_skip && stage_cnt == 4); // todo
assign add64_sel = (state_cal_res && ~cal_res_skip && stage_cnt == 5); // todo

assign mult_sel = 0;
endmodule

