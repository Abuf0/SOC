module layernorm #(
    parameter ADDR_WD = 32              ,
    parameter DATA_WB  = 8              ,
    parameter DATA_WD = DATA_WB * 8     ,
    parameter CADDR_WD = 32             ,
    parameter CDATA_WB = 17             ,
    parameter CDATA_WD = CDATA_WB * 8
) (
    input                       clk                 ,
    input                       rstn                ,
    /* config */
    input [ADDR_WD-1:0]         rg_src_data_base    ,
    input [ADDR_WD-1:0]         rg_dest_data_base   ,
    input [CADDR_WD-1:0]        rg_coef_base        ,
    input [7:0]                 rg_batch            ,
    input [15:0]                rg_inh              ,
    input [15:0]                rg_inw              ,
    input [15:0]                rg_inc              ,
    input [15:0]                rg_outh             ,
    input [15:0]                rg_outw             ,
    input [15:0]                rg_outc             ,
    input [7:0]                 rg_inzp             ,
    input [7:0]                 rg_outzp            ,
    input [31:0]                rg_normsize         ,
    input                       rg_actvale          ,
    /* DATA MEM interface */
    output logic                data_mem_rd         ,
    output logic                data_mem_wr         ,
    output logic [DATA_WB-1:0]  data_mem_wmask      ,
    output logic [ADDR_WD-1:0]  data_mem_addr       ,
    output logic [DATA_WD-1:0]  data_mem_wdata      ,
    input [DATA_WD-1:0]         data_mem_rdata      ,
    /* COEF MEM interface */
    output logic                coef_mem_rd         ,
    output logic                coef_mem_wr         ,
    output logic [CDATA_WB-1:0] coef_mem_wmask      ,
    output logic [CADDR_WD-1:0] coef_mem_addr       ,
    output logic [CDATA_WD-1:0] coef_mem_wdata      ,
    input [CDATA_WD-1:0]        coef_mem_rdata      ,
    /* control */
    input                       layernorm_start     ,
    output logic                layernorm_fail      ,
    output logic                layernorm_done        
);
parameter INT32_WD = 32;
parameter INT64_WD = 64;
parameter OFFSET = $clog2(DATA_WB);
parameter PIPE_TIME = 8;
parameter SHIFT_N = 24;
parameter EPS = 168;
parameter ACTMIN = 0;
parameter ACTMAX = 255;

logic init_done;
logic last_loop_end;
logic last_loop_wait_end;
logic loop_end;
logic wait_end;
logic sum_lat;
logic sqsum_lat;
logic param_done;
logic layernorm_on;
logic config_fail;

logic state_init;
logic state_loop;
logic state_param;
logic state_wait;

logic [2:0] tcnt;
logic [15:0] pre_cnt;
logic [15:0] post_cnt;
logic [15:0] c_cnt;
logic [15:0] h_cnt;
logic [15:0] w_cnt;
logic [7:0] batch_cnt;
logic [2:0] param_stage_cnt;

logic [OFFSET:0] pre_cnt_delta;
logic [OFFSET:0] pre_cnt_delta_pre;
logic [OFFSET:0] post_cnt_delta;

logic t_end;
logic pre_loop_end;
logic post_loop_end;
logic pp_loop_end;
logic c_loop_end;
logic h_loop_end;
logic w_loop_end;
logic frame_loop_end;
logic batch_loop_end;
logic param_stage_end;

logic first_loop;
logic last_loop;
logic last_batch;
logic first_tcnt_loop;
logic first_wait_loop;
logic wait_no_write;

logic [15:0] c_num;
logic [1:0] param_stage_num;

logic data_in_vld;
logic param_div_start;
            
logic                 div_in_vld  ;
logic [INT32_WD-1:0]  dividend    ;
logic [INT32_WD-1:0]  divisor     ;
logic [INT32_WD-1:0]  div_result  ;
logic [INT32_WD-1:0]  remainder   ;
logic                 div_out_vld ;
                                                            
logic [INT64_WD-1:0]  sqrt_in     ;        
logic [INT32_WD-1:0]  sqrt_out    ;
logic                 sqrt_in_vld ;
logic                 sqrt_out_vld;

logic [INT32_WD-1:0] size_inv;
logic [INT32_WD-1:0] sqrt_inv;
logic signed [INT64_WD-1:0] mean;
logic signed [INT64_WD-1:0] mean_mod;
logic signed [INT64_WD-1:0] mean_pow2;
logic signed [INT64_WD-1:0] var_value;
logic signed [INT32_WD-1:0] sum;
logic signed [INT64_WD-1:0] sqsum;

logic [DATA_WD-1:0] puchin_lat;
logic [7:0] puchin [0:DATA_WB-1];
logic [DATA_WD-1:0] puchin_cal_lat;
logic [7:0] puchin_cal [0:DATA_WB-1];
logic signed [INT32_WD-1:0] puchin_cal_mean;
logic [CDATA_WD-1:0] param_lat;

logic signed [INT32_WD-1:0] puchin_mod;
logic signed [INT32_WD-1:0] puchin_mod_pow2;
logic signed [INT64_WD-1:0] mult_coef;
logic signed [INT64_WD-1:0] mult;
logic signed [INT64_WD-1:0] puchout_mod;
logic signed [INT32_WD-1:0] puchout_int32;
logic [8-1:0] puchout;
logic [DATA_WD-1:0] puchout_merge;
logic [DATA_WD-1:0] puchmod_merge;

logic signed [INT64_WD-1:0] multsc;
logic signed [INT64_WD-1:0] mulbzp;
logic signed [8-1:0] puchshift;
logic signed [INT64_WD-1:0] mulbzp_d1;
logic signed [8-1:0] puchshift_d1;
logic signed [INT64_WD-1:0] mulbzp_d2;
logic signed [8-1:0] puchshift_d2;

logic [7:0] puchout_min;
logic [7:0] puchout_tmp;
logic [DATA_WD-1:0] data_mem_addr_pre;
logic [DATA_WD-1:0] data_mem_addr_post;
logic [DATA_WD-1:0] data_mem_addr_pre_next;
logic [DATA_WD-1:0] data_mem_addr_post_next;

logic [15:0] total_pre_cnt;
logic [15:0] pre_cnt_next;
logic [15:0] total_post_cnt;
logic [15:0] total_post_cnt_d1;
logic [15:0] total_post_cnt_next;
logic [15:0] post_cnt_next;
logic [15:0] index_head_pre;
logic [15:0] index_head_post;
logic pre_stall;
logic post_stall;
logic pre_stall_d1;
logic post_stall_d1;

typedef enum logic [2:0] {IDLE, INIT, LOOP, WAIT, PARAM, DONE, FAIL} state_t;
state_t state_c, state_n;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        state_c <= IDLE;
    else 
        state_c <= state_n;
end
always@(*) begin
    state_n = state_c;
    case(state_c)
        IDLE:   state_n = layernorm_start?  INIT : IDLE;
        INIT:   state_n = init_done?    (config_fail?  FAIL : LOOP) : INIT;
        LOOP:   state_n = loop_end?         WAIT : LOOP;
        WAIT:   state_n = wait_end?  (last_loop_wait_end?    DONE : PARAM) : WAIT;
        PARAM:  state_n = param_done?   LOOP : PARAM;
        DONE:   state_n = IDLE;
        FAIL:   state_n = IDLE;
        default:state_n = state_c;
    endcase
end

assign state_init = (state_c == INIT);
assign state_loop = (state_c == LOOP);
assign state_param = (state_c == PARAM);
assign state_wait = (state_c == WAIT);
assign layernorm_done = (state_c == DONE);
assign layernorm_fail = (state_c == FAIL);

assign config_fail = (rg_normsize == 0);    // todo confirm others
assign init_done = state_init && div_out_vld;
assign param_done = state_param && div_out_vld;

assign first_loop = state_loop && (c_cnt == 0) && (batch_cnt == 0);
assign last_loop =  state_loop && (c_cnt == c_num-1) && (batch_cnt == rg_batch-1);
assign loop_end = pp_loop_end; // todo
assign last_loop_end = batch_loop_end;  // todo
assign last_batch = state_loop && (batch_cnt == rg_batch-1);
assign first_tcnt_loop = state_loop && (post_cnt == 0);
assign first_wait_loop = state_wait && (c_cnt == 1) && (batch_cnt == 0);

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        last_loop_wait_end <= 1'b0;
    else if(last_loop_end)
        last_loop_wait_end <= 1'b1;
    else if(layernorm_done || layernorm_fail)
        last_loop_wait_end <= 1'b0;
end
// todo
// loop_end 
// last_loop_end 

assign t_end = state_loop && (tcnt == PIPE_TIME-1);
assign wait_end = state_wait && (tcnt == 5);
always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        tcnt <= 'd0;
    else if(state_loop)
        tcnt <= t_end?    'd0 : (tcnt + 1);
    else if(state_wait)
        tcnt <= wait_end?    'd0 : (tcnt + 1);
end

assign pp_loop_end = t_end && ((pre_cnt_next >= rg_normsize) || last_loop) && ((post_cnt_next >= rg_normsize) || first_loop);
assign pre_stall = (pre_cnt_next >= rg_normsize) && (post_cnt_next < rg_normsize) && ~first_loop;
assign post_stall = (pre_cnt_next < rg_normsize) && (post_cnt_next >= rg_normsize) && ~last_loop;

assign pre_loop_end = t_end && (pre_cnt_next >= rg_normsize);
always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        pre_cnt <= 'd0;
    else if(t_end && ~last_loop && ~pre_stall)
        pre_cnt <= pre_loop_end?    'd0 : pre_cnt_next;
end
assign pre_cnt_next = pre_cnt + pre_cnt_delta;
assign pre_cnt_delta = DATA_WB - total_pre_cnt[OFFSET-1:0];
//assign pre_cnt_delta_pre = DATA_WB - total_pre_cnt[OFFSET-1:0];
//assign pre_cnt_delta = (pre_cnt + pre_cnt_delta_pre >= rg_normsize)?   (rg_normsize - pre_cnt) : pre_cnt_delta_pre;

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        index_head_pre <= 'd0;
    else if(layernorm_start)
        index_head_pre <= 'd0;
    else if(pre_loop_end && ~pre_stall)
        index_head_pre <= index_head_pre + rg_normsize;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        total_pre_cnt <= 'd0;
    else if(layernorm_start)
        total_pre_cnt <= 'd0;
    else if(t_end && ~last_loop && ~pre_stall)
        total_pre_cnt <= pre_loop_end?    (index_head_pre + rg_normsize) : ({(total_pre_cnt[15:OFFSET]+1),{OFFSET{1'b0}}});
end

assign post_loop_end = t_end && (post_cnt_next >= rg_normsize);
always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        post_cnt <= 'd0;
    else if(t_end && ~first_loop && ~post_stall)
        post_cnt <= post_loop_end?    'd0 : post_cnt_next;
end
assign post_cnt_next = post_cnt + post_cnt_delta;
assign post_cnt_delta = DATA_WB - total_post_cnt[OFFSET-1:0];

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        index_head_post <= 'd0;
    else if(layernorm_start)
        index_head_post <= 'd0;
    else if(post_loop_end && ~post_stall)
        index_head_post <= index_head_post + rg_normsize;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        total_post_cnt <= 'd0;
    else if(layernorm_start)
        total_post_cnt <= 'd0;
    else if(t_end && ~first_loop && ~post_stall)
        total_post_cnt <= total_post_cnt_next;
end

// todo pre cal
assign total_post_cnt_next = post_loop_end?    (index_head_post + rg_normsize) : ({(total_post_cnt[15:OFFSET]+1),{OFFSET{1'b0}}});

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        total_post_cnt_d1 <= 'd0;
    else if(t_end)
        total_post_cnt_d1 <= total_post_cnt;
end

assign c_num = last_batch?  (rg_inc * rg_inw * rg_inh / rg_normsize + 1) : (rg_inc * rg_inw * rg_inh / rg_normsize);  // todo
assign c_loop_end = pp_loop_end && (c_cnt == c_num-1);  // todo
always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        c_cnt <= 'd0;
    else if(pp_loop_end)
        c_cnt <= c_loop_end?    'd0 : (c_cnt + 1);
end

assign batch_loop_end = c_loop_end && (batch_cnt == rg_batch-1);
always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        batch_cnt <= 'd0;
    else if(c_loop_end)
        batch_cnt <= batch_loop_end?    'd0 : (batch_cnt + 1);
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        puchout_min <= 'd0;
    else if(layernorm_start)   
        puchout_min <= rg_actvale?  rg_outzp : ACTMIN;
end

//genvar i;
//generate
//    for(i==0; i < DATA_WB; i=i+1) begin
//        assign puchin[i+2] = puchin_lat[i*8+7:i*8];
//    end
//endgenerate

logic [DATA_WB-1:0] puchin_mask;
logic [DATA_WB-1:0] puchout_mask;
logic [DATA_WB-1:0] puchout_mask_d1;

assign puchin[1] = puchin_mask[6]?   puchin_lat[6*8+7:6*8] : rg_inzp;
assign puchin[2] = puchin_mask[7]?   puchin_lat[7*8+7:7*8] : rg_inzp;
assign puchin[3] = puchin_mask[0]?   puchin_lat[0*8+7:0*8] : rg_inzp;
assign puchin[4] = puchin_mask[1]?   puchin_lat[1*8+7:1*8] : rg_inzp;
assign puchin[5] = puchin_mask[2]?   puchin_lat[2*8+7:2*8] : rg_inzp;
assign puchin[6] = puchin_mask[3]?   puchin_lat[3*8+7:3*8] : rg_inzp;
assign puchin[7] = puchin_mask[4]?   puchin_lat[4*8+7:4*8] : rg_inzp;
assign puchin[0] = puchin_mask[5]?   puchin_lat[5*8+7:5*8] : rg_inzp;

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        puchin_lat <= 'd0;
    else if(state_loop && tcnt == 2)
        puchin_lat <= data_mem_rdata;
end

genvar k;
generate 
    for(k=0; k<DATA_WB; k=k+1) begin
        always_ff @( posedge clk or negedge rstn ) begin
            if(~rstn)
                puchin_mask[k] <= 1'b1;
            else if((state_loop && tcnt == 2) || init_done) begin
                if((pre_cnt + k >= rg_normsize) || (k < total_pre_cnt[OFFSET-1:0]) || pre_stall_d1)
                    puchin_mask[k] <= 1'b0;
                else 
                    puchin_mask[k] <= 1'b1;
            end
        end
        always_ff @( posedge clk or negedge rstn ) begin
            if(~rstn)
                puchout_mask[k] <= 1'b1;
            else if(state_loop && tcnt == 1) begin
                if((post_cnt + k >= rg_normsize) || (k < total_post_cnt[OFFSET-1:0]))
                    puchout_mask[k] <= 1'b0;
                else 
                    puchout_mask[k] <= 1'b1;
            end
        end
    end
endgenerate

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        pre_stall_d1 <= 1'b0;
    else if((state_loop || state_wait) && t_end)
        pre_stall_d1 <= pre_stall;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        post_stall_d1 <= 1'b0;
    else if((state_loop || state_wait) && t_end)
        post_stall_d1 <= post_stall;
end


always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        puchout_mask_d1 <= {DATA_WB{1'b1}};
    else if((state_loop || state_wait) && tcnt == 1)
        puchout_mask_d1 <= puchout_mask;
end

assign sum_lat = state_wait && (tcnt >= 4);
assign sqsum_lat = wait_end;

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        puchin_mod <= 'sd0;
    else if(param_done)
        puchin_mod <= 'sd0;
    else if((state_loop && ~(pre_cnt==0 && (tcnt < 3))) || (state_wait && ~sum_lat)) begin
        puchin_mod <= puchin[tcnt] - rg_inzp;  // ADD32
    end
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        puchmod_merge <= 'sd0;
    else if(state_loop)
        puchmod_merge <= {puchin_mod, puchmod_merge[DATA_WD-1:8]};
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        sum <= 'sd0;
    else if(param_done)
        sum <= 'sd0;
    else if(state_loop || (state_wait && ~sum_lat)) begin
        sum <= sum + puchin_mod;    // ADD32
    end
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        puchin_mod_pow2 <= 'sd0;
    else if(param_done)
        puchin_mod_pow2 <= 'sd0;
    else if(state_loop || (state_wait && ~sum_lat)) begin
        puchin_mod_pow2 <= puchin_mod * puchin_mod; // MULT32X32
    end
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        sqsum <= 'sd0;
    else if(param_done)
        sqsum <= 'sd0;
    else if(state_loop || (state_wait && ~sqsum_lat)) begin
        sqsum <= sqsum + puchin_mod_pow2;    // ADD64
    end
end

assign param_stage_end = state_param && div_out_vld;//(param_stage_cnt == param_stage_num-1);
always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        param_stage_cnt <= 'd0;
    else if(state_param) begin
        if(param_stage_cnt < 4 || sqrt_out_vld)   
            param_stage_cnt <= (param_stage_cnt + 1);   
        else if(param_stage_end)
            param_stage_cnt <= 'd0;
    end
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        mean <= 'sd0;
    else if(state_param && param_stage_cnt == 0)  
        mean <= sum * size_inv; // MULT32X32
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        mean_mod <= 'sd0;
    else if(state_param && param_stage_cnt == 1)  
        mean_mod <= (mean >>> (SHIFT_N >> 1)) + (rg_inzp <<< (SHIFT_N >> 1)); // ADD32
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        mean_pow2 <= 'sd0;
    else if(state_param && param_stage_cnt == 1)  
        mean_pow2 <= mean * mean;   // MULT64X64
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        var_value <= 'sd0;
    else if(state_param) begin
        if(param_stage_cnt == 0)
            var_value <= sqsum * size_inv;    // MULT64X32
        else if(param_stage_cnt == 2)
            var_value <= var_value - (mean_pow2 >>> SHIFT_N);    // ADD64
    end
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        sqrt_in_vld <= 1'b0;
    else if(state_param && param_stage_cnt == 3)  
        sqrt_in_vld <= 1'b1;
    else
        sqrt_in_vld <= 1'b0;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        sqrt_in <= 'd0;
    else if(state_param && param_stage_cnt == 3)  
        sqrt_in <= var_value + EPS;
end

assign param_div_start = (state_param && sqrt_out_vld);   
always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        div_in_vld <= 1'b0;
    else if(layernorm_start || param_div_start)  
        div_in_vld <= 1'b1;
    else
        div_in_vld <= 1'b0;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        dividend <= 'd0;
    else if(layernorm_start || param_div_start)   
        dividend <= ( 1 << SHIFT_N );
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        divisor <= 'd0;
    else if(layernorm_start)   
        divisor <= rg_normsize;
    else if(param_div_start)    
        divisor <= sqrt_out;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        size_inv <= 'd0;
    else if(init_done)   
        size_inv <= div_result;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        sqrt_inv <= 'd0;
    else if(param_done)   
        sqrt_inv <= div_result;
end

//genvar j;
//generate
//    for(j==0; j < DATA_WB; j=j+1) begin
//        assign puchin_cal[j+1] = puchin_cal_lat[j*8+7:j*8];
//
//    end
//endgenerate
assign puchin_cal[0] = puchin_cal_lat[6*8+7:6*8];
assign puchin_cal[1] = puchin_cal_lat[7*8+7:7*8];
assign puchin_cal[2] = puchin_cal_lat[0*8+7:0*8];
assign puchin_cal[3] = puchin_cal_lat[1*8+7:1*8];
assign puchin_cal[4] = puchin_cal_lat[2*8+7:2*8];
assign puchin_cal[5] = puchin_cal_lat[3*8+7:3*8];
assign puchin_cal[6] = puchin_cal_lat[4*8+7:4*8];
assign puchin_cal[7] = puchin_cal_lat[5*8+7:5*8];

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        puchin_cal_lat <= 'sd0;
    else if(state_loop && tcnt == 1)
        puchin_cal_lat <= data_mem_rdata;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        puchin_cal_mean <= 'sd0;
    else if(wait_end)
        puchin_cal_mean <= 'sd0;
    else if((state_loop && ~(post_cnt==0 && (tcnt<2))) || state_wait) begin
        puchin_cal_mean <= (puchin_cal[tcnt] <<< (SHIFT_N >> 1)) - mean_mod;  // ADD32
    end
end

//assign multsc = 100;  //param_lat[135:72];
//assign mulbzp = 0;  //param_lat[71:8];
//assign puchshift = 0;   //param_lat[7:0];

assign multsc = param_lat[135:72];
assign mulbzp = param_lat[71:8];
assign puchshift = param_lat[7:0];

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        param_lat <= 'sd0;
    else if(state_loop || state_wait)
        param_lat <= coef_mem_rdata;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        mulbzp_d1 <= 'sd0;
    else if(state_loop || state_wait)
        mulbzp_d1 <= mulbzp;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        mulbzp_d2 <= 'sd0;
    else if(state_loop || state_wait)
        mulbzp_d2 <= mulbzp_d1;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        puchshift_d1 <= 'sd0;
    else if(state_loop || state_wait)
        puchshift_d1 <= puchshift;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        puchshift_d2 <= 'sd0;
    else if(state_loop || state_wait)
        puchshift_d2 <= puchshift_d1;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        mult_coef <= 'sd0;
    else if(state_loop || state_wait)
        mult_coef <= multsc * sqrt_inv; // MULT64X32
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        mult <= 'sd0;
    else if(state_loop || state_wait)
        mult <= mult_coef * puchin_cal_mean; // MULT64X64
end

assign puchout_mod = (((mult >>> SHIFT_N) + mulbzp_d2) >>> puchshift_d2);   // ADD64
assign puchout_int32 = {puchout_mod[INT64_WD-1], puchout_mod[INT32_WD-2:0]};

assign puchout = (puchout_int32 < $signed(puchout_min))?  puchout_min :
                (puchout_int32 > ACTMAX)?       ACTMAX : puchout_int32;

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        puchout_merge <= 'sd0;
    else if(state_loop || state_wait)
        puchout_merge <= {puchout, puchout_merge[DATA_WD-1:8]};
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        wait_no_write <= 1'b0;
    else if(state_loop || state_wait) begin
        if(wait_end)
            wait_no_write <= 1'b0;
        else if(post_stall)
            wait_no_write <= 1'b1;
        else if(pre_stall)
            wait_no_write <= 1'b0;
    end
end

// Data memory interface //
always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        data_mem_rd <= 1'b0;
    else if((state_loop && (tcnt == 0 || tcnt ==  PIPE_TIME-1)) || param_done)
        data_mem_rd <= 1'b1;
    else 
        data_mem_rd <= 1'b0;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        data_mem_wr <= 1'b0;
    else if(((state_loop && ~first_tcnt_loop && ~first_loop) || (state_wait && ~first_wait_loop && ~wait_no_write)) && (tcnt == 3))
        data_mem_wr <= 1'b1;// todo 1
    else 
        data_mem_wr <= 1'b0;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        data_mem_addr <= 'd0;
    else if(layernorm_start)
        data_mem_addr <= (rg_src_data_base >> OFFSET);
    else if(state_loop && (tcnt == 0))
        data_mem_addr <= ((rg_src_data_base + total_pre_cnt)>> OFFSET);
    else if(state_loop && (tcnt == PIPE_TIME-1) || param_done) begin
        if(t_end && ~first_loop && ~post_stall)
            data_mem_addr <= ((rg_src_data_base + total_post_cnt_next)>> OFFSET);   // todo
        else
            data_mem_addr <= ((rg_src_data_base + total_post_cnt)>> OFFSET); 
    end
    else if(((state_loop && ~first_tcnt_loop && ~first_loop) || (state_wait && ~first_wait_loop && ~wait_no_write)) && tcnt == 3)
        data_mem_addr <= ((rg_dest_data_base + total_post_cnt_d1)>> OFFSET);
    // todo
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        data_mem_wdata <= 'd0;
    else if(((state_loop && ~first_tcnt_loop && ~first_loop) || (state_wait && ~first_wait_loop && ~wait_no_write))) begin
        //if(tcnt == 2)
        //    data_mem_wdata <= {puchin_mod, puchmod_merge[DATA_WD-1:8]};
        //else if(tcnt == 3)
        if(tcnt == 3)
            data_mem_wdata <= {puchout, puchout_merge[DATA_WD-1:8]};
    end
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        data_mem_wmask <= {DATA_WB{1'b1}};
    else if(((state_loop && ~first_tcnt_loop && ~first_loop) || (state_wait && ~first_wait_loop && ~wait_no_write)) && tcnt == 3) begin
        data_mem_wmask <= puchout_mask_d1; // todo
    end
end

// Coef memory interface //
assign coef_mem_wr = 1'b0;
assign coef_mem_wmask = 'd0;
assign coef_mem_wdata = 'd0;

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        coef_mem_rd <= 1'b0;
    //else if((post_cnt + tcnt + 1 > rg_normsize-1) || (tcnt + 1 >= post_cnt_delta[OFFSET-1:0]))
    //    coef_mem_rd <= 1'b0;
    //else if(((state_loop && (tcnt ==  PIPE_TIME-1) && (tcnt + 1 < total_post_cnt_next[OFFSET-1:0]) && ~post_loop_end) || param_done) && ~first_loop) // todo with first loop
    //    coef_mem_rd <= 1'b1;
    else if((post_cnt + tcnt + 1 > rg_normsize-1) || ( (|total_post_cnt[OFFSET-1:0]) && (tcnt + 1 < total_post_cnt[OFFSET-1:0])))
        coef_mem_rd <= 1'b0;
    else if(param_done && (total_post_cnt[OFFSET-1:0] == 1))
        coef_mem_rd <= 1'b0;
    else if(~first_loop && (state_loop || param_done))
        coef_mem_rd <= 1'b1;
    //    ((post_cnt + k >= rg_normsize) || (k < total_post_cnt[OFFSET-1:0]))
    //else if(wait_end)
    //    coef_mem_rd <= 1'b0;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        coef_mem_addr <= 'd0;
    else if(layernorm_start || post_loop_end)
        coef_mem_addr <= rg_coef_base;
    //else if(state_loop && ~first_loop && ~post_stall_d1) begin
    //    if(puchout_mask[tcnt])
    //        coef_mem_addr <= (coef_mem_addr == (rg_coef_base + rg_normsize - 1))?   rg_coef_base : coef_mem_addr + 1;   // todo pre cal
    //end
    //else if((t_end & ~first_loop) || (wait_end && ~first_wait_loop)) begin
    //    if(post_cnt_next >= rg_normsize)
    //        coef_mem_addr <= rg_coef_base;
    //    else 
    //        coef_mem_addr <= rg_coef_base + {post_cnt_next[15:OFFSET], {OFFSET{1'b0}}};
    //end
    else if(coef_mem_rd) // else if(coef_mem_rd && c_loop_end) // todo with parameter size
        coef_mem_addr <= coef_mem_addr + 1'b1;
end    


divider_u32 #(
    .DATA_WD(INT32_WD)
) u_divider_u32 (
    .clk         ( clk          ),
    .rstn        ( rstn         ),
    .div_in_vld  ( div_in_vld   ),
    .dividend    ( dividend     ),
    .divisor     ( divisor      ),
    .div_result  ( div_result   ),
    .remainder   ( remainder    ),
    .div_out_vld ( div_out_vld  )
);

sqrtu64 #(
    .DATA_WD ( INT64_WD ))
 u_sqrtu64 (
    .clk           ( clk                ),
    .rstn          ( rstn               ),
    .sqrt_in_vld   ( sqrt_in_vld        ),
    .sqrt_in       ( sqrt_in            ),
    .sqrt_out      ( sqrt_out           ),
    .sqrt_out_vld  ( sqrt_out_vld       )
);

endmodule