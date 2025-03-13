module radix4#(
    parameter ADDR_WIDTH = 17,
    parameter DATA_WIDTH = 32,
    parameter LADDR_WIDTH = 4
)(
    input                               clk                 ,
    input                               rstn                ,
    /**************** control ****************/
    input                               fft_start           ,
    output logic                        fft_done            ,
    input                               pre_start           ,
    output logic                        pre_done            ,
    input                               post_start          ,
    output logic                        post_done           ,
    input                               reverse_start       ,
    output logic                        reverse_done        ,
    /**************** config ****************/
    input        [9:0]                  rg_bitrevlen        ,
    input        [15:0]                 fft_len             ,   // = 4^M
    input        [31:0]                 rg_twid             ,
    input                               rg_ifft_flag        ,
    input                               rg_bitreverse_flag  ,
    input        [ADDR_WIDTH-1:0]       data_base           ,
    input        [ADDR_WIDTH-1:0]       wn_base             ,
    input        [ADDR_WIDTH-1:0]       rev_base            ,
    /**************** data memory interface ****************/
    input        [DATA_WIDTH-1:0]       data_rdata          ,
    output logic [DATA_WIDTH-1:0]       data_wdata          ,
    output logic [DATA_WIDTH/8-1:0]     data_wmask          ,
    output logic                        data_wr             ,
    output logic                        data_rd             ,
    output logic [ADDR_WIDTH-1:0]       data_addr           ,
    /**************** wn memory interface ****************/
    input        [DATA_WIDTH-1:0]       wn_rdata            ,
    output logic [DATA_WIDTH-1:0]       wn_wdata            ,
    output logic [DATA_WIDTH/8-1:0]     wn_wmask            ,
    output logic                        wn_wr               ,
    output logic                        wn_rd               ,
    output logic [ADDR_WIDTH-1:0]       wn_addr             ,
    /**************** line buffer interface ****************/
    input        [DATA_WIDTH-1:0]           mem1_rdata          ,
    output logic [DATA_WIDTH-1:0]           mem1_wdata          ,
    output logic                            mem1_wr             ,
    output logic                            mem1_rd             ,
    output logic [LADDR_WIDTH-1:0]          mem1_addr           ,
    input        [DATA_WIDTH-1:0]           mem2_rdata          ,
    output logic [DATA_WIDTH-1:0]           mem2_wdata          ,
    output logic                            mem2_wr             ,
    output logic                            mem2_rd             ,
    output logic [LADDR_WIDTH-1:0]          mem2_addr           ,
    input        [DATA_WIDTH-1:0]           mem3_rdata          ,
    output logic [DATA_WIDTH-1:0]           mem3_wdata          ,
    output logic                            mem3_wr             ,
    output logic                            mem3_rd             ,
    output logic [LADDR_WIDTH-1:0]          mem3_addr           ,
    input        [DATA_WIDTH-1:0]           mem4_rdata          ,
    output logic [DATA_WIDTH-1:0]           mem4_wdata          ,
    output logic                            mem4_wr             ,
    output logic                            mem4_rd             ,
    output logic [LADDR_WIDTH-1:0]          mem4_addr           ,
    /***************** MULT1 interface *********************/
    output logic signed [DATA_WIDTH-1:0]    mult1_a             ,
    output logic signed [DATA_WIDTH-1:0]    mult1_b             ,
    input signed [2*DATA_WIDTH-1:0]         mult1_res           ,
    /***************** MULT2 interface *********************/
    output logic signed [DATA_WIDTH-1:0]    mult2_a             ,
    output logic signed [DATA_WIDTH-1:0]    mult2_b             ,
    input signed [2*DATA_WIDTH-1:0]         mult2_res           ,
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
parameter OUT_DLY = 10;     // according to pipelined 
//parameter DATA_BASE = 0;
//parameter WN_BASE = 0;
//parameter REV_BASE = 0;
parameter PIPE_TIME = 28;
parameter PRE_TIME = 15;
parameter POST_TIME = 4;
parameter REV_TIME = 4;

logic stage_loop_end;   // for one state switch
logic [2:0] stage_num;// 16,...,4096 = 2,...,6 // stage num in one state
logic [2:0] stage_cnt; // for middile stage counter// 0,1,2,3,4 // for start&last = 0
logic group_loop_end;   // for one stage switch
logic [9:0] group_num;  // group num in one group
logic [9:0] group_loop_cnt; // for group in one stage // 0~N/4-1
logic radix_loop_end;   // for one group switch
logic [9:0] radix_num;  // radix num in one group
logic [9:0] radix_loop_cnt; // for radix in one group // 0~N/4-1
logic tcnt_loop_end;   // for one radix 4 swith
logic [4:0] tcnt_num;   // tcnt num in one radix
logic [4:0] tcnt;  // for wn 0~5// for data 0~7 

logic single_loop_end;  // pre/post/rev end
logic [11:0] single_num;


logic state_radix4;
logic state_pre;
logic state_post;
logic state_rev;

logic first_stage_done;
logic middile_stage_done;
logic last_stage_done;
logic pre_stage_done;
logic post_stage_done;
logic rev_stage_done;

logic last_stage_last_radix;
logic last_stage_first_radix;
logic first_stage_first_radix;
logic middle_stage_first_radix;
logic first_radix;
logic pipe_flag;

logic post_stage_last_radix;

logic [15:0] step;
logic [15:0] strid;
logic [15:0] twid;
logic [15:0] re_addr_next;
logic im_addr_flag;
logic trans_flag;
logic [15:0] re_addr;

logic [15:0] re_pre_addr_next;
logic [15:0] re_post_addr_next;
logic [15:0] rev_addr_next;

logic im_pre_addr_flag;
logic im_post_addr_flag;

logic [15:0] re_addr_a;
logic [15:0] re_addr_a_lat;

logic signed [DATA_WIDTH-1:0] signed_data_rdata;
logic signed [DATA_WIDTH-1:0] signed_wn_rdata;
logic signed [DATA_WIDTH-1:0] signed_add2_sum_out;
logic signed [DATA_WIDTH-1:0] signed_data_rdata_shift4;
logic signed [DATA_WIDTH-1:0] signed_data_rdata_shift2;
logic signed [DATA_WIDTH-1:0] signed_xa_ya_sum;
logic signed [DATA_WIDTH-1:0] signed_xa_ya_out;
logic signed [DATA_WIDTH-1:0] mult1_res_sat_shift32;
logic [DATA_WIDTH-1:0] tab_rdata;

logic [DATA_WIDTH-1:0] buff1;
logic [DATA_WIDTH-1:0] buff2;
logic [DATA_WIDTH-1:0] buff3;
logic [DATA_WIDTH-1:0] buff4;
logic [DATA_WIDTH-1:0] buff5;

assign signed_data_rdata = $signed(data_rdata);
assign signed_wn_rdata = $signed(wn_rdata);
assign signed_data_rdata_shift4 = (signed_data_rdata >>> 4);
assign signed_data_rdata_shift2 = (signed_data_rdata >>> 2);
assign tab_rdata = wn_rdata;

// -------------------- behavior model -------------------//
/*
logic signed [DATA_WIDTH-1:0] add1_a;
logic signed [DATA_WIDTH-1:0] add1_b;
logic signed [DATA_WIDTH-1:0] add1_sum;
assign add1_sum = add1_a + add1_b;
logic signed [DATA_WIDTH-1:0] add2_a;
logic signed [DATA_WIDTH-1:0] add2_b;
logic signed [DATA_WIDTH-1:0] add2_sum;
assign add2_sum = add2_a + add2_b;
logic signed [DATA_WIDTH-1:0] add3_a;
logic signed [DATA_WIDTH-1:0] add3_b;
logic signed [DATA_WIDTH-1:0] add3_sum;
assign add3_sum = add3_a + add3_b;

logic signed [DATA_WIDTH-1:0] mult1_a;
logic signed [DATA_WIDTH-1:0] mult1_b;
logic signed [2*DATA_WIDTH-1:0] mult1_res;
assign mult1_res = mult1_a * mult1_b;
logic signed [DATA_WIDTH-1:0] mult2_a;
logic signed [DATA_WIDTH-1:0] mult2_b;
logic signed [2*DATA_WIDTH-1:0] mult2_res;
assign mult2_res = mult2_a * mult2_b;

logic mem1_rd;
logic mem1_wr;
logic [2:0] mem1_addr;
logic [DATA_WIDTH-1:0] mem1_wdata;
logic [DATA_WIDTH-1:0] mem1_rdata;
logic [DATA_WIDTH-1:0] mem1_array [0:7];
always_ff@(posedge clk or negedge rstn) begin
    if(mem1_wr)
        mem1_array[mem1_addr] <= mem1_wdata;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        mem1_rdata <= 'd0;
    end
    else if(mem1_rd)
        mem1_rdata <= mem1_array[mem1_addr];
end

logic mem2_rd;
logic mem2_wr;
logic [3:0] mem2_addr;
logic [DATA_WIDTH-1:0] mem2_wdata;
logic [DATA_WIDTH-1:0] mem2_rdata;
logic [DATA_WIDTH-1:0] mem2_array [0:15];
always_ff@(posedge clk or negedge rstn) begin
    if(mem2_wr)
        mem2_array[mem2_addr] <= mem2_wdata;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        mem2_rdata <= 'd0;
    end
    else if(mem2_rd)
        mem2_rdata <= mem2_array[mem2_addr];
end

logic mem3_rd;
logic mem3_wr;
logic [3:0] mem3_addr;
logic [DATA_WIDTH-1:0] mem3_wdata;
logic [DATA_WIDTH-1:0] mem3_rdata;
logic [DATA_WIDTH-1:0] mem3_array [0:15];
always_ff@(posedge clk or negedge rstn) begin
    if(mem3_wr)
        mem3_array[mem3_addr] <= mem3_wdata;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        mem3_rdata <= 'd0;
    end
    else if(mem3_rd)
        mem3_rdata <= mem3_array[mem3_addr];
end

logic mem4_rd;
logic mem4_wr;
logic [3:0] mem4_addr;
logic [DATA_WIDTH-1:0] mem4_wdata;
logic [DATA_WIDTH-1:0] mem4_rdata;
logic [DATA_WIDTH-1:0] mem4_array [0:15];
always_ff@(posedge clk or negedge rstn) begin
    if(mem4_wr)
        mem4_array[mem4_addr] <= mem4_wdata;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        mem4_rdata <= 'd0;
    end
    else if(mem4_rd)
        mem4_rdata <= mem4_array[mem4_addr];
end
*/
//--------------------------------------------//


// FSM
typedef enum logic  [2:0] {IDLE, FIRST_STAGE, MIDDLE_STAGE, LAST_STAGE,PRE_STAGE,POST_STAGE,REV_STAGE} state_t;
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
                                reverse_start?         REV_STAGE : IDLE;
        FIRST_STAGE : state_n = first_stage_done?       ((stage_num == 2)?  LAST_STAGE : MIDDLE_STAGE) : FIRST_STAGE;
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
assign last_stage_done = group_loop_end && (state_c == LAST_STAGE);    // 此时的最有一轮的tcnt_num会delay几拍，因为最后一级没有后续pipeline
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
assign middle_stage_first_radix = (state_c == MIDDLE_STAGE) && (radix_loop_cnt == 0) && (group_loop_cnt == 0);
//assign tcnt_num = last_stage_last_radix?  PIPE_TIME + OUT_DLY : PIPE_TIME;
assign post_stage_last_radix = (state_c == POST_STAGE) && (radix_loop_cnt == single_num-1);

assign tcnt_num = state_radix4?  PIPE_TIME : 
                  state_pre?    PRE_TIME : 
                  state_post?   POST_TIME : 
                  state_rev?    REV_TIME : PIPE_TIME;   //todo
assign radix_num = (state_c == LAST_STAGE)? strid+1 : strid;
assign group_num = step;
assign single_num = state_pre?  fft_len : 
                    state_post? (fft_len << 1)+1'b1 : (rg_bitrevlen+1'b1);

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

always_ff@(posedge clk or negedge rstn) begin   
    if(~rstn)
        fft_done <= 1'b0;
    else if(state_c == LAST_STAGE && state_n == IDLE)
        fft_done <= 1'b1;
    else 
        fft_done <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin   
    if(~rstn)
        pre_done <= 1'b0;
    else if(state_c == PRE_STAGE && state_n == IDLE)
        pre_done <= 1'b1;
    else 
        pre_done <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin   
    if(~rstn)
        post_done <= 1'b0;
    else if(state_c == POST_STAGE && state_n == IDLE)
        post_done <= 1'b1;
    else 
        post_done <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin   
    if(~rstn)
        reverse_done <= 1'b0;
    else if(state_c == REV_STAGE && state_n == IDLE)
        reverse_done <= 1'b1;
    else 
        reverse_done <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        pipe_flag <= 1'b0;
    else if(state_c != state_n)
        pipe_flag <= 1'b0;
    else if(tcnt_loop_end && state_radix4)
        pipe_flag <= ~pipe_flag;
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

always@(*) begin
    add3_a = 'bx;
    if(((tcnt>=0 && tcnt<=7) || (tcnt==tcnt_num-1)) && ~last_stage_last_radix) 
        add3_a = radix_loop_end?   (data_base >> 1) : re_addr_a;
    else if(tcnt>=19 && tcnt<=26 && ~first_stage_first_radix)
        add3_a = re_addr_a_lat;
end

always@(*) begin
    add3_b = 'bx;
    case(tcnt)
        tcnt_num-1 : add3_b = (radix_loop_end)?  (group_loop_cnt+1) : (step << 2);
        5'd0:  add3_b = 0;
        5'd1:  add3_b = (step << 1);
        5'd2:  add3_b = step;
        5'd3:  add3_b = step + (step << 1);        // todo adder 
        5'd4:  add3_b = step;
        5'd5:  add3_b = step + (step << 1);
        5'd6:  add3_b = 0;
        5'd7:  add3_b = (step << 1);
        5'd19: add3_b = 0;
        5'd20: add3_b = 0;
        5'd21: add3_b = first_radix?  (step << 2) : step;
        5'd22: add3_b = first_radix?  (step << 2) : step;
        5'd23: add3_b = first_radix?  (step << 3) : (step << 1);
        5'd24: add3_b = first_radix?  (step << 3) : (step << 1);
        5'd25: add3_b = first_radix?  ((step << 3) + (step << 2)) : step + (step << 1);
        5'd26: add3_b = first_radix?  ((step << 3) + (step << 2)) : step + (step << 1);
        //default : add3_b = 0;       
    endcase
end

assign re_addr_next = add3_sum;
assign re_pre_addr_next = (tcnt == 0 || tcnt == 5 || tcnt == 6 || tcnt == 11)?  re_addr_a : (re_addr_a + fft_len);
assign re_post_addr_next = re_addr_a;
// todo //
assign rev_addr_next = (tcnt==2 || tcnt==3)?    (radix_loop_cnt[0]?  (tab_rdata >> 2)+1'b1 : (tab_rdata >> 2)) : 
                       (tcnt==0)?   buff2 : buff1;
//assign rev_addr_next = 0;

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn) 
        re_addr_a <= (data_base >> 1);
    else if(state_c != state_n)
        re_addr_a <= (data_base >> 1);
    else if(tcnt_loop_end) begin
        if(state_radix4)  
            re_addr_a <= re_addr_next;
        else if(state_pre || state_post)
            re_addr_a <= re_addr_a + 1'b1;
    end
end
assign im_addr_flag = (tcnt>=0 && tcnt<=7)? tcnt[1] : ~tcnt[0];
assign im_pre_addr_flag = (tcnt==6 || tcnt==7 || tcnt==11 || tcnt==13) ;
assign im_post_addr_flag = tcnt[0];

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn) 
        re_addr_a_lat <= (data_base >> 1);
    else if(tcnt_loop_end && state_radix4)  
        re_addr_a_lat <= re_addr_a;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn) 
        data_addr <= data_base;
    else if(state_c != state_n)
        data_addr <= data_base;
    else if(state_radix4)
        data_addr <= {re_addr_next[14:0],im_addr_flag};
    else if(state_pre)
        data_addr <= {re_pre_addr_next[14:0],im_pre_addr_flag};
    else if(state_post)
        data_addr <= {re_post_addr_next[14:0],im_post_addr_flag};
    else if(state_rev)
        data_addr <= rev_addr_next;
end

always_ff@(posedge clk or negedge rstn) begin   // todo except last radix
    if(~rstn)
        data_rd <= 1'b0;
    else if(~(|tcnt[4:3]) && (state_radix4) && ~last_stage_last_radix)
        data_rd <= 1'b1;
    else if(state_pre && (tcnt==0 || tcnt==1 || tcnt==6 || tcnt==7))
        data_rd <= 1'b1;
    else if(state_post && (tcnt==0 || tcnt==1)) 
        data_rd <= 1'b1;
    else if(state_rev && (tcnt==2 || tcnt==3) && (radix_loop_cnt != single_num-1))
        data_rd <= 1'b1;
    else 
        data_rd <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin   // todo except first radix
    if(~rstn)
        data_wr <= 1'b0;
    else if((tcnt >= 19 && tcnt<=26) && (state_radix4) && ~first_stage_first_radix)
        data_wr <= 1'b1;
    else if(state_pre && (tcnt==5 || tcnt==11 || tcnt==12 || tcnt==13))
        data_wr <= 1'b1;
    else if(state_post && (tcnt==2 || tcnt==3) && ~post_stage_last_radix)
        data_wr <= 1'b1;
    else if(state_rev && (tcnt==0 || tcnt==1) && (radix_loop_cnt!=0))
        data_wr <= 1'b1;
    else 
        data_wr <= 1'b0;
end

assign data_wdata = buff4;  // register output

// todo wn_addr
logic [ADDR_WIDTH-2:0] wn_addr_sta;
logic [ADDR_WIDTH-1:0] wn_addr_co1;
logic [ADDR_WIDTH-1:0] wn_addr_si1;
logic [ADDR_WIDTH-1:0] wn_addr_co2;
logic [ADDR_WIDTH-1:0] wn_addr_si2;
logic [ADDR_WIDTH-1:0] wn_addr_co3;
logic [ADDR_WIDTH-1:0] wn_addr_si3;

assign wn_addr_co1 = {wn_addr_sta,1'b0};
assign wn_addr_si1 = {wn_addr_sta,1'b1};
assign wn_addr_co2 = (wn_addr_co1 << 1) ;
assign wn_addr_si2 = wn_addr_co2 + 1'b1;
assign wn_addr_co3 = wn_addr_co2 + wn_addr_co1;  // todo : can reuse ADD2
assign wn_addr_si3 = wn_addr_co3 + 1'b1;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        wn_addr_sta <= wn_base;
    else if(state_radix4 && (state_c != LAST_STAGE) && tcnt == 14) begin    // condition: >= 13 && < tcnt_num-3
        if(first_radix)
            wn_addr_sta <= wn_base;
        else if(radix_loop_cnt == 0)
            wn_addr_sta <= wn_addr_sta + twid;  // todo : can reuse ADD2
    end
    else if(state_pre) begin
        if(radix_loop_cnt == 0 && ~tcnt_loop_end)
            wn_addr_sta <= wn_base;
        else if(tcnt_loop_end)
            wn_addr_sta <= wn_addr_sta + 1'b1;
    end
    else if(state_rev) begin
        if(radix_loop_cnt == 0 && ~tcnt_loop_end)
            wn_addr_sta <= rev_base;
        else if(tcnt_loop_end && radix_loop_cnt[0])
            wn_addr_sta <= wn_addr_sta + 2;
    end
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        wn_addr <= wn_base;
    else if((state_radix4 && (state_c != LAST_STAGE)) || last_stage_first_radix) begin
        if(tcnt == tcnt_num-3 || tcnt==9)
            wn_addr <= wn_addr_co3;
        else if(tcnt == tcnt_num-2 || tcnt==10)
            wn_addr <= wn_addr_si3;
        else if(tcnt == 3 || tcnt==12)
            wn_addr <= wn_addr_co2;
        else if(tcnt == 4 || tcnt==13)
            wn_addr <= wn_addr_si2;
        else if(tcnt == 0 || tcnt==6)
            wn_addr <= wn_addr_co1;
        else if(tcnt == 1 || tcnt==7)
            wn_addr <= wn_addr_si1;
    end
    else if(state_pre) begin
        if(tcnt==2 || tcnt==8)
            wn_addr <= {wn_addr_sta,1'b0};
        else if(tcnt==3 || tcnt==9)
            wn_addr <= {wn_addr_sta,1'b1};
    end
    else if(state_rev) begin
        if(tcnt==0)
            wn_addr <= (radix_loop_cnt==0)?  rev_base : wn_addr_sta;
        else if(tcnt==1)
            wn_addr <= wn_addr_sta + 1'b1;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        wn_rd <= 1'b0;
    else if(state_radix4 && ((tcnt >= tcnt_num-3) || (tcnt<=13)) && ~(state_c == LAST_STAGE && ~last_stage_first_radix))
        wn_rd <= 1'b1;
    else if(state_pre && (tcnt==2 || tcnt==3 || tcnt==8 || tcnt==9))    // todo : can always rd??
        wn_rd <= 1'b1;
    else if(state_rev && (tcnt==0 || tcnt==1) && (radix_loop_cnt != single_num-1))
        wn_rd <= 1'b1;
    else 
        wn_rd <= 1'b0;
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

// PIPE 0

// BUFFER1 //
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        buff1 <= 'd0;
    else if(state_radix4) begin
        if(tcnt>=2 && tcnt<=9 && ~tcnt[0])
            buff1 <= (state_c == FIRST_STAGE)?  signed_data_rdata_shift4 : signed_data_rdata;
        // todo
        else if(tcnt>=13 && tcnt<=19 && tcnt[0])
            buff1 <= mem1_rdata;
    end
    else if(state_pre) begin
        if(tcnt==2 || tcnt==8)
            buff1 <= signed_data_rdata_shift2;
        else if(tcnt==4 || tcnt==10)
            buff1 <= add1_sum;
        else if(tcnt==11)
            buff1 <= mult1_res_sat_shift32;
        else if(tcnt==12)
            buff1 <= buff5;
    end
    else if(state_rev) begin
        if(tcnt==2)
            buff1 <= (tab_rdata >>> 2);
    end
end

// BUFFER2 //
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        buff2 <= 'd0;
    else if(state_radix4) begin
        if(tcnt>=3 && tcnt<=10 && tcnt[0])
            buff2 <= (state_c == FIRST_STAGE)?  signed_data_rdata_shift4 : signed_data_rdata;
        // todo
        else if(tcnt>=14 && tcnt<=20 && ~tcnt[0])
            buff2 <= mem1_rdata;
    end
    else if(state_pre) begin
        if(tcnt==3 || tcnt==9)
            buff2 <= signed_data_rdata_shift2;
        else if(tcnt==10)
            buff2 <= mult1_res_sat_shift32;
    end
    else if(state_rev) begin
        if(tcnt==3)
            buff2 <= (tab_rdata >>> 2);
    end
end

// BUFFER3 //
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        buff3 <= 'd0;
    else if(state_radix4) begin
        if(tcnt>=3 && tcnt<=10)
            buff3 <= add1_sum;
    // todo
        else if(tcnt>=14 && tcnt<=21)
            buff3 <= add1_sum;
    end
    else if(state_pre) begin
        if(tcnt==4)
            buff3 <= mult1_res_sat_shift32;
        else if(tcnt==12)
            buff3 <= buff2;
    end
end

assign mult1_res_sat_shift32 = mult1_res[DATA_WIDTH-1]?  (mult1_res >>> DATA_WIDTH)+1'b1 : (mult1_res >>> DATA_WIDTH);

// BUFFER4 //
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        buff4 <= 'd0;
    else if(state_radix4) begin
        if((tcnt == tcnt_num-1) || tcnt==2 || tcnt==5 || tcnt==8 || tcnt==11 || tcnt==14)
            buff4 <= signed_wn_rdata;
        else if(tcnt==1 || tcnt==4 || tcnt==7 || tcnt==10 || tcnt==13 || tcnt== 16)
            buff4 <= $signed(mult1_res >>> DATA_WIDTH);
        else if(tcnt>=19 && tcnt <=26) begin
            if(state_c == LAST_STAGE && ~last_stage_first_radix) begin
                buff4 <= pipe_flag?  mem2_rdata : mem3_rdata;
            end
            else begin
                buff4 <= (tcnt==19 || tcnt==20)?    signed_xa_ya_out : signed_add2_sum_out;
            end
        end
    end
    else if(state_pre) begin
        if(tcnt==3 || tcnt==9)
            buff4 <= add1_sum;
        else if(tcnt==5 || tcnt==11)
            buff4 <= buff1;
        else if(tcnt==12 || tcnt==13)
            buff4 <= (add2_sum << 1);
    end
    else if(state_post) begin
        if(tcnt==2 || tcnt==3)
            buff4 <= (signed_data_rdata <<< 1);
    end
    else if(state_rev) begin
        if(tcnt==0 || tcnt==1)
            buff4 <= signed_data_rdata;
    end
end
assign signed_xa_ya_sum = (pipe_flag?  mem2_rdata : mem3_rdata);
assign signed_xa_ya_out = (state_c == FIRST_STAGE || middle_stage_first_radix)?  signed_xa_ya_sum : (signed_xa_ya_sum>>>2);

// BUFFER5 //
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        buff5 <= 'd0;
    else if(state_radix4) begin
        if(tcnt == 0 || tcnt==3 || tcnt==6 || tcnt==9 || tcnt==12 || tcnt==15)
            buff5 <= signed_wn_rdata;
        else if(tcnt==1 || tcnt==4 || tcnt==7 || tcnt==10 || tcnt==13 || tcnt== 16)
            buff5 <= $signed(mult2_res >>> DATA_WIDTH);
    end
    else if(state_pre) begin
        if(tcnt==5)
            buff5 <= mult1_res_sat_shift32;
    end
end

// ADD1 interface //
always@(*) begin
    add1_a = 'bx;
    add1_b = 'bx;
    if(state_radix4) begin
        if(tcnt>=3 && tcnt<=10) begin
            add1_a = buff1;
            add1_b = tcnt[0]?   ((state_c == FIRST_STAGE)?  (-signed_data_rdata_shift4) : (-signed_data_rdata)) : buff2;
        end
        //todo
        else if(tcnt>=14 && tcnt<=21) begin
            add1_a = buff1;
            add1_b = tcnt[0]?   buff2 : (-mem1_rdata);
        end
    end
    else if(state_pre) begin
        if((tcnt>=3 && tcnt<=4) || (tcnt>=9 && tcnt <=10)) begin    // to delete, for debug
            add1_a = buff1;
            add1_b = tcnt[0]?   -signed_data_rdata_shift2 : buff2;
        end
    end
end

// ADD2 interface //
always@(*) begin
    add2_a = 'bx;
    add2_b = 'bx;
    if(state_radix4) begin
        if(tcnt>=21 && tcnt<=26) begin  // to delete, for debug
            add2_a = pipe_flag?  mem2_rdata : mem3_rdata;
            add2_b = (rg_ifft_flag ^ tcnt[0])?   mem4_rdata : -mem4_rdata;
        end
    end
    else if(state_pre) begin
        if(tcnt==12 || tcnt==13) begin  // to delete, for debug
            add2_a = buff3;
            add2_b = (rg_ifft_flag ^ tcnt[0])?  -buff1 : buff1;
        end
    end
end

assign signed_add2_sum_out = (state_c == FIRST_STAGE || middle_stage_first_radix)?  ($signed(add2_sum) <<< 1) : ($signed(add2_sum) >>> 1);

// MULT1 interface //
always@(*) begin
    mult1_a = 'bx;
    mult1_b = 'bx;
    if(state_radix4) begin
        if(tcnt==1 || tcnt==4 || tcnt==7 || tcnt==10 || tcnt==13 || tcnt==16) begin   // todo delet, just for check
            mult1_a = buff4;
            mult1_b = pipe_flag?    mem2_rdata : mem3_rdata;
        end
    end
    else if(state_pre) begin
        if(tcnt==4 || tcnt==5 || tcnt==10 || tcnt==11) begin   // to delete , just for debug
            mult1_a = signed_wn_rdata;
            mult1_b = buff4;
        end
    end
end

// MULT2 interface //
always@(*) begin
    mult2_a = 'bx;
    mult2_b = 'bx;
    if(tcnt==1 || tcnt==4 || tcnt==7 || tcnt==10 || tcnt==13 || tcnt==16) begin   // todo delet, just for check
        mult2_a = buff5;
        mult2_b = pipe_flag?    mem2_rdata : mem3_rdata;
    end
end
// M1 interface //
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem1_addr <= 'd0;
    else if(state_radix4) begin
        if(tcnt>=3 && tcnt<=10)
            mem1_addr <= tcnt-3;
        else if(tcnt == 11)
            mem1_addr <= 0;
        else if(tcnt == 12)
            mem1_addr <= 2;
        else if(tcnt == 13)
            mem1_addr <= 1;
        else if(tcnt == 14)
            mem1_addr <= 5;
        else if(tcnt == 15)
            mem1_addr <= 6;
        else if(tcnt == 16)
            mem1_addr <= 4;
        else if(tcnt == 17)
            mem1_addr <= 7;
        else if(tcnt == 18)
            mem1_addr <= 3;
    end
end
assign mem1_wdata = buff3;

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem1_wr <= 1'b0;
    else if((tcnt>=3 && tcnt<=10) && state_radix4) 
        mem1_wr <= 1'b1;
    else
        mem1_wr <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem1_rd <= 1'b0;
    else if((tcnt>=11 && tcnt<=18) && state_radix4) 
        mem1_rd <= 1'b1;
    else
        mem1_rd <= 1'b0;
end

// M2 interface //
// todo replace by reg table or memory
logic [3:0] mem_addr_mux;
logic mem_wr_condition;
logic mem_rd_condition;
always@(*) begin
    mem_addr_mux = 0;
    case(tcnt)
        tcnt_num-1 : mem_addr_mux = rg_ifft_flag?   1 : 0 ;
        5'd1 : mem_addr_mux = 8 ;
        5'd2 : mem_addr_mux = rg_ifft_flag?   0 : 1 ;
        5'd4 : mem_addr_mux = 9 ;
        5'd5 : mem_addr_mux = 2 ;
        5'd7 : mem_addr_mux = 10;
        5'd8 : mem_addr_mux = rg_ifft_flag?   5 : 4 ;
        5'd10: mem_addr_mux = 11;
        5'd11: mem_addr_mux = rg_ifft_flag?   4 : 5 ;
        5'd13: mem_addr_mux = 12;
        5'd14: mem_addr_mux = 6 ;
        5'd16: mem_addr_mux = 13;
        5'd17: mem_addr_mux = 3 ;
        5'd18: mem_addr_mux = 7 ;
        5'd19: mem_addr_mux = (state_c == LAST_STAGE && ~last_stage_first_radix)?   2 : 10;
        5'd20: mem_addr_mux = (state_c == LAST_STAGE && ~last_stage_first_radix)?   6 : 13;
        5'd21: mem_addr_mux = (state_c == LAST_STAGE && ~last_stage_first_radix)?   (rg_ifft_flag?   0 : 1) : 9 ;
        5'd22: mem_addr_mux = (state_c == LAST_STAGE && ~last_stage_first_radix)?   (rg_ifft_flag?   5 : 4) : 11;
        5'd23: mem_addr_mux = (state_c == LAST_STAGE && ~last_stage_first_radix)?   (rg_ifft_flag?   1 : 0) : 8 ;
        5'd24: mem_addr_mux = (state_c == LAST_STAGE && ~last_stage_first_radix)?   (rg_ifft_flag?   4 : 5) : 12;
        default : mem_addr_mux = 0;
    endcase
end
assign mem_wr_condition = (tcnt==1 || tcnt==4 || tcnt==7 || tcnt==10 || tcnt==13 || tcnt==16);
assign mem_rd_condition = (tcnt==2 || tcnt==5 || tcnt==8 || tcnt==11 || tcnt==14 || (tcnt>=17 && tcnt<=24));

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem2_addr <= 'd0;
    else if(state_radix4) begin
        if(~pipe_flag) begin
            if(tcnt>=14 && tcnt<=21)
                mem2_addr <= tcnt-14;
            else if(tcnt == tcnt_num-1)
                mem2_addr <= rg_ifft_flag?   1 : 0;
        end
        else begin
            mem2_addr <= mem_addr_mux;
        end
    end
end

assign mem2_wdata = pipe_flag?  buff4 : buff3;

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem2_wr <= 1'b0;
    else if(state_radix4) begin
        if(~pipe_flag && tcnt >=14 && tcnt<=21)
            mem2_wr <= 1'b1;
        else if(pipe_flag && mem_wr_condition)
            mem2_wr <= 1'b1;
        else
            mem2_wr <= 1'b0;
    end
    else
        mem2_wr <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem2_rd <= 1'b0;
    else if(state_radix4) begin
        if((pipe_flag && mem_rd_condition) || (~pipe_flag && (tcnt==tcnt_num-1 )))
            mem2_rd <= 1'b1;
        else
            mem2_rd <= 1'b0;
    end
    else
        mem2_rd <= 1'b0;
end

// M3 interface //
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem3_addr <= 'd0;
    else if(state_radix4) begin
        if(pipe_flag) begin
            if(tcnt>=14 && tcnt<=21)
                mem3_addr <= tcnt-14;
            else if(tcnt == tcnt_num-1)
                mem3_addr <= rg_ifft_flag?   1 : 0;
        end
        else begin
            mem3_addr <= mem_addr_mux;
        end
    end
end

assign mem3_wdata = pipe_flag?  buff3 : buff4;

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem3_wr <= 1'b0;
    else if(state_radix4) begin
        if(pipe_flag && tcnt >=14 && tcnt<=21)
            mem3_wr <= 1'b1;
        else if(~pipe_flag && mem_wr_condition)
            mem3_wr <= 1'b1;
        else
            mem3_wr <= 1'b0;
    end
    else
        mem3_wr <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem3_rd <= 1'b0;
    else if(state_radix4) begin
        if((~pipe_flag && mem_rd_condition) || (pipe_flag && (tcnt==tcnt_num-1 )))
            mem3_rd <= 1'b1;
        else
            mem3_rd <= 1'b0;
    end
    else
        mem3_rd <= 1'b0;
end

// M4 interface //
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem4_addr <= 'd0;
    else if(state_radix4) begin
            if(tcnt>=0 && tcnt<=16) mem4_addr <= mem_addr_mux;
            else if(tcnt == 19)  mem4_addr <= 13;
            else if(tcnt == 20)  mem4_addr <= 10;
            else if(tcnt == 21)  mem4_addr <= 11;
            else if(tcnt == 22)  mem4_addr <= 9;
            else if(tcnt == 23)  mem4_addr <= 12;
            else if(tcnt == 24)  mem4_addr <= 8;
        end
end

assign mem4_wdata = buff5;

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem4_wr <= 1'b0;
    else if(state_radix4) begin
        if(mem_wr_condition && tcnt>=0 && tcnt<=16)
            mem4_wr <= 1'b1;
        else
            mem4_wr <= 1'b0;
    end
    else
        mem4_wr <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem4_rd <= 1'b0;
    else if(state_radix4) begin
        if(tcnt>=19 && tcnt<=24)
            mem4_rd <= 1'b1;
        else
            mem4_rd <= 1'b0;
    end
    else
        mem4_rd <= 1'b0;
end

endmodule