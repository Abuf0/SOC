module moce_cfft #(
    parameter ADDR_WIDTH = 17,
    parameter DATA_WIDTH = 32,
    parameter LADDR_WIDTH = 4
)(
    input                                   clk                 ,
    input                                   rstn                ,
    /**************** control ****************/
    input                                   cfft_start          ,
    output logic                            cfft_done           ,
    /**************** config ****************/
    input        [9:0]                      rg_bitrevlen        ,
    input        [15:0]                     rg_fft_len          ,
    input        [31:0]                     rg_twid             ,
    input                                   rg_ifft_flag        ,
    input                                   rg_bitreverse_flag  ,
    /**************** data memory interface ****************/
    input        [DATA_WIDTH-1:0]           data_rdata          ,
    output logic [DATA_WIDTH-1:0]           data_wdata          ,
    output logic [DATA_WIDTH/8-1:0]         data_wmask          ,
    output logic                            data_wr             ,
    output logic                            data_rd             ,
    output logic [ADDR_WIDTH-1:0]           data_addr           ,
    /**************** wn/table memory interface ****************/
    input        [DATA_WIDTH-1:0]           wn_rdata            ,
    output logic [DATA_WIDTH-1:0]           wn_wdata            ,
    output logic [DATA_WIDTH/8-1:0]         wn_wmask            ,
    output logic                            wn_wr               ,
    output logic                            wn_rd               ,
    output logic [ADDR_WIDTH-1:0]           wn_addr             ,
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

logic need_4by2;
logic radix4_done;
logic radix4by2_done;
logic pre_done;
logic post_done;
logic reverse_done;
logic cfft_done_pre;

logic radix4_start;
logic pre_start;
logic post_start;
logic reverse_start;

logic [11:0] fft_len;

logic radix4_cnt;

assign need_4by2 = (rg_fft_len == 32 || rg_fft_len == 128 || rg_fft_len == 512 || rg_fft_len == 2048);

assign fft_len = need_4by2?  (rg_fft_len>>1) : rg_fft_len;

typedef enum logic [2:0] {IDLE, PRE, RADIX4, POST, REVERSE } fft_state_t;
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
                    fft_state_n = radix4by2_done?   POST : RADIX4;
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

assign pre_start = cfft_start && need_4by2;
assign radix4_start = ((fft_state_c != RADIX4) && (fft_state_n == RADIX4)) || (need_4by2 && radix4_done && ~radix4by2_done);
assign post_start = (fft_state_c != POST) && (fft_state_n == POST);
assign reverse_start = (fft_state_c != REVERSE) && (fft_state_n == REVERSE);

assign cfft_done_pre = (fft_state_c != IDLE) && (fft_state_n == IDLE);

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
        radix4_cnt <= 1'b0;
    else if(need_4by2 && radix4_done)
        radix4_cnt <= radix4by2_done?   1'b0 : radix4_cnt + 1'b1;
end

radix4 # (
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .LADDR_WIDTH(LADDR_WIDTH)
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
    .data_rdata         (data_rdata          ) ,
    .data_wdata         (data_wdata          ) ,
    .data_wmask         (data_wmask          ) ,
    .data_wr            (data_wr             ) ,
    .data_rd            (data_rd             ) ,
    .data_addr          (data_addr           ) ,
    .wn_rdata           (wn_rdata            ) ,
    .wn_wdata           (wn_wdata            ) ,
    .wn_wmask           (wn_wmask            ) ,
    .wn_wr              (wn_wr               ) ,
    .wn_rd              (wn_rd               ) ,
    .wn_addr            (wn_addr             ) ,
    .mem1_rdata         (mem1_rdata          ) ,
    .mem1_wdata         (mem1_wdata          ) ,
    .mem1_addr          (mem1_addr           ) ,
    .mem1_wr            (mem1_wr             ) ,
    .mem1_rd            (mem1_rd             ) ,
    .mem2_rdata         (mem2_rdata          ) ,
    .mem2_wdata         (mem2_wdata          ) ,
    .mem2_addr          (mem2_addr           ) ,
    .mem2_wr            (mem2_wr             ) ,
    .mem2_rd            (mem2_rd             ) ,
    .mem3_rdata         (mem3_rdata          ) ,
    .mem3_wdata         (mem3_wdata          ) ,
    .mem3_addr          (mem3_addr           ) ,
    .mem3_wr            (mem3_wr             ) ,
    .mem3_rd            (mem3_rd             ) ,
    .mem4_rdata         (mem4_rdata          ) ,
    .mem4_wdata         (mem4_wdata          ) ,
    .mem4_addr          (mem4_addr           ) ,
    .mem4_wr            (mem4_wr             ) ,
    .mem4_rd            (mem4_rd             ) ,
    .mult1_a            (mult1_a             ) ,
    .mult1_b            (mult1_b             ) ,
    .mult1_res          (mult1_res           ) ,
    .mult2_a            (mult2_a             ) ,
    .mult2_b            (mult2_b             ) ,
    .mult2_res          (mult2_res           ) ,
    .add1_a             (add1_a              ) ,
    .add1_b             (add1_b              ) ,
    .add1_sum           (add1_sum            ) ,
    .add2_a             (add2_a              ) ,
    .add2_b             (add2_b              ) ,
    .add2_sum           (add2_sum            ) ,
    .add3_a             (add3_a              ) ,
    .add3_b             (add3_b              ) ,
    .add3_sum           (add3_sum            ) 
);


endmodule