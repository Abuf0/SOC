module moce_cfft #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter N          = 4
)(
    input                                   clk                 ,
    input                                   rstn                ,
    /**************** control ****************/
    input                                   cfft_start          ,
    output logic                            cfft_done           ,
    /**************** config ****************/
    input        [11:0]                     rg_bitrevlen        ,
    input        [15:0]                     rg_fft_len          ,
    input        [15:0]                     rg_twid             ,
    input                                   rg_ifft_flag        ,
    input                                   rg_bitreverse_flag  ,
    input        [ADDR_WIDTH-1:0]           rg_src_data_base  [0:N-1] ,
    input        [ADDR_WIDTH-1:0]           rg_dest_data_base [0:N-1] ,
    input        [ADDR_WIDTH-1:0]           rg_wn_base          ,
    input        [ADDR_WIDTH-1:0]           rg_rev_base         ,
    /**************** data memory interface ****************/
    input        [DATA_WIDTH-1:0]           data_rdata [0:N-1]  ,
    output logic [DATA_WIDTH-1:0]           data_wdata [0:N-1]  ,
    output logic [DATA_WIDTH/8-1:0]         data_wmask [0:N-1]  ,
    output logic                            data_wr    [0:N-1]  ,
    output logic                            data_rd    [0:N-1]  ,
    output logic [ADDR_WIDTH-1:0]           data_addr  [0:N-1]  ,
    /**************** wn/table memory interface ****************/
    input        [DATA_WIDTH-1:0]           wn_rdata            ,
    output logic [DATA_WIDTH-1:0]           wn_wdata            ,
    output logic [DATA_WIDTH/8-1:0]         wn_wmask            ,
    output logic                            wn_wr               ,
    output logic                            wn_rd               ,
    output logic [ADDR_WIDTH-1:0]           wn_addr             ,
    /***************** MULT1 interface *********************/
    output logic signed [DATA_WIDTH-1:0]    mult1_a    [0:N-1]  ,
    output logic signed [DATA_WIDTH-1:0]    mult1_b    [0:N-1]  ,
    input signed [2*DATA_WIDTH-1:0]         mult1_res  [0:N-1]  ,
    /***************** MULT2 interface *********************/
    output logic signed [DATA_WIDTH-1:0]    mult2_a    [0:N-1]  ,
    output logic signed [DATA_WIDTH-1:0]    mult2_b    [0:N-1]  ,
    input signed [2*DATA_WIDTH-1:0]         mult2_res  [0:N-1]  ,
    /***************** MULT3 interface *********************/
    output logic signed [DATA_WIDTH-1:0]    mult3_a    [0:N-1]  ,
    output logic signed [DATA_WIDTH-1:0]    mult3_b    [0:N-1]  ,
    input signed [2*DATA_WIDTH-1:0]         mult3_res  [0:N-1]  ,
    /***************** MULT4 interface *********************/
    output logic signed [DATA_WIDTH-1:0]    mult4_a    [0:N-1]  ,
    output logic signed [DATA_WIDTH-1:0]    mult4_b    [0:N-1]  ,
    input signed [2*DATA_WIDTH-1:0]         mult4_res  [0:N-1]  
    ///***************** ADD1 interface *********************/
    //output logic signed [DATA_WIDTH-1:0]    add1_a              ,
    //output logic signed [DATA_WIDTH-1:0]    add1_b              ,
    //input signed [DATA_WIDTH-1:0]           add1_sum            ,
    ///***************** ADD2 interface *********************/
    //output logic signed [DATA_WIDTH-1:0]    add2_a              ,
    //output logic signed [DATA_WIDTH-1:0]    add2_b              ,
    //input signed [DATA_WIDTH-1:0]           add2_sum            ,
    ///***************** ADD3 interface *********************/
    //output logic signed [DATA_WIDTH-1:0]    add3_a              ,
    //output logic signed [DATA_WIDTH-1:0]    add3_b              ,
    //input signed [DATA_WIDTH-1:0]           add3_sum            ,
);
// ---------- behavior model (just for module test) --------//
logic signed [DATA_WIDTH-1:0] add1_a [0:N-1];
logic signed [DATA_WIDTH-1:0] add1_b [0:N-1];
logic signed [DATA_WIDTH-1:0] add1_sum [0:N-1];
logic signed [DATA_WIDTH-1:0] add2_a [0:N-1];
logic signed [DATA_WIDTH-1:0] add2_b [0:N-1];
logic signed [DATA_WIDTH-1:0] add2_sum [0:N-1];
logic signed [DATA_WIDTH-1:0] add3_a [0:N-1];
logic signed [DATA_WIDTH-1:0] add3_b [0:N-1];
logic signed [DATA_WIDTH-1:0] add3_sum [0:N-1];

genvar j;
generate
    for(j=0;j<N;j=j+1) begin : ADDER_ARRAY
        assign add1_sum[j] = add1_a[j] + add1_b[j];
        assign add2_sum[j] = add2_a[j] + add2_b[j];
        assign add3_sum[j] = add3_a[j] + add3_b[j];
    end
endgenerate
// ----------------------------------------------------//

logic need_4by2;
logic radix4_done;
logic radix4by2_done;
logic pre_done;
logic post_done;
logic reverse_done;
logic cfft_done_pre;

logic radix4_start_pre;
logic pre_start_pre;
logic post_start_pre;
logic reverse_start_pre;
logic radix4_start;
logic pre_start;
logic post_start;
logic reverse_start;

logic [15:0] fft_len;
logic [ADDR_WIDTH-1:0]       src_data_base  [0:N-1];
logic [ADDR_WIDTH-1:0]       dest_data_base [0:N-1];
logic [ADDR_WIDTH-1:0]       wn_base        ;
logic [ADDR_WIDTH-1:0]       rev_base       ;
logic signed [ADDR_WIDTH-1:0] data_base_offset [0:N-1];


logic radix4_cnt;
logic [3:0] wn_rd_cnt;
logic signed [DATA_WIDTH-1:0]       cos_val_1;
logic signed [DATA_WIDTH-1:0]       sin_val_1;
logic signed [DATA_WIDTH-1:0]       cos_val_2;
logic signed [DATA_WIDTH-1:0]       sin_val_2;
logic signed [DATA_WIDTH-1:0]       cos_val_3;
logic signed [DATA_WIDTH-1:0]       sin_val_3;

assign need_4by2 = (rg_fft_len == 32 || rg_fft_len == 128 || rg_fft_len == 512 || rg_fft_len == 2048);

typedef enum logic [2:0] {IDLE, PRE, RADIX4, POST, REVERSE} fft_state_t;
fft_state_t fft_state_c,fft_state_n;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        fft_state_c <= IDLE;
    else
        fft_state_c <= fft_state_n;
end
always@(*) begin
    fft_state_n = fft_state_c;
    case(fft_state_c)
        IDLE : fft_state_n = cfft_start?    (need_4by2?   PRE : RADIX4) : IDLE;
        PRE:   fft_state_n = pre_done?  RADIX4 : PRE;
        RADIX4: begin
            if(need_4by2) begin
                if(radix4_done)
                    //fft_state_n = radix4by2_done?   POST : RADIX4;
                    fft_state_n = radix4by2_done?   (rg_bitreverse_flag?    REVERSE : IDLE) : RADIX4;
                else
                    fft_state_n = RADIX4;
            end
            else begin
                if(radix4_done)
                    fft_state_n = rg_bitreverse_flag?   REVERSE : IDLE;
                else
                    fft_state_n = RADIX4;
            end
        end
        POST:   fft_state_n = post_done?    (rg_bitreverse_flag?    REVERSE : IDLE) : POST;
        REVERSE: fft_state_n = reverse_done?    IDLE : REVERSE;
        default: fft_state_n = fft_state_c;
    endcase
end

assign radix4by2_done = radix4_done && radix4_cnt;

assign pre_start_pre = cfft_start && need_4by2;
assign radix4_start_pre = ((fft_state_c != RADIX4) && (fft_state_n == RADIX4)) || (need_4by2 && radix4_done && ~radix4by2_done);
assign post_start_pre = (fft_state_c != POST) && (fft_state_n == POST);
assign reverse_start_pre = (fft_state_c != REVERSE) && (fft_state_n == REVERSE);

assign cfft_done_pre = (fft_state_c != IDLE) && (fft_state_n == IDLE);

assign fft_len = need_4by2?  (rg_fft_len>>1) : rg_fft_len;

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        cfft_done <= 1'b0;
    else if(cfft_done_pre)
        cfft_done <= 1'b1;
    else 
        cfft_done <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        pre_start <= 1'b0;
    else if(pre_start_pre)
        pre_start <= 1'b1;
    else 
        pre_start <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        radix4_start <= 1'b0;
    else if(radix4_start_pre)
        radix4_start <= 1'b1;
    else 
        radix4_start <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        post_start <= 1'b0;
    else if(post_start_pre)
        post_start <= 1'b1;
    else 
        post_start <= 1'b0;
end


always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        reverse_start <= 1'b0;
    else if(reverse_start_pre)
        reverse_start <= 1'b1;
    else 
        reverse_start <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        radix4_cnt <= 1'b0;
    else if(need_4by2 && radix4_done)
        radix4_cnt <= radix4by2_done?   1'b0 : radix4_cnt + 1'b1;
end

assign wn_base  = (rg_wn_base >> 2);
assign rev_base  = (rg_rev_base >> 2);

genvar k;
generate 
    for(k=0;k<N;k=k+1) begin : BASE_ADDR_BLOCK
        assign src_data_base[k] = radix4_cnt?  ((rg_src_data_base[k] >> 2) + rg_fft_len) : (rg_src_data_base[k] >> 2);
        assign dest_data_base[k] = radix4_cnt?  ((rg_dest_data_base[k] >> 2) + rg_fft_len) : (rg_dest_data_base[k] >> 2);

        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                data_base_offset[k] <= 'd0;
            else if(cfft_start)
                data_base_offset[k] <= (dest_data_base[k] - src_data_base[k]);
        end
    end
endgenerate

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        cos_val_1 <= 'sd0;
    else if(fft_state_c == RADIX4 && wn_rd_cnt == 4)
        cos_val_1 <= $signed(wn_rdata);
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        sin_val_1 <= 'sd0;
    else if(fft_state_c == RADIX4 && wn_rd_cnt == 5)
        sin_val_1 <= $signed(wn_rdata);
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        cos_val_2 <= 'sd0;
    else if(fft_state_c == RADIX4 && wn_rd_cnt == 2)
        cos_val_2 <= $signed(wn_rdata);
    else if(fft_state_c == PRE && wn_rd_cnt == 2)
        cos_val_2 <= $signed(wn_rdata);
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        sin_val_2 <= 'sd0;
    else if(fft_state_c == RADIX4 && wn_rd_cnt == 3)
        sin_val_2 <= $signed(wn_rdata);
    else if(fft_state_c == PRE && wn_rd_cnt == 3)
        sin_val_2 <= $signed(wn_rdata);
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        cos_val_3 <= 'sd0;
    else if(fft_state_c == RADIX4 && wn_rd_cnt == 6)
        cos_val_3 <= $signed(wn_rdata);
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        sin_val_3 <= 'sd0;
    else if(fft_state_c == RADIX4 && wn_rd_cnt == 7)
        sin_val_3 <= $signed(wn_rdata);
end

genvar i;
generate
    for(i=0;i<N;i=i+1) begin : RADIX_BANK
        if(i==0) begin
            radix4 # (
                .ADDR_WIDTH (ADDR_WIDTH),
                .DATA_WIDTH (DATA_WIDTH)
            ) radix4_inst (
                .clk                (clk                 ) ,
                .rstn               (rstn                ) ,
                .fft_start          (radix4_start        ) ,
                .fft_done           (radix4_done         ) ,
                .pre_start          (pre_start           ) ,
                .pre_done           (pre_done            ) ,
                .post_start         (post_start          ) ,
                .post_done          (post_done           ) ,
                .reverse_start      (reverse_start       ) ,
                .reverse_done       (reverse_done        ) ,
                .fft_len            (fft_len             ) ,
                .rg_bitrevlen       (rg_bitrevlen        ) ,
                .rg_twid            (rg_twid             ) ,
                .rg_ifft_flag       (rg_ifft_flag        ) ,
                .rg_bitreverse_flag (rg_bitreverse_flag  ) ,
                .src_data_base      (src_data_base  [i]  ) ,
                .dest_data_base     (dest_data_base [i]  ) ,
                .wn_base            (wn_base             ) ,
                .rev_base           (rev_base            ) ,
                .switch_flag        (radix4_cnt          ) ,
                .data_base_offset   (data_base_offset[i] ) ,
                .wn_rd_cnt          (wn_rd_cnt           ) , 
                .need_post          (need_4by2           ) ,
                .data_rdata         (data_rdata      [i] ) ,
                .data_wdata         (data_wdata      [i] ) ,
                .data_wmask         (data_wmask      [i] ) ,
                .data_wr            (data_wr         [i] ) ,
                .data_rd            (data_rd         [i] ) ,
                .data_addr          (data_addr       [i] ) ,
                .wn_rdata           (wn_rdata            ) ,
                .wn_wdata           (wn_wdata            ) ,
                .wn_wmask           (wn_wmask            ) ,
                .wn_wr              (wn_wr               ) ,
                .wn_rd              (wn_rd               ) ,
                .wn_addr            (wn_addr             ) ,
                .cos_val_1          (cos_val_1           ) ,
                .sin_val_1          (sin_val_1           ) ,
                .cos_val_2          (cos_val_2           ) ,
                .sin_val_2          (sin_val_2           ) ,
                .cos_val_3          (cos_val_3           ) ,
                .sin_val_3          (sin_val_3           ) ,
                .mult1_a            (mult1_a         [i] ) ,
                .mult1_b            (mult1_b         [i] ) ,
                .mult1_res          (mult1_res       [i] ) ,
                .mult2_a            (mult2_a         [i] ) ,
                .mult2_b            (mult2_b         [i] ) ,
                .mult2_res          (mult2_res       [i] ) ,
                .mult3_a            (mult3_a         [i] ) ,
                .mult3_b            (mult3_b         [i] ) ,
                .mult3_res          (mult3_res       [i] ) ,
                .mult4_a            (mult4_a         [i] ) ,
                .mult4_b            (mult4_b         [i] ) ,
                .mult4_res          (mult4_res       [i] ) ,
                .add1_a             (add1_a          [i] ) ,
                .add1_b             (add1_b          [i] ) ,
                .add1_sum           (add1_sum        [i] ) ,
                .add2_a             (add2_a          [i] ) ,
                .add2_b             (add2_b          [i] ) ,
                .add2_sum           (add2_sum        [i] ) ,
                .add3_a             (add3_a          [i] ) ,
                .add3_b             (add3_b          [i] ) ,
                .add3_sum           (add3_sum        [i] ) 
            );
        end
        else begin
            radix4_simple # (
                .ADDR_WIDTH (ADDR_WIDTH),
                .DATA_WIDTH (DATA_WIDTH)
            ) radix4_simple_inst (
                .clk                (clk                 ) ,
                .rstn               (rstn                ) ,
                .fft_start          (radix4_start        ) ,
                .pre_start          (pre_start           ) ,
                .post_start         (post_start          ) ,
                .reverse_start      (reverse_start       ) ,
                .fft_len            (fft_len             ) ,
                .rg_bitrevlen       (rg_bitrevlen        ) ,
                .rg_twid            (rg_twid             ) ,
                .rg_ifft_flag       (rg_ifft_flag        ) ,
                .rg_bitreverse_flag (rg_bitreverse_flag  ) ,
                .src_data_base      (src_data_base  [i]  ) ,
                .dest_data_base     (dest_data_base [i]  ) ,
                .switch_flag        (radix4_cnt          ) ,
                .data_base_offset   (data_base_offset[i] ) ,
                .need_post          (need_4by2           ) ,
                .data_rdata         (data_rdata      [i] ) ,
                .data_wdata         (data_wdata      [i] ) ,
                .data_wmask         (data_wmask      [i] ) ,
                .data_wr            (data_wr         [i] ) ,
                .data_rd            (data_rd         [i] ) ,
                .data_addr          (data_addr       [i] ) ,
                .wn_rdata           (wn_rdata            ) ,
                .cos_val_1          (cos_val_1           ) ,
                .sin_val_1          (sin_val_1           ) ,
                .cos_val_2          (cos_val_2           ) ,
                .sin_val_2          (sin_val_2           ) ,
                .cos_val_3          (cos_val_3           ) ,
                .sin_val_3          (sin_val_3           ) ,
                .mult1_a            (mult1_a         [i] ) ,
                .mult1_b            (mult1_b         [i] ) ,
                .mult1_res          (mult1_res       [i] ) ,
                .mult2_a            (mult2_a         [i] ) ,
                .mult2_b            (mult2_b         [i] ) ,
                .mult2_res          (mult2_res       [i] ) ,
                .mult3_a            (mult3_a         [i] ) ,
                .mult3_b            (mult3_b         [i] ) ,
                .mult3_res          (mult3_res       [i] ) ,
                .mult4_a            (mult4_a         [i] ) ,
                .mult4_b            (mult4_b         [i] ) ,
                .mult4_res          (mult4_res       [i] ) ,
                .add1_a             (add1_a          [i] ) ,
                .add1_b             (add1_b          [i] ) ,
                .add1_sum           (add1_sum        [i] ) ,
                .add2_a             (add2_a          [i] ) ,
                .add2_b             (add2_b          [i] ) ,
                .add2_sum           (add2_sum        [i] ) ,
                .add3_a             (add3_a          [i] ) ,
                .add3_b             (add3_b          [i] ) ,
                .add3_sum           (add3_sum        [i] ) 
            );
        end
    end
    endgenerate

endmodule