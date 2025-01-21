module NN_layer_ctrl(
    input                       clk                          ,
    input                       rstn                         ,
    /* 一轮NN计算控制信号 */
    input                       NN_layer_start               ,
    output logic                NN_layer_done                ,
    /* 每层LAYER的子层数/是否跳过L1矩阵乘/是否做ReLU/参数&数据的存储地址/data ratio */
    input                       subl_num                     ,
    input                       jump_sub1_mul                ,    
    input                       need_relu                    ,
    input        [5:0]          subl0_coef_base_addr         , 
    input        [5:0]          subl1_coef_base_addr         , 
    input        [4:0]          subl0_data_base_addr         , 
    input        [4:0]          subl1_data_base_addr         , 
    input        [3:0]          subl0_weight_addr_num        , 
    input        [3:0]          subl1_weight_addr_num        , 
    input        [0:0]          subl0_data_addr_num_log2     , 
    input        [0:0]          subl1_data_addr_num_log2     , 
    input        [2:0]          subl0_data_ratio             ,
    input        [2:0]          subl1_data_ratio             ,
    /* 参数coef cache的控制 */
    output logic                coef_ena                     ,
    output logic [5:0]          coef_addr                    ,
    input        [63:0]         coef_rdata                   ,
    /* 数据data cache的控制 */
    output logic                cache_ena                    ,
    output logic                cache_wena                   ,
    output logic [5:0]          cache_addr                   ,
    output logic [63:0]         cache_wdata                  ,
    input        [63:0]         cache_rdata                  ,
    /* NN计算结果 */
    output logic [7:0] [7:0]    NN_layer_out                 ,  // A[7:0] · B[7:0] + BIAS[7:0] // 8个8bit的数据矩阵乘加结果
    output logic                NN_layer_out_vld     
);

// FSM @ NN layer：子层L0 --> 子层L1
typedef enum logic [2:0] {IDLE, SUBL0_MUL, SUBL0_ADD, SUBL1_MUL, SUBL1_ADD, SUML_SUM} nn_layer_state_t;
nn_layer_state_t nn_layer_state_s, nn_layer_state_n;

always @(posedge clk or negedge rstn) begin
    if(~rstn)
        nn_layer_state_s <= IDLE;
    else
        nn_layer_state_s <= nn_layer_state_n;
end

always@(*) begin
    nn_layer_state_n = nn_layer_state_s;
    case(nn_layer_state_s)
        IDLE:   nn_layer_state_n = NN_layer_start?  SUBL0_MUL : IDLE;
        SUBL0_MUL:  nn_layer_state_n = subl0_mul_done?  SUBL0_ADD : SUBL0_MUL;
        SUBL0_ADD:  nn_layer_state_n = subl0_add_done?  ((subl_num==1'd0)?   SUBL_SUM : jump_sub1_mul?   SUBL1_ADD : SUBL1_MUL) : SUBL0_ADD;
        SUBL1_MUL:  nn_layer_state_n = subl1_mul_done?  SUBL1_ADD : SUBL1_MUL;
        SUBL1_ADD:  nn_layer_state_n = subl1_add_done?  SUBL_SUM : SUBL1_ADD;
        SUBL_SUM:   nn_layer_state_n = subl_sum_done?   IDLE : SUBL_SUM;
        default:    nn_layer_state_n = IDLE;
end

assign subl0_mul_done = (nn_layer_state_s == SUBL0_MUL) && state_cnt == subl0_weight_addr_num;
assign subl0_add_done = (nn_layer_state_s == SUBL0_ADD) && state_cnt == 4'd2;
assign subl1_mul_done = (nn_layer_state_s == SUBL1_MUL) && state_cnt == subl1_weight_addr_num;
assign subl1_add_done = (nn_layer_state_s == SUBL1_ADD) && state_cnt == 4'd2;
assign subl_sum_done  = (nn_layer_state_s == SUBL_SUM ) && state_cnt == 4'd2;

always @(posedge clk or negedge rstn) begin
    if(~rstn)
        state_cnt <= 'd0;
    else if(nn_layer_state_s != nn_layer_state_n)
        state_cnt <= 'd0;
    else if(nn_layer_state_s != IDLE)
        state_cnt <= state_cnt + 4'd1;
end

// 参数控制，包括weight和bias
always @(posedge clk or negedge rstn) begin
    if(~rstn) begin
        coef_ena <= 1'b0;
        coef_addr <= 6'd0;
    end
    else if(nn_layer_state_s == SUBL0_MUL) begin
        coef_ena <= 1'b1;
        coef_addr <= subl0_coef_base_addr + state_cnt;  // 一个coef地址存64bit数据，参数在MUL阶段作为乘数矩阵
    end
    else if(nn_layer_state_s == SUBL0_ADD) begin
        coef_ena <= (state_cnt == 5'd1)?    1'b1 : 1'b0;    // bias在ADD阶段读出一次
        coef_addr <= subl0_coef_base_addr + subl0_weight_addr_num + 5'd1;  // bias
    end
    else if(nn_layer_state_s == SUBL1_MUL) begin
        coef_ena <= 1'b1;
        coef_addr <= subl1_coef_base_addr + state_cnt; 
    end
    else if(nn_layer_state_s == SUBL1_ADD) begin
        coef_ena <= (state_cnt == 5'd1)?    1'b1 : 1'b0;
        coef_addr <= subl1_coef_base_addr + subl1_weight_addr_num + 5'd1;  
    end
    else begin
        coef_ena <= 1'b0;
    end
end

// 数据控制，包括input和累加 //
assign subl0_state = (nn_layer_state_s == SUBL0_MUL || nn_layer_state_s == SUBL0_ADD);
assign subl1_state = (nn_layer_state_s == SUBL1_MUL || nn_layer_state_s == SUBL1_ADD);

assign data_addr_num_log2 = subl0_state?    subl0_data_addr_num_log2 : subl1_state?  subl1_data_addr_num_log2 : 1'd0;
assign data_addr_cnt = (data_addr_num_log2 == 1'd1)?    {4'd0, state_cnt[0]} : 5'd0;

always @(posedge clk or negedge rstn) begin
    if(~rstn) begin
        cache_ena <= 1'b0;
        cache_wena <= 1'b0;
        cache_addr <= 5'd0;
    end
    else if(nn_layer_state_s == SUBL0_MUL && state_cnt <= subl0_weight_addr_num) begin
        cache_ena <= 1'b1;
        cache_wena <= 1'b0;
        cache_addr <= subl0_data_base_addr + data_addr_cnt;  // 一个cache地址存储64bit数据
    end
    else if(nn_layer_state_s == SUBL1_MUL && state_cnt <= subl1_weight_addr_num) begin
        cache_ena <= 1'b1;
        cache_wena <= 1'b0;
        cache_addr <= subl1_data_base_addr + data_addr_cnt;  // 读出数据，在MUL阶段作为乘数
    end
    else if(nn_layer_state_s == SUBL_SUM && state_cnt == 5'd1) begin
        cache_ena <= 1'b1;
        cache_wena <= 1'b1; // 计算子层IH+HH，写入累加结果，作为下一层的数据源地址
        cache_addr <= subl1_data_base_addr;  
    end
    else begin
        cache_ena <= 1'b0;
        cache_wena <= 1'b0;
    end
end

assign cache_wdata = (cache_ena && cache_wena)?  nn_hh_cache : 64'h0;   // 没一层NN layer数据输出

// 数据暂存结果cache //
always @(posedge clk or negedge rstn) begin
    if(~rstn) 
        nn_ih_cache <= 64'd0;
    else if(NN_layer_done)
        nn_ih_cache <= 64'd0;
    else if(subl0_state && mac_out_vld) // 8bit切片，64bit空间存储8个8bit mac计算结果
        nn_ih_cache[slice_cnt] <= mac_psum_out_8b;
    else if(subl0_add_bias_en)  // mac + bias计算结果
        nn_ih_cache <= ch8_adder_out_8b;
end

always @(posedge clk or negedge rstn) begin
    if(~rstn) 
        nn_hh_cache <= 64'd0;
    else if(NN_layer_done)
        nn_hh_cache <= 64'd0;
    else if(subl1_state && mac_out_vld) // 8bit切片，64bit空间存储8个8bit mac计算结果
        nn_hh_cache[slice_cnt] <= mac_psum_out_8b;
    else if(subl1_add_bias_en)  // mac + bias计算结果
        nn_hh_cache <= ch8_adder_out_8b;
    else if(subl1_sum_add_en)   // relu结果
        nn_hh_cache <= need_relu?   ch8_relu_Z_out : ch8_adder_out_8b;
end

always @(posedge clk or negedge rstn) begin
    if(~rstn) 
        cache_rdata_vld <= 1'b0;
    else if(cache_ena && ~cache_wena)   // cache读delay一拍
        cache_rdata_vld <= 1'b1;
    else if(cache_rdata_vld)
        cache_rdata_vld <= 1'b0;
end

always @(posedge clk or negedge rstn) begin
    if(~rstn) 
        rdata_cnt <= 'd0;
    else if(subl0_add_done || subl1_add_done)
        rdata_cnt <= 4'd0;
    else if(cache_rdata_vld)
        rdata_cnt <= rdata_cnt + 4'd1;
end

always @(posedge clk or negedge rstn) begin
    if(~rstn) 
        slice_cnt <= 'd0'
    else if(nn_layer_state_s != IDLE)
        slice_cnt <= (data_addr_num_log2 == 1'b1)?  rdata_cnt[3:1] : rdata_cnt[2:0];
end

always @(posedge clk or negedge rstn) begin
    if(~rstn) 
        subl0_bias_rdata_vld <= 1'b0;
    else if(nn_layer_state_s == SUBL0_ADD && state_cnt == 5'd2)
        subl0_bias_rdata_vld <= 1'b1;
    else if(subl0_bias_rdata_vld)
        subl0_bias_rdata_vld <= 1'b0;
end

always @(posedge clk or negedge rstn) begin
    if(~rstn) 
        subl1_bias_rdata_vld <= 1'b0;
    else if(nn_layer_state_s == SUBL1_ADD && state_cnt == 5'd2)
        subl1_bias_rdata_vld <= 1'b1;
    else if(subl1_bias_rdata_vld)
        subl1_bias_rdata_vld <= 1'b0;
end

assign subl0_add_bias_en = subl0_bias_rdata_vld;    // IH的bias
assign subl1_add_bias_en = subl1_bias_rdata_vld;    // HH的bias
assign subl_sum_add_en = (nn_layer_state_s == SUBL_SUM) && (state_cnt == 4'd1);    // IH + HH


// MAC计算单元控制
assign mac_in_vld = (nn_layer_state_s != IDLE) && cache_rdata_vld;
assign psum_in_mux_out = (data_addr_num_log2 == 1'b1)?  rdata_cnt[0] : 1'b0;
assign mac_psum_in = psum_in_mux_out?   mac_psum_out : 20'd0;

assign mac_A_in = mac_in_vld?   coef_rdata : 64'h0;
assign mac_B_in = mac_in_vld?   cache_rdata : 64'h0;

// (8,8)·(8,8)
mac_cal_unit mac_cal_inst(
    .clk         ( clk           ),
    .rstn        ( rstn          ),
    .in_valid    ( mac_in_vld    ),
    .A_in        ( mac_A_in      ),
    .B_in        ( mac_B_in      ),
    .psum_in     ( mac_psum_in   ),
    .psum_out    ( mac_psum_out  ),
    .out_valid   ( mac_out_vld   )
);

int_sat_proc #(
    .SIGNED_IN  ( 1  ),
    .DW_IN      ( 20 ),
    .DW_OUT     ( 16 )
) mac_psum_out_16b_sat(
    .data_in    ( mac_psum_out      ),
    .data_out   ( mac_psum_out_16b  )
);

assign data_ratio = subl0_state?    subl0_data_ratio : subl1_data_ratio;
assign mac_psum_out_ratio = $signed(mac_psum_out_16b) >>> data_ratio;

int_sat_proc #(
    .SIGNED_IN  ( 1  ),
    .DW_IN      ( 20 ),
    .DW_OUT     ( 16 )
) mac_psum_out_8b_sat(
    .data_in    ( mac_psum_out_ratio),
    .data_out   ( mac_psum_out_8b   )
);

// adder 计算单元控制
// ch8_adder_A_in ： MAC output / IH output
assign ch8_adder_A_in = subl0_add_bias_en?  nn_ih_cache :
                        subl1_add_bias_en?  nn_hh_cache :
                        subl_sum_add_en?    nn_ih_cache : 64'h0;
// ch8_adder_A_in ： bias参数值 / HH output
assign ch8_adder_B_in = subl0_add_bias_en?  coef_rdata :
                        subl1_add_bias_en?  coef_rdata :
                        subl_sum_add_en?    nn_hh_cache : 64'h0;

assign ch8_relu_A_in = (need_relu && subl_sum_add_en)?  ch8_adder_out_8b : 64'h0;

// (8,8) + (8,8)
ch8_adder #(
    .DW     ( 8 )
) ch8_adder_inst(
    .A_in   ( ch8_adder_A_in    ),
    .B_in   ( ch8_adder_B_in    ),
    .Z_out  ( ch8_adder_Z_out   )
);

// (8,8)饱和处理
genvar i;
generate
    for(i=0;i<8;i=i+1) begin: ch8_adder_sat_proc
        int_sat_proc #(
            .SIGNED_IN  ( 1 ),
            .DW_IN      ( 9 ),
            .DW_OUT     ( 8 )
        ) mac_psum_out_8b_sat(
            .data_in    ( ch8_adder_Z_out[i] ),
            .data_out   ( ch8_adder_out_8b[i])
        );  
    end
endgenerate

// (8,8) ReLU
ch8_relu #(
    .DW ( 8 )
) ch8_relu_inst(
    .A_in   ( ch8_relu_A_in  ),
    .Z_out  ( ch8_relu_Z_out )
);

// NN layer一层结束后的输出
assign NN_layer_out = cache_wdata;
assign NN_layer_out_vld = cache_ena && cache_wena;

assign NN_layer_done = subl_sum_done;

endmodule