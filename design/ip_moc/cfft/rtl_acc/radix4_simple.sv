module radix4_simple#(
    parameter ADDR_WIDTH = 17,
    parameter DATA_WIDTH = 32
)(
    input                               clk                 ,
    input                               rstn                ,
    /**************** control ****************/
    input                               fft_start           ,
    input                               pre_start           ,
    input                               post_start          ,
    input                               reverse_start       ,
    /**************** config ****************/
    input        [11:0]                 rg_bitrevlen        ,
    input        [15:0]                 fft_len             ,   // = 4^M
    input        [15:0]                 rg_twid             ,
    input                               rg_ifft_flag        ,
    input                               rg_bitreverse_flag  ,
    input        [ADDR_WIDTH-1:0]       src_data_base       ,
    input        [ADDR_WIDTH-1:0]       dest_data_base      ,
    input                               switch_flag         ,
    input signed [ADDR_WIDTH-1:0]       data_base_offset    ,
    input signed [DATA_WIDTH-1:0]       cos_val_1           ,
    input signed [DATA_WIDTH-1:0]       sin_val_1           ,
    input signed [DATA_WIDTH-1:0]       cos_val_2           ,
    input signed [DATA_WIDTH-1:0]       sin_val_2           ,
    input signed [DATA_WIDTH-1:0]       cos_val_3           ,
    input signed [DATA_WIDTH-1:0]       sin_val_3           ,
    input                               need_post           ,
    /**************** data memory interface ****************/
    input        [DATA_WIDTH-1:0]       data_rdata          ,
    output logic [DATA_WIDTH-1:0]       data_wdata          ,
    output logic [DATA_WIDTH/8-1:0]     data_wmask          ,
    output logic                        data_wr             ,
    output logic                        data_rd             ,
    output logic [ADDR_WIDTH-1:0]       data_addr           ,
    /***************** wn memory interface *****************/
    input        [DATA_WIDTH-1:0]       wn_rdata            ,
    /***************** MULT1 interface *********************/
    output logic signed [DATA_WIDTH-1:0]    mult1_a             ,
    output logic signed [DATA_WIDTH-1:0]    mult1_b             ,
    input signed [2*DATA_WIDTH-1:0]         mult1_res           ,
    /***************** MULT2 interface *********************/
    output logic signed [DATA_WIDTH-1:0]    mult2_a             ,
    output logic signed [DATA_WIDTH-1:0]    mult2_b             ,
    input signed [2*DATA_WIDTH-1:0]         mult2_res           ,
    /***************** MULT1 interface *********************/
    output logic signed [DATA_WIDTH-1:0]    mult3_a             ,
    output logic signed [DATA_WIDTH-1:0]    mult3_b             ,
    input signed [2*DATA_WIDTH-1:0]         mult3_res           ,
    /***************** MULT2 interface *********************/
    output logic signed [DATA_WIDTH-1:0]    mult4_a             ,
    output logic signed [DATA_WIDTH-1:0]    mult4_b             ,
    input signed [2*DATA_WIDTH-1:0]         mult4_res           ,
    /***************** ADD1 interface *********************/
    output logic signed [DATA_WIDTH-1:0]    add1_a              ,
    output logic signed [DATA_WIDTH-1:0]    add1_b              ,
    input signed [DATA_WIDTH-1:0]           add1_sum            ,
    /***************** ADD2 interface *********************/
    output logic signed [DATA_WIDTH-1:0]    add2_a              ,
    output logic signed [DATA_WIDTH-1:0]    add2_b              ,
    input signed [DATA_WIDTH-1:0]           add2_sum            ,
    /***************** ADD3 interface *********************/
    output logic signed [DATA_WIDTH-1:0]    add3_a              ,
    output logic signed [DATA_WIDTH-1:0]    add3_b              ,
    input signed [DATA_WIDTH-1:0]           add3_sum           
);
parameter RADIX = 4;    // fixed
parameter PIPE_TIME = 20;
parameter PRE_TIME = 10;
parameter POST_TIME = 4;
parameter REV_TIME = 5;

logic stage_loop_end;   // for one state switch
logic [2:0] stage_num;// 16,...,4096 = 2,...,6 // stage num in one state
logic [2:0] stage_cnt; // for middile stage counter// 0,1,2,3,4 // for start&last = 0
logic group_loop_end;   // for one stage switch
logic [11:0] group_num;  // group num in one group
logic [11:0] group_loop_cnt; // for group in one stage // 0~N/4-1
logic radix_loop_end;   // for one group switch
logic [11:0] radix_num;  // radix num in one group
logic [11:0] radix_loop_cnt; // for radix in one group // 0~N/4-1
logic tcnt_loop_end;   // for one radix 4 swith
logic [4:0] tcnt_num;   // tcnt num in one radix
logic [4:0] tcnt;  // for wn 0~5// for data 0~7 

logic single_loop_end;  // pre/post/rev end
logic [12:0] single_num;


logic state_radix4;
logic state_pre;
logic state_post;
logic state_rev;

logic first_stage_done;
logic middile_stage_done;
logic last_stage_done;
logic wait_done;
logic pre_stage_done;
logic post_stage_done;
logic rev_stage_done;

logic last_stage_last_radix;
logic last_stage_first_radix;
logic first_stage_first_radix;
logic middle_stage_first_radix;
logic first_radix;
logic pipe_flag;

logic wn_rd_d1;

logic post_stage_last_radix;

logic [15:0] step;
logic [15:0] strid;
logic [15:0] twid;

logic signed [DATA_WIDTH-1:0] mult1_res_sat_shift32;
logic signed [DATA_WIDTH-1:0] mult2_res_sat_shift32;


logic signed [DATA_WIDTH-1:0] result;

assign mult1_res_sat_shift32 = mult1_res[DATA_WIDTH-1]?  (mult1_res >>> DATA_WIDTH)+1'b1 : (mult1_res >>> DATA_WIDTH);
assign mult2_res_sat_shift32 = mult2_res[DATA_WIDTH-1]?  (mult2_res >>> DATA_WIDTH)+1'b1 : (mult2_res >>> DATA_WIDTH);


// FSM
typedef enum logic  [3:0] {IDLE, FIRST_STAGE, MIDDLE_STAGE, LAST_STAGE,PRE_STAGE,POST_STAGE,REV_STAGE} state_t;
state_t state_c,state_n;

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        state_c <= IDLE;
    else 
        state_c <= state_n;
end

always @(*) begin
    state_n = state_c;
    case(state_c) 
        IDLE:         state_n = fft_start?              FIRST_STAGE :
                                pre_start?              PRE_STAGE :
                                post_start?             POST_STAGE :
                                reverse_start?          REV_STAGE : IDLE;
        FIRST_STAGE : state_n = first_stage_done?       ((stage_num == 2)?   LAST_STAGE : MIDDLE_STAGE) : FIRST_STAGE;
        MIDDLE_STAGE: state_n = middile_stage_done?     LAST_STAGE : MIDDLE_STAGE;
        LAST_STAGE :  state_n = last_stage_done?        IDLE : LAST_STAGE;
        PRE_STAGE :   state_n = pre_stage_done?         IDLE : PRE_STAGE;
        POST_STAGE :  state_n = post_stage_done?        IDLE : POST_STAGE;
        REV_STAGE :   state_n = rev_stage_done?         IDLE : REV_STAGE;
        default :     state_n = state_c;
    endcase
end

assign first_stage_done = group_loop_end && (state_c == FIRST_STAGE);
assign middile_stage_done = group_loop_end && (stage_num != 2) && (stage_cnt == stage_num-2) && (state_c == MIDDLE_STAGE);
assign last_stage_done = group_loop_end && (state_c == LAST_STAGE);    
assign pre_stage_done = single_loop_end && (state_c == PRE_STAGE);
assign post_stage_done = single_loop_end && (state_c == POST_STAGE);
assign rev_stage_done = single_loop_end && (state_c == REV_STAGE);

assign state_radix4 = (state_c == FIRST_STAGE || state_c == MIDDLE_STAGE || state_c == LAST_STAGE);
assign state_pre = (state_c == PRE_STAGE);
assign state_post = (state_c == POST_STAGE);
assign state_rev = (state_c == REV_STAGE);

assign last_stage_last_radix = (state_c == LAST_STAGE) && (radix_loop_cnt == radix_num-1) && (group_loop_cnt == group_num-1);
assign last_stage_first_radix = (state_c == LAST_STAGE) && (radix_loop_cnt == 0) && (group_loop_cnt == group_num-1);
assign first_stage_first_radix = (state_c == FIRST_STAGE) && (radix_loop_cnt == 0) && (group_loop_cnt == 0);
assign first_radix = (radix_loop_cnt == 0) && (group_loop_cnt == 0);
assign middle_stage_first_radix = (state_c == MIDDLE_STAGE) && (stage_cnt == 1) && (radix_loop_cnt == 0) && (group_loop_cnt == 0);
assign post_stage_last_radix = (state_c == POST_STAGE) && (radix_loop_cnt == single_num-1);

assign tcnt_num = state_radix4?  PIPE_TIME : 
                  state_pre?    PRE_TIME : 
                  state_post?   POST_TIME : 
                  state_rev?    REV_TIME : PIPE_TIME;  
assign radix_num = strid;
assign group_num = step;
assign single_num = state_pre?  fft_len : 
                    state_post? (fft_len << 1) :
                    state_rev?  (rg_bitrevlen+1'b1) : 2;

assign tcnt_loop_end = (tcnt == tcnt_num-1);
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        tcnt <= 'd0;
    else if(state_c != IDLE)
        tcnt <= tcnt_loop_end?   'd0 : (tcnt+1'b1);
end

assign radix_loop_end = state_radix4 && tcnt_loop_end && (radix_loop_cnt == radix_num-1);
assign single_loop_end = ~state_radix4 && tcnt_loop_end && (radix_loop_cnt == single_num-1);
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        radix_loop_cnt <= 'd0;
    else if(tcnt_loop_end) begin
        if(state_radix4)
            radix_loop_cnt <= radix_loop_end?   'd0 : (radix_loop_cnt+1'b1);
        else
            radix_loop_cnt <= single_loop_end?   'd0 : (radix_loop_cnt+1'b1);
    end
end

assign group_loop_end = radix_loop_end && (group_loop_cnt == group_num-1);
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        group_loop_cnt <= 'd0;
    else if(radix_loop_end)
        group_loop_cnt <= group_loop_end?   'd0 : (group_loop_cnt+1'b1);
end


assign stage_loop_end = group_loop_end && last_stage_done;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        stage_cnt <= 'd0;
    else if(group_loop_end)
        stage_cnt <= stage_loop_end?   'd0 : (stage_cnt+1'b1);
end


//always_ff@(posedge clk or negedge rstn) begin   
//    if(~rstn)
//        fft_done <= 1'b0;
//    else if(state_c == LAST_STAGE && state_n == IDLE)
//        fft_done <= 1'b1;
//    else 
//        fft_done <= 1'b0;
//end
//
//always_ff@(posedge clk or negedge rstn) begin   
//    if(~rstn)
//        pre_done <= 1'b0;
//    else if(state_c == PRE_STAGE && state_n == IDLE)
//        pre_done <= 1'b1;
//    else 
//        pre_done <= 1'b0;
//end
//
//always_ff@(posedge clk or negedge rstn) begin   
//    if(~rstn)
//        post_done <= 1'b0;
//    else if(state_c == POST_STAGE && state_n == IDLE)
//        post_done <= 1'b1;
//    else 
//        post_done <= 1'b0;
//end
//
//always_ff@(posedge clk or negedge rstn) begin   
//    if(~rstn)
//        reverse_done <= 1'b0;
//    else if(state_c == REV_STAGE && state_n == IDLE)
//        reverse_done <= 1'b1;
//    else 
//        reverse_done <= 1'b0;
//end


always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        pipe_flag <= 1'b0;
    else if(tcnt_loop_end && state_radix4)
        pipe_flag <= ~pipe_flag;
    else if(state_c != state_n)
        pipe_flag <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin   // N/4, N/16, N/64, ...
    if(~rstn) begin
        step <= 'd0;
    end
    else if(fft_start) begin
        step <= (fft_len>>2);
    end
    else if(group_loop_end) begin
        step <= (step>>2);
    end
end

always_ff@(posedge clk or negedge rstn) begin   // 1, 4, 16, ...
    if(~rstn) begin
        strid <= 'd0;
    end
    else if(fft_start) begin
        strid <= 1;
    end
    else if(group_loop_end) begin
        strid <= (strid<<2);
    end
end

always_ff@(posedge clk or negedge rstn) begin   
    if(~rstn) begin
        twid <= 'd0;
    end
    else if(fft_start) begin
        twid <= rg_twid;
    end
    else if(group_loop_end) begin
        twid <= (twid<<2);
    end
end

// Caculate Stage //
logic signed [DATA_WIDTH-1:0] signed_rdata_0;
logic signed [DATA_WIDTH-1:0] signed_rdata_1;
logic signed [DATA_WIDTH-1:0] sub_xa_xc;
logic signed [DATA_WIDTH-1:0] add_xa_xc;
logic signed [DATA_WIDTH-1:0] sub_xb_xd;
logic signed [DATA_WIDTH-1:0] add_xb_xd;
logic signed [DATA_WIDTH-1:0] sub_ya_yc;
logic signed [DATA_WIDTH-1:0] add_ya_yc;
logic signed [DATA_WIDTH-1:0] sub_yb_yd;
logic signed [DATA_WIDTH-1:0] add_yb_yd;

logic signed [DATA_WIDTH-1:0] radix_tmp_0;
logic signed [DATA_WIDTH-1:0] radix_tmp_1;
logic signed [DATA_WIDTH-1:0] radix_tmp_2;
logic signed [DATA_WIDTH-1:0] radix_tmp_3;
logic signed [DATA_WIDTH-1:0] radix_tmp_4;
logic signed [DATA_WIDTH-1:0] radix_tmp_5;
logic signed [DATA_WIDTH-1:0] radix_tmp_6;
logic signed [DATA_WIDTH-1:0] radix_tmp_7;

logic signed [DATA_WIDTH-1:0] xc_cos;
logic signed [DATA_WIDTH-1:0] yc_sin;
logic signed [DATA_WIDTH-1:0] yb_cos;
logic signed [DATA_WIDTH-1:0] xb_sin;
logic signed [DATA_WIDTH-1:0] yd_cos;
logic signed [DATA_WIDTH-1:0] xd_sin;
logic signed [DATA_WIDTH-1:0] xb_cos;
logic signed [DATA_WIDTH-1:0] yb_sin;
logic signed [DATA_WIDTH-1:0] xd_cos;
logic signed [DATA_WIDTH-1:0] yd_sin;
logic signed [DATA_WIDTH-1:0] yc_cos;
logic signed [DATA_WIDTH-1:0] xc_sin;

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        signed_rdata_0 <= 'sd0;
    else if(state_radix4) begin
        if(tcnt >=2 && tcnt <= 8 && ~tcnt[0]) 
            signed_rdata_0 <= (state_c == FIRST_STAGE)?   ($signed(data_rdata) >>> 4 ) : $signed(data_rdata);
    end
    else if(state_pre) begin
        if(tcnt == 2 || tcnt == 4)
            signed_rdata_0 <= ($signed(data_rdata) >>> 2 );
        else if(tcnt == 7)
            signed_rdata_0 <= radix_tmp_2;
        else if(tcnt == 8)
            signed_rdata_0 <= radix_tmp_4;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        signed_rdata_1 <= 'sd0;
    else if(state_radix4) begin
        if(tcnt <= 9 && tcnt >=3 && tcnt[0])
            signed_rdata_1 <= (state_c == FIRST_STAGE)?   ($signed(data_rdata) >>> 4 ) : $signed(data_rdata);
    end
    else if(state_pre) begin
        if(tcnt == 3 || tcnt == 5)
            signed_rdata_1 <= ($signed(data_rdata) >>>2 );
        else if(tcnt == 7)
            signed_rdata_1 <= mult2_res_sat_shift32;
        else if(tcnt == 8)
            signed_rdata_1 <= radix_tmp_3;
    end
end

always@(*) begin
    if(~tcnt[0]) begin
        add1_a = signed_rdata_0;
        add1_b = -signed_rdata_1;
    end
    else begin
        if(tcnt == 7) begin
            add1_a = add_xa_xc;
            add1_b = -add_xb_xd;
        end
        else if(tcnt == 9) begin
            add1_a = sub_ya_yc;
            add1_b = -sub_xb_xd;
        end
        else if(tcnt == 11) begin
            add1_a = sub_xa_xc;
            add1_b = -sub_yb_yd;
        end
        else if(tcnt == 13) begin
            add1_a = add_ya_yc;
            add1_b = -add_yb_yd;
        end
        else begin
            add1_a = 'bx;//'sd0;
            add1_b = 'bx;//'sd0;
        end
    end
end

always@(*) begin
    if(~tcnt[0]) begin
        add2_a = signed_rdata_0;
        add2_b = signed_rdata_1;
    end
    else begin
        if(tcnt == 7) begin
            add2_a = add_xa_xc;
            add2_b = add_xb_xd;
        end
        else if(tcnt == 9) begin
            add2_a = sub_ya_yc;
            add2_b = sub_xb_xd;
        end
        else if(tcnt == 11) begin
            add2_a = sub_xa_xc;
            add2_b = sub_yb_yd;
        end
        else if(tcnt == 13) begin
            add2_a = add_ya_yc;
            add2_b = add_yb_yd;
        end
        else begin
            add2_a = 'bx;//'sd0;
            add2_b = 'bx;//'sd0;
        end
    end
end

always@(*) begin
    add3_a = 'bx;   // 'b0;
    add3_b = 'bx;   // 'b0;
    case(tcnt)
        'd9: begin
            add3_a = signed_rdata_0;
            add3_b = rg_ifft_flag?  signed_rdata_1 : -signed_rdata_1;
        end
        'd13: begin
            add3_a = xb_cos;
            add3_b = rg_ifft_flag?  -xb_sin : xb_sin;
        end
        'd15: begin
            add3_a = yb_cos;
            add3_b = rg_ifft_flag?  yb_sin : -yb_sin;
        end
        'd16: begin
            add3_a = xc_cos;
            add3_b = rg_ifft_flag?  -xc_sin : xc_sin;
        end
        'd17: begin
            add3_a = xd_cos;
            add3_b = rg_ifft_flag?  -xd_sin : xd_sin;
        end
        'd18: begin
            add3_a = yc_cos;
            add3_b = rg_ifft_flag?  yc_sin : -yc_sin;
        end
        'd19: begin
            add3_a = yd_cos;
            add3_b = rg_ifft_flag?  yd_sin : -yd_sin;
        end
        default: begin
            add3_a = 'bx;   // 'b0;
            add3_b = 'bx;   // 'b0;
        end
    endcase
end

always@(*) begin
    mult1_a = 'bx;   // 'b0;
    mult1_b = 'bx;   // 'b0;
    case(tcnt)
        'd5,'d7,'d8: begin
            mult1_a = radix_tmp_0;
            mult1_b = cos_val_2;
        end
        'd10: begin
            mult1_a = radix_tmp_2;
            mult1_b = cos_val_1;
        end
        'd12: begin
            mult1_a = radix_tmp_5;
            mult1_b = cos_val_1;
        end
        'd14: begin
            mult1_a = radix_tmp_6;
            mult1_b = cos_val_2;
        end
        default: begin
            mult1_a = 'bx;   // 'b0;
            mult1_b = 'bx;   // 'b0;
        end
    endcase
end

always@(*) begin
    mult2_a = 'bx;   // 'b0;
    mult2_b = 'bx;   // 'b0;
    case(tcnt)
        'd5,'d7,'d8: begin
            mult2_a = radix_tmp_0;
            mult2_b = sin_val_2;
        end
        'd10: begin
            mult2_a = radix_tmp_2;
            mult2_b = sin_val_1;
        end
        'd12: begin
            mult2_a = radix_tmp_5;
            mult2_b = sin_val_1;
        end
        'd14: begin
            mult2_a = radix_tmp_6;
            mult2_b = sin_val_2;
        end
        default: begin
            mult2_a = 'bx;   // 'b0;
            mult2_b = 'bx;   // 'b0;
        end
    endcase
end

always@(*) begin
    mult3_a = 'bx;   // 'b0;
    mult3_b = 'bx;   // 'b0;
    case(tcnt)
        'd10: begin
            mult3_a = radix_tmp_3;
            mult3_b = cos_val_3;
        end
        'd12: begin
            mult3_a = radix_tmp_4;
            mult3_b = cos_val_3;
        end
        default: begin
            mult3_a = 'bx;   // 'b0;
            mult3_b = 'bx;   // 'b0;
        end
    endcase
end

always@(*) begin
    mult4_a = 'bx;   // 'b0;
    mult4_b = 'bx;   // 'b0;
    case(tcnt)
        'd10: begin
            mult4_a = radix_tmp_3;
            mult4_b = sin_val_3;
        end
        'd12: begin
            mult4_a = radix_tmp_4;
            mult4_b = sin_val_3;
        end
        default: begin
            mult4_a = 'bx;   // 'b0;
            mult4_b = 'bx;   // 'b0;
        end
    endcase
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        sub_xa_xc <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 4)
            sub_xa_xc <= add1_sum;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        add_xa_xc <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 4)
            add_xa_xc <= add2_sum;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        sub_xb_xd <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 6)
            sub_xb_xd <= add1_sum;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        add_xb_xd <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 6)
            add_xb_xd <= add2_sum;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        sub_ya_yc <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 8)
            sub_ya_yc <= add1_sum;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        add_ya_yc <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 8)
            add_ya_yc <= add2_sum;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        sub_yb_yd <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 10)
            sub_yb_yd <= add1_sum;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        add_yb_yd <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 10)
            add_yb_yd <= add2_sum;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        radix_tmp_0 <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 7)
            radix_tmp_0 <= add1_sum;
    end
    else if(state_rev && (tcnt == 2 || tcnt == 3) && (radix_loop_cnt != single_num-1))
        radix_tmp_0 <= $unsigned(wn_rdata);
    else if(state_pre && (tcnt == 4 || tcnt == 6))
        radix_tmp_0 <= add1_sum;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        radix_tmp_1 <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 7)
            radix_tmp_1 <= add2_sum;
    end
    else if(state_pre && (tcnt == 4 || tcnt == 6))
        radix_tmp_1 <= add2_sum;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        radix_tmp_2 <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 9)
            radix_tmp_2 <= rg_ifft_flag?  add2_sum : add1_sum;
    end
    else if(state_rev && tcnt == 4)
        radix_tmp_2 <= (radix_loop_cnt[0]?  (radix_tmp_0 >> 2)+1'b1 : (radix_tmp_0 >> 2));
    else if(state_pre && tcnt == 5)
        radix_tmp_2 <= mult1_res_sat_shift32;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        radix_tmp_3 <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 9)
            radix_tmp_3 <= rg_ifft_flag?  add1_sum : add2_sum;
    end
    else if(state_rev && tcnt == 3)
        radix_tmp_3 <= (radix_loop_cnt[0]?  (radix_tmp_0 >> 2)+1'b1 : (radix_tmp_0 >> 2));
    else if(state_pre && tcnt == 5)
        radix_tmp_3 <= mult2_res_sat_shift32;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        radix_tmp_4 <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 11)
            radix_tmp_4 <= rg_ifft_flag?  add2_sum : add1_sum;
    end
    else if(state_pre && tcnt == 7)
        radix_tmp_4 <= mult1_res_sat_shift32;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        radix_tmp_5 <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 11)
            radix_tmp_5 <= rg_ifft_flag?  add1_sum : add2_sum;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        radix_tmp_6 <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 13)
            radix_tmp_6 <= add1_sum;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        radix_tmp_7 <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 13)
            radix_tmp_7 <= add2_sum;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        xc_cos <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 8)
            xc_cos <= $signed(mult1_res >>> DATA_WIDTH);
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        yc_sin <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 8)
            yc_sin <= $signed(mult2_res >>> DATA_WIDTH);
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        yb_cos <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 10)
            yb_cos <= $signed(mult1_res >>> DATA_WIDTH);
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        xb_sin <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 10)
            xb_sin <= $signed(mult2_res >>> DATA_WIDTH);
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        yd_cos <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 10)
            yd_cos <= $signed(mult3_res >>> DATA_WIDTH);
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        xd_sin <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 10)
            xd_sin <= $signed(mult4_res >>> DATA_WIDTH);
    end
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        xb_cos <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 12)
            xb_cos <= $signed(mult1_res >>> DATA_WIDTH);
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        yb_sin <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 12)
            yb_sin <= $signed(mult2_res >>> DATA_WIDTH);
    end
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        xd_cos <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 12)
            xd_cos <= $signed(mult3_res >>> DATA_WIDTH);
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        yd_sin <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 12)
            yd_sin <= $signed(mult4_res >>> DATA_WIDTH);
    end
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        yc_cos <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 14)
            yc_cos <= $signed(mult1_res >>> DATA_WIDTH);
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        xc_sin <= 'sd0;
    else if(state_radix4) begin
        if(tcnt == 14)
            xc_sin <= $signed(mult2_res >>> DATA_WIDTH);
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        result <= 'sd0;
    else if(state_radix4) begin
        if(state_c != LAST_STAGE) begin
            if(tcnt == 8)
                result <= (state_c == FIRST_STAGE)?  radix_tmp_1 : (radix_tmp_1 >>> 2);
            else if(tcnt == 14)
                result <= (state_c == FIRST_STAGE)?  radix_tmp_7 : (radix_tmp_7 >>> 2);
            else if(tcnt >= 13 && tcnt <= 19)
                result <= (state_c == FIRST_STAGE)?  (add3_sum <<< 1) : (add3_sum >>> 1);
        end
        else begin
            if(~need_post) begin
                if(tcnt == 8)
                    result <= radix_tmp_1;
                else if(tcnt == 13)
                    result <= radix_tmp_5;
                else if(tcnt == 14)
                    result <= radix_tmp_7;
                else if(tcnt == 15)
                    result <= radix_tmp_2;
                else if(tcnt == 16)
                    result <= radix_tmp_0;
                else if(tcnt == 17) 
                    result <=  radix_tmp_4;
                else if(tcnt == 18)
                    result <= radix_tmp_6;
                else if(tcnt == 19)
                    result <= radix_tmp_3;
            end
            else begin
                if(tcnt == 8)
                    result <= (radix_tmp_1 <<< 1);
                else if(tcnt == 13)
                    result <= (radix_tmp_5 <<< 1);
                else if(tcnt == 14)
                    result <= (radix_tmp_7 <<< 1);
                else if(tcnt == 15)
                    result <= (radix_tmp_2 <<< 1);
                else if(tcnt == 16)
                    result <= (radix_tmp_0 <<< 1);
                else if(tcnt == 17) 
                    result <=  (radix_tmp_4 <<< 1);
                else if(tcnt == 18)
                    result <= (radix_tmp_6 <<< 1);
                else if(tcnt == 19)
                    result <= (radix_tmp_3 <<< 1);
            end
        end
    end
    else if(state_rev && radix_loop_cnt != 0) begin
        if(tcnt == 0 || tcnt == 1)
            result <= $signed(data_rdata);
    end
    else if(state_pre) begin
        if(tcnt == 5 || tcnt == 7)
            result <= radix_tmp_1;
        else if(tcnt == 8)
            result <= rg_ifft_flag?  (add1_sum <<< 1) : (add2_sum <<< 1);
        else if(tcnt == 9)
            result <= (add3_sum <<< 1);
    end
    else if(state_post && tcnt[1])
        result <= ($signed(data_rdata) <<< 1);
end

//-------------------todo--------------------------//
always@(*) begin
    stage_num = 2;
    case(fft_len)
        16 : stage_num = 2;
        64 : stage_num = 3;
        256: stage_num = 4;
        1024: stage_num = 5;
        4096: stage_num = 6;
        default : stage_num = 2;
    endcase
end


always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_rd <= 1'b0;
    else begin
        if(state_radix4) begin
            if(tcnt==0)
                data_rd <= 1'b1;
            else if(tcnt == 8) 
                data_rd <= 1'b0;    
        end
        else if(state_rev && (tcnt==3 || tcnt==4) && (radix_loop_cnt != single_num-1))
            data_rd <= 1'b1;
        else if(state_pre) begin
            if(tcnt == 0)
                data_rd <= 1'b1;
            else if(tcnt == 4)
                data_rd <= 1'b0;
        end
        else if(state_post && (tcnt==0 || tcnt==1)) 
            data_rd <= 1'b1;
        else 
            data_rd <= 1'b0;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_wr <= 1'b0;
    else begin
        if(state_radix4) begin
            if(tcnt==8 || (tcnt >= 13 && tcnt <= 19))
                data_wr <= 1'b1;
            else
                data_wr <= 1'b0;    
        end
        else if(state_rev && (tcnt==0 || tcnt==1) && (radix_loop_cnt!=0))
            data_wr <= 1'b1;
        else if(state_pre && (tcnt == 5 || tcnt >=7 && tcnt <=9))
            data_wr <= 1'b1;
        else if(state_post && (tcnt==2 || tcnt==3) )//&& ~post_stage_last_radix)
            data_wr <= 1'b1;
        else 
            data_wr <= 1'b0;
    end
end

logic [ADDR_WIDTH-1:0] data_addr_head;

// todo with ADD //
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_addr <= 'd0;
    else begin
        if(state_radix4) begin
            if(tcnt == 0)
                data_addr <= data_addr_head;
            else if(tcnt == 1)
                data_addr <= data_addr + (step << 2);
            else if(tcnt == 2)
                data_addr <= data_addr - (step << 1);
            else if(tcnt == 3)
                data_addr <= data_addr + (step << 2);
            else if(tcnt == 4)
                data_addr <= data_addr_head + 1;
            else if(tcnt == 5)
                data_addr <= data_addr + (step << 2);
            else if(tcnt == 6)
                data_addr <= data_addr - (step << 1);
            else if(tcnt == 7)
                data_addr <= data_addr + (step << 2);
            else if(tcnt == 8) begin
                //if(~switch_flag && state_c == FIRST_STAGE)
                if(state_c == FIRST_STAGE)
                    data_addr <= data_addr_head + data_base_offset;
                else
                    data_addr <= data_addr_head;
            end
            else if(tcnt == 13 || tcnt == 17)
                data_addr <= data_addr + (step << 2) ;
            else if(tcnt == 14 || tcnt == 18)
                data_addr <= data_addr - (step << 2) + 1;
            else if(tcnt == 15 || tcnt == 19)
                data_addr <= data_addr + (step << 2);
            else if(tcnt == 16)
                data_addr <= data_addr - (step << 1) - 1;
        end
        else if(state_rev) begin
            if ((tcnt == 3 || tcnt == 4) && (radix_loop_cnt != single_num-1))
                data_addr <= (radix_loop_cnt[0]?  dest_data_base + (radix_tmp_0 >> 2)+1'b1 : dest_data_base + (radix_tmp_0 >> 2));
            else if((tcnt == 0) && (radix_loop_cnt != 0))
                data_addr <= dest_data_base + radix_tmp_2;
            else if((tcnt == 1) && (radix_loop_cnt != 0))
                data_addr <= dest_data_base + radix_tmp_3;  
        end
        else if(state_pre) begin
            if(tcnt == 0)
                data_addr <= (radix_loop_cnt == 0)?  src_data_base : data_addr_head + 2;
            else if(tcnt == 2 || tcnt == 7)
                data_addr <= data_addr_head + 1;
            else if(tcnt == 1 || tcnt == 3)
                data_addr <= data_addr + (fft_len << 1);
            else if(tcnt == 5)
                data_addr <= data_addr_head;
            else if(tcnt == 8)
                data_addr <= data_addr_head + (fft_len << 1);
            else if(tcnt == 9)
                data_addr <= data_addr + 1;
        end
        else if(state_post) begin
            if(radix_loop_cnt == 0 && tcnt == 0)
                data_addr <= dest_data_base;
            else if(tcnt == 2)
                data_addr <= data_addr_head;
            else 
                data_addr <= data_addr + 1;
        end
    end
end


always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_addr_head <= 'd0;
    else begin
        if(fft_start)
            data_addr_head <= src_data_base; 
        else if(state_radix4) begin
            if(group_loop_end)
                data_addr_head <= dest_data_base;
            else if(radix_loop_end) begin
                //if(~switch_flag && state_c == FIRST_STAGE)
                if(state_c == FIRST_STAGE)
                    data_addr_head <= src_data_base + ((group_loop_cnt + 1) << 1);
                else 
                    data_addr_head <= dest_data_base + ((group_loop_cnt + 1) << 1);
            end
            else if(tcnt_loop_end)
                data_addr_head <= data_addr_head + (step <<< 3);
        end
        else if(state_pre && tcnt == 1) begin
            data_addr_head <= data_addr;
        end
        else if(state_post && tcnt == 1) begin
            data_addr_head <= data_addr;
        end
    end
end

assign data_wdata = result;
assign data_wmask = {DATA_WIDTH{1'b1}};


endmodule