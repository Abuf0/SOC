module amp_cal #(
    parameter FDT_ROW_N = 5,
    parameter FDT_COL_N = 5
)(
    input               clk                         ,
    input               rstn                        ,
    input               soft_clr                    ,
    input [2:0]         rg_amp_therm_comp_ratio_0   ,
    input [2:0]         rg_amp_therm_comp_ratio_1   ,
    input [2:0]         rg_amp_therm_comp_ratio_2   ,
    input [2:0]         rg_amp_therm_comp_ratio_3   ,
    input [2:0]         rg_amp_therm_comp_ratio_4   ,
    input [2:0]         rg_amp_data_ratio           ,
    input               rg_fifo_empty_dummy_en      ,
    input               amp_enable                  ,
    input               amp_iq_data_to_fifo_en      ,
    input               adc_data_in_vld             ,   // adc数据：input
    input [11:0]        adc0_data_in                ,   // adc数据：input
    input [4:0]         fdt_therm_comp_one_hot      ,
    /* AMP MEAN计算*/
    output logic        amp_mean_vld                ,
    output logic        amp_mean                    ,
    output logic        amp_done                    ,
    output logic        amp_trig_norm               ,
    /* AMP计算的cache ctrl */
    output logic        cache_ena                   ,
    output logic        cache_wena                  ,
    output logic [4:0]  cache_addr                  ,
    output logic [53:0] cache_wdata                 ,
    input [63:0]        cache_rdata                 ,
    /* 使能IQ时把计算结果送到FIFO */
    output logic [11:0] amp_iq_data_to_fifo         ,
    output logic        amp_iq_vld_to_fifo
);
localparam CNT_PHASE0     = 2'd0;
localparam CNT_PHASE180   = 2'd1;
localparam CNT_PHASE90    = 2'd2;
localparam CNT_PHASE270   = 2'd3;

typedef enum logic [2:0] {IDLE, PHASE0T90, SQUARE_Q, SQUARE_I, SQRT_IN, WAIT_SQRT, MEAN, DONE} amp_state_t;
amp_state_t amp_state_s, amp_state_n;

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        amp_state_s <= IDLE;
    else if(soft_clr)
        amp_state_s <= IDLE;
    else
        amp_state_s <= amp_state_n;
end

always@(*) begin
    amp_state_n = amp_state_s;
    case(amp_state_s)
        IDLE:   amp_state_n = amp_enable?   PHASE0T90 : IDLE;
        PHASE0T90:  amp_state_n = phase0t90_done?   SQUARE_I : PHASE0T90;
        SQUARE_I:   amp_state_n = square_i_done?    SQUARE_Q : SQUARE_I;
        SQUARE_Q:   amp_state_n = square_q_done?    SQRT_IN : SQUARE_Q;
        SQRT_IN:    amp_state_n = sqrt_in_done?  (phase_cnt_ov?  WAIT_SQRT : SQUARE_I) : SQRT_IN;
        WAIT_SQRT:  amp_state_n = wait_sqrt_done?   MEAN : WAIT_SQRT;
        MEAN:       amp_state_n = mean_done?    DONE : MEAN;
        DONE:       amp_state_n = IDLE;
        default:;
    endcase
end

assign phase0t90_done = (amp_state_s == PHASE0T90) && (phase_cnt == CNT_PHASE90) && col_cnt_ov;
assign square_i_done = (amp_state_s == SQUARE_I) && (square_i_cnt == 2'd2);
assign square_q_done = (amp_state_s == SQUARE_Q) && adc_data_in_vld;
assign sqrt_in_done = (amp_state_s == SQRT_IN);
assign wait_sqrt_done = (amp_state_s == WAIT_SQRT) && sqrt_out_vld;
assign mean_done = (amp_state_s == MEAN) && div_out_vld;

assign row_cnt_ov = (row_cnt == FDT_ROW_N-1) && adc_data_save_done; // adc_data_save_done = adc_data_vld_d1
assign col_cnt_ov = (col_cnt == FDT_COL_N-1) && row_cnt_ov;
assign phase_cnt_ov = (phase_cnt == CNT_PHASE270) && col_cnt_ov;

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        row_cnt <= 3'd0;
    else if(soft_clr || row_cnt_ov)
        row_cnt <= 3'd0;
    else if(adc_data_save_done)
        row_cnt <= row_cnt + 3'd1;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        col_cnt <= 3'd0;
    else if(soft_clr || col_cnt_ov)
        col_cnt <= 3'd0;
    else if(row_cnt_ov)
        col_cnt <= col_cnt + 3'd1;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        phase_cnt <= 2'd0;
    else if(soft_clr || phase_cnt_ov)
        phase_cnt <= 2'd0;
    else if(col_cnt_ov)
        phase_cnt <= phase_cnt + 2'd1;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        square_i_cnt <= 2'd0;
    else if(soft_clr || square_i_done)
        square_i_cnt <= 2'd0;
    else if(amp_state_s == SQUARE_I)
        square_i_cnt <= square_i_cnt + 2'd1;
end

// adc data proc
assign data_IQ_cal_en = (phase_cnt == CNT_PHASE180 || phase_cnt == CNT_PHASE270) && adc_data_in_vld;    // 0-180-90-270
assign adc_data_cut = {1'b0, adc0_data_in[11:1]};
assign cache_rdata_array = cache_rdata[59:0];
assign cache_rdata_row = cache_rdata_array[row_cnt];
assign data_IQ = data_IQ_cal_en?    ($signed(cache_rdata_row) - $signed(adc_data_cut)) : 12'sd0;

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        adc_data_save_done <= 1'b0;
    else
        adc_data_save_done <= adc_data_in_vld;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        amp_cache <= 60'd0;
    else if(soft_clr)
        amp_cache <= 60'd0;
    else begin
        if((phase_cnt == CNT_PHASE0 || phase_cnt == CNT_PHASE90) && adc_data_in_vld)
            amp_cache[row_cnt] <= adc_data_cut;
        else if(phase_cnt == CNT_PHASE180 && adc_data_in_vld)
            amp_cache[row_cnt] <= data_IQ;
        else if(amp_state_s == SQUARE_I && square_out_vld) begin
            amp_cache[2] <= square_out_data[11:0];
            amp_cache[3] <= square_out_data[23:12];
        end
        else if(amp_state_s == SQUARE_Q && square_out_vld) begin
            amp_cache[0] <= square_out_data[11:0];
            amp_cache[1] <= square_out_data[23:12];
        end
    end
end

always@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        cache_ena <= 1'b0;
        cache_wena <= 1'b0;
        cache_addr <= 5'd0;
    end
    else if((phase_cnt == CNT_PHASE0 || phase_cnt == CNT_PHASE180) && (row_cnt == FDT_ROW_N-3'd1) && adc_data_in_vld) begin   
        cache_ena <= 1'b1;
        cache_wena <= 1'b1;
        cache_addr <= `DATA_COMMON_BASE_ADDR + {2'b0, col_cnt};
    end
    else if(phase_cnt == CNT_PHASE0 && row_cnt_ov && col_cnt_ov) begin   
        cache_ena <= 1'b1;
        cache_wena <= 1'b0;
        cache_addr <= `DATA_COMMON_BASE_ADDR + 5'd0;
    end
    else if(phase_cnt == CNT_PHASE180 && row_cnt_ov && !col_cnt_ov) begin   
        cache_ena <= 1'b1;
        cache_wena <= 1'b0;
        cache_addr <= `DATA_COMMON_BASE_ADDR + {2'b0, col_cnt} + 5'd1;
    end
    else if((phase_cnt == CNT_PHASE90)  && (row_cnt == FDT_ROW_N-3'd1) && adc_data_in_vld) begin   
        cache_ena <= 1'b1;
        cache_wena <= 1'b1;
        cache_addr <= `DATA_COMMON_BASE_ADDR + FDT_COL_N + {2'b0, col_cnt};
    end
    else if(amp_state_s == SQUARE_I && square_i_cnt < 2'd2) begin   
        cache_ena <= 1'b1;
        cache_wena <= 1'b0;
        if(square_i_cnt == 2'd0)
            cache_addr <= `DATA_COMMON_BASE_ADDR + {2'b0, col_cnt};
        else if(square_i_cnt == 2'd1)
            cache_addr <= `DATA_COMMON_BASE_ADDR + FDT_COL_N + {2'b0, col_cnt};
    end
    else begin
        cache_ena <= 1'b0;
        cache_wena <= 4'b0;
    end
end

assign cache_wdata = (cache_ena & cache_wena)?  {4'd0, amp_cache} : 64'd0;

assign suqare_in_vld = square_i_done || square_q_done;
assign square_in_data = (amp_state_s == SQUARE_Q)?  data_IQ : (amp_state_s == SQUARE_I)?    cache_rdata_row : 12'd0;

// sqrt calc
assign sqrt_in_vld = (amp_state_s == SQRT_IN);
assign square_data_Q_unsign_24b = amp_cache[1:0];
assign square_data_I_unsign_24b = amp_cache[3:2];
assign sqrt_in_data = {1'b0, square_data_I_unsign_24b} + {1'b0, square_data_Q_unsign_24b};
assign sqrt_out_data_12b = sqrt_out_data[11:0];
assign sqrt_out_data_14b = {2'b0, sqrt_out_data_12b};

always@(*) begin
    amp_therm_comp_ratio = 3'b010;
    case(fdt_therm_comp_one_hot)
        5'h10 : amp_therm_comp_ratio = rg_amp_therm_comp_ratio_0;
        5'h08 : amp_therm_comp_ratio = rg_amp_therm_comp_ratio_1;
        5'h04 : amp_therm_comp_ratio = rg_amp_therm_comp_ratio_2;
        5'h02 : amp_therm_comp_ratio = rg_amp_therm_comp_ratio_3;
        5'h01 : amp_therm_comp_ratio = rg_amp_therm_comp_ratio_4;
        default: ;
    endcase
end

always@(*) begin
    therm_comp_dout = sqrt_out_data_14b;
    case(amp_therm_comp_ratio)
        3'b000 : therm_comp_dout = (sqrt_out_data_14b >> 2);
        3'b001 : therm_comp_dout = (sqrt_out_data_14b >> 1);
        3'b010 : therm_comp_dout = sqrt_out_data_14b;
        3'b011 : therm_comp_dout = (sqrt_out_data_14b << 1);
        3'b100 : therm_comp_dout = (sqrt_out_data_14b << 2);
        default: ;
    endcase
end

assign amp_after_ratio_14b = therm_comp_dout >> rg_amp_data_ratio;

int_sat_proc #(
    .SIGNED_IN  ( 1  ),
    .DW_IN      ( 20 ),
    .DW_OUT     ( 16 )
) amp_ratio_sat(
    .data_in    ( amp_after_ratio_14b ),
    .data_out   ( amp_after_ratio_12b )
);

// root acc calc
always@(posedge clk or negedge rstn) begin
    if(~rstn)
        amp_acc <= 16'd0;
    else if(mean_done)
        amp_acc <= 16'd0;
    else if(sqrt_out_vld)
        amp_acc <= amp_acc + {4'd0, amp_after_ratio_12b[11:0]};
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        amp_acc_vld <= 1'b0;
    else if(wait_sqrt_done)
        amp_acc_vld <= 1'b1;
    else if(amp_acc_vld)
        amp_acc_vld <= 1'b0;
end

assign div_in_vld = amp_acc_vld;
assign div_in_data = div_in_vld?    amp_acc : 16'd0;
assign div_in_data_signed = {1'b0, div_in_data};
assign div_out_data = div_out_data_signed[15:0];

always@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        amp_mean <= 12'd0;
        amp_neam_vld <= 1'b0;
    end
    else if(div_out_vld) begin
        amp_mean <= div_out_data[11:0];
        amp_neam_vld <= 1'b1;    
    end
    else
        amp_neam_vld <= 1'b0;
end

assign amp_iq_data_off_code = {~data_IQ[11], data_IQ[10:0]};    // offset code, range [0,4095]
assign amp_iq_data_dummy_hit = (rg_fifo_empty_dummy_en && (amp_iq_data_off_code != 12'd4095));
assign amp_iq_data_off_code_dmy = amp_iq_data_dummy_hit?    (amp_iq_data_off_code + 12'd1) : amp_iq_data_off_code;

assign amp_iq_data_to_fifo = amp_iq_data_to_fifo_en?    amp_iq_data_off_code_dmy : 12'd0;
assign amp_iq_vld_to_fifo = amp_iq_data_to_fifo_en?  (phase_cnt == CNT_PHASE180 || phase_cnt == CNT_PHASE270) && adc_data_in_vld : 1'b0;

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        amp_done <= 1'b0;
    else if(amp_done)
        amp_done <= 1'b0;
    else if((amp_state_s==PHASE0T90 && adc_data_save_done && !phase0t90_done) || (square_i_done && row_cnt==3'd0 && col_cnt==3'd0) || (amp_state_s==DONE))
        amp_done <= 1'b1;
end

assign amp_trig_norm = amp_mean_vld;

SignMultiplier #(
    .IN_DW  ( 12    ),
    .reg_out( 0     )
) sign_mul_inst(
    .clk        ( clk               ),
    .rstn       ( rstn              ),
    .din_A      ( square_in_data    ),
    .din_B      ( square_in_data    ),
    .din_vld    ( square_in_vld     ),
    .dout       ( square_out_data   ),
    .dout_vld   ( square_out_vld    )
);

Sqrt_unsigned Sqrt_inst(
    .clk        ( clk                   ),
    .rstn       ( rstn                  ),
    .din        ( {7'b0, sqrt_in_data}  ),
    .din_vld    ( sqrt_in_vld           ),
    .dout       ( sqrt_out_data         ),
    .dout_vld   ( sqrt_out_vld          )
);

signed_divider #(
    .L_DIVN( 17  ),
    .L_DIVR( 6   )   
) div_inst(
    .clk            (clk                ),
    .rstn           (rstn               ),
    .dividend       (div_in_data_signed ),
    .divisor        (6'sd25             ),
    .div_din_vld    (div_in_vld         ),
    .div_busy       (                   ),
    .div_quotient   (div_out_data_signed),
    .div_remainder  (                   ),
    .div_dout_vld   (div_out_vld        ),
    .divide_by_0    (                   )  
);

endmodule