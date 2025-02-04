module NN_unit(
    input               clk                         ,
    input               rstn                        ,
    /* NN layer data ratio */
    input [2:0]         rg_nn_ilayer_ih_data_ratio  ,
    input [2:0]         rg_nn_ilayer_hh_data_ratio  ,
    input [2:0]         rg_nn_hlayer_ih_data_ratio  ,
    input [2:0]         rg_nn_hlayer_hh_data_ratio  ,
    input [2:0]         rg_nn_flayer_data_ratio     ,
    /* 配置信号 */
    input               rg_label_seq_init_en        ,
    input               rg_label_dec_mode           ,   // 决策模式，0：MemSeq，1：Count
    input [4:0]         rg_label_up_memcnt_th       ,   // Count决策模式的up计数阈值
    input [4:0]         rg_label_dn_memcnt_th       ,   // Count决策模式的down计数阈值
    input [3:0]         rg_label_memseq_len         ,   // MemSeq长度
    /* FDT检测结果 */
    output logic        ro_fdt_result_up            ,
    output logic        ro_fdt_result_down          ,
    /* 软件清NN state */
    input               soft_clr                    ,
    /* coef memory interface */
    output logic        coef_ena                    ,
    output logic [5:0]  coef_addr                   ,
    input [63:0]        coef_rdata                  ,
    /* cache memory interface */
    output logic        cache_ena                   ,
    output logic        cache_wena                  ,
    output logic [5:0]  cache_addr                  ,
    output logic [63:0] cache_wdata                 ,
    input [63:0]        cache_rdata                 ,
    /* NN时序 */
    input               NN_unit_start               ,
    output logic        NN_unit_done                ,
    /* FDT检测结果编码 */
    output logic        dec_result                  ,
    output logic        dec_result_vld

);

typedef enum logic [2:0] {IDLE, INPUT_LAYER, HIDDEN_LAYER, FC_LAYER, LABEL_DEC, DONE} nn_state_t;
nn_state_t nn_state_s, nn_state_n;
always @(posedge clk or negedge rstn) begin
    if(~rstn)
        nn_state_s <= IDLE;
    else if(soft_clr)
        nn_state_s <= nn_state_n;
end
always@(*) begin
    nn_state_n = nn_state_s;
    case(nn_state_s)
        IDLE:   nn_state_n = idle_done?  INPUT_LAYER : IDLE;
        INPUT_LAYER:    nn_state_n = input_layer_done?  HIDDEN_LAYER : INPUT_LAYER;
        HIDDEN_LAYER:   nn_state_n = hidden_layer_done?  FC_LAYER : HIDDEN_LAYER;
        FC_LAYER:   nn_state_n = fc_layer_done?  LABEL_DEC : FC_LAYER;
        LABEL_DEC:  nn_state_n = label_dec_done?  DONE : LABEL_DEC;
        DONE:   nn_state_n = IDLE;
        default:    nn_state_n = IDLE;
end

assign idle_done = (nn_state_s == IDLE) && NN_unit_start;
assign input_layer_done = (nn_state_s == INPUT_LAYER) && NN_layer_done;
assign hidden_layer_done = (nn_state_s == HIDDEN_LAYER) && NN_layer_done;
assign fc_layer_done = (nn_state_s == FC_LAYER) && NN_layer_done;
assign label_dec_done = dec_result_vld;

assign NN_unit_done = (nn_state_s == DONE);

// 由于第一次h_0 = 0，可以跳过某些层的计算 //
always@(posedge clk or negedge rstn) begin
    if(~rstn)
        first_rnn <= 1'b1;
    else if(soft_clr)
        first_rnn <= 1'b1;
    else if(NN_unit_done)
        first_rnn <= 1'b0;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        NN_layer_start <= 1'b0;
    else if(nn_state_s == IDLE)
        NN_layer_start <= NN_unit_start;
    else if(nn_state_s == INPUT_LAYER || nn_state_s == HIDDEN_LAYER)
        NN_layer_start <= NN_layer_done;
    else
        NN_layer_start <= 1'b0;
end

/*
Data cache(64bit)
 ------------------------------------------------------
|   AMP Mean    |   0x00~0x03   |   amp mean output    |
 ------------------------------------------------------
|   NORM        |   0x04~0x05   |   norm output        |
 ------------------------------------------------------
|               |   0x06        |   INPUT LAYER output |
                 ---------------------------------------
|      NN       |   0x07        |   HIDDEN LAYER output|
                ---------------------------------------
|               |   0x08        |   FC LAYER output    |
 ------------------------------------------------------

Coef cache(64bit)
 ---------------------------------------------------
|                     |   0x00~0x0F   |   weight    |
|   INPUT LAYER IH     -----------------------------
|                     |   0x10        |   bias      |
 ---------------------------------------------------
|                     |   0x11~0x18   |   weight    |
|   INPUT LAYER HH     -----------------------------
|                     |   0x19        |   bias      |
 ---------------------------------------------------
|                     |   0x1A~0x21   |   weight    |
|   HIDDEN LAYER IH    -----------------------------
|                     |   0x22        |   bias      |
 ---------------------------------------------------
|                     |   0x23~0x2A   |   weight    |
|   HIDDEN LAYER HH    -----------------------------
|                     |   0x2B        |   bias      |
 ---------------------------------------------------
|                     |   0x2C~0x2E   |   weight    |
|   FC LAYER           -----------------------------
|                     |   0x2F        |   bias      |
 ---------------------------------------------------

*/

always@(*) begin
    subl_num = 1'd1;    // 子层数 = subl_num +1, 例如INPUT_LAYER & HIDDEN_LAYER 子层=2，FC 子层=1
    jump_sub1_mul = 1'b1;   // 是否要跳过子层计算, 例如first_rnn跳过L1的矩阵乘
    need_relu = 1'b1;   // FC layer无需做ReLU
    subl0_coef_base_addr = `COEF_ILAYER_IH_BASE_ADDR;   // coef memory中 INPUT LAYER的子层L0的参数基地址  // 6'h00
    subl1_coef_base_addr = `COEF_ILAYER_HH_BASE_ADDR;   // coef memory中 INPUT LAYER的子层L1的参数基地址  // 6'h11
    subl0_data_base_addr = `DATA_NORM_IH_BASE_ADDR;     // cache memory中NORM后的数据基地址-->INPUT LAYER用的的数据基地址  // 5'h04
    subl1_data_base_addr = `DATA_ILAYER_HH_BASE_ADDR;   // cache memory中INPUT LAYERR output --> HIDDEN LAYER的数据基地址  // 5'h06
    subl0_weight_addr_num = 4'd15;  // 子层L0的weight byte数 = addr_num+1
    subl1_weight_addr_num = 4'd7;   // 子层L1的weight byte数
    subl0_data_addr_num_log2 = 1'd1;
    subl1_data_addr_num_log2 = 1'd0;
    subl0_data_ratio = rg_nn_ilayer_ih_data_ratio;  // INPUT LAYER 的子层L0数据缩放参数
    subl1_data_ratio = rg_nn_ilayer_hh_data_ratio;  // INPUT LAYER 的子层L1数据缩放参数
    if(nn_state_s == INPUT_LAYER) begin
        subl_num = 1'd1;    // L0-L1
        jump_sub1_mul = first_rnn;   // first_rnn跳过L1的矩阵乘
        need_relu = 1'b1;
        subl0_coef_base_addr = `COEF_ILAYER_IH_BASE_ADDR;   // coef memory中 INPUT LAYER的子层L0的参数基地址  // 6'h00
        subl1_coef_base_addr = `COEF_ILAYER_HH_BASE_ADDR;   // coef memory中 INPUT LAYER的子层L1的参数基地址  // 6'h11
        subl0_data_base_addr = `DATA_NORM_IH_BASE_ADDR;     // cache memory中NORM后的数据基地址-->INPUT LAYER用的的数据基地址  // 5'h04
        subl1_data_base_addr = `DATA_ILAYER_HH_BASE_ADDR;   // cache memory中INPUT LAYERR output --> HIDDEN LAYER的数据基地址  // 5'h06
        subl0_weight_addr_num = 4'd15;  // 子层L0的weight byte数
        subl1_weight_addr_num = 4'd7;   // 子层L1的weight byte数
        subl0_data_addr_num_log2 = 1'd1;
        subl1_data_addr_num_log2 = 1'd0;
        subl0_data_ratio = rg_nn_ilayer_ih_data_ratio;  // INPUT LAYER 的子层L0数据缩放参数
        subl1_data_ratio = rg_nn_ilayer_hh_data_ratio;  // INPUT LAYER 的子层L1数据缩放参数
    end
    else if(nn_state_s == HIDDEN_LAYER) begin
        subl_num = 1'd1;    // L0-L1
        jump_sub1_mul = first_rnn;   // first_rnn跳过L1的矩阵乘
        need_relu = 1'b1;
        subl0_coef_base_addr = `COEF_HLAYER_IH_BASE_ADDR;   // coef memory中 HIDDEN LAYER的子层L0的参数基地址  // 6'h1A
        subl1_coef_base_addr = `COEF_HLAYER_HH_BASE_ADDR;   // coef memory中 HIDDEN LAYER的子层L1的参数基地址  // 6'h23
        subl0_data_base_addr = `DATA_ILAYER_BASE_ADDR;     // cache memory中 INPUT LAYER output -->HIDDEN LAYER L0用的的数据基地址  // 5'h06
        subl1_data_base_addr = `DATA_HLAYER_BASE_ADDR;   // cache memory中 HIDDEN LAYER L0 output --> HIDDEN LAYER L1的数据基地址  // 5'h07
        subl0_weight_addr_num = 4'd7;  // 子层L0的weight byte数
        subl1_weight_addr_num = 4'd7;   // 子层L1的weight byte数
        subl0_data_addr_num_log2 = 1'd0;
        subl1_data_addr_num_log2 = 1'd0;
        subl0_data_ratio = rg_nn_hlayer_ih_data_ratio;  // HIDDEN LAYER 的子层L0数据缩放参数
        subl1_data_ratio = rg_nn_hlayer_hh_data_ratio;  // HIDDEN LAYER 的子层L1数据缩放参数
    end
    else if(nn_state_s == FC_LAYER) begin
        subl_num = 1'd0;    // L0
        jump_sub1_mul = 1'd1;   // FC只有L0一层，必定会跳过L1的矩阵乘
        need_relu = 1'b0;
        subl0_coef_base_addr = `COEF_FLAYER_BASE_ADDR;   // coef memory中 FC LAYER的子层L0的参数基地址  // 6'h2C
        subl1_coef_base_addr = `COEF_FLAYER_BASE_ADDR;   // not used
        subl0_data_base_addr = `DATA_HLAYER_BASE_ADDR;   // cache memory中 HIDDEN LAYER output -->FC LAYER 用的的数据基地址  // 5'h07
        subl1_data_base_addr = `DATA_FLAYER_BASE_ADDR;   // cache memory中 FC LAYER  output -->   // 5'h08
        subl0_weight_addr_num = 4'd2;  // 子层L0的weight byte数
        subl1_weight_addr_num = 4'd2;   // 子层L1的weight byte数
        subl0_data_addr_num_log2 = 1'd0;
        subl1_data_addr_num_log2 = 1'd0;
        subl0_data_ratio = rg_nn_flayer_data_ratio;  // FC LAYER 的子层数据缩放参数
        subl1_data_ratio = rg_nn_flayer_data_ratio;  // 
    end
end

// NN计算模块 //
NN_layer_ctrl NN_layer_ctrl_inst(
    .clk                      ( clk                       ),
    .rstn                     ( rstn                      ),
    .NN_layer_start           ( NN_layer_start            ),
    .NN_layer_done            ( NN_layer_done             ),
    .subl_num                 ( subl_num                  ),
    .jump_sub1_mul            ( jump_sub1_mul             ),
    .need_relu                ( need_relu                 ),
    .subl0_coef_base_addr     ( subl0_coef_base_addr      ),
    .subl1_coef_base_addr     ( subl1_coef_base_addr      ),
    .subl0_data_base_addr     ( subl0_data_base_addr      ),
    .subl1_data_base_addr     ( subl1_data_base_addr      ),
    .subl0_weight_addr_num    ( subl0_weight_addr_num     ),
    .subl1_weight_addr_num    ( subl1_weight_addr_num     ),
    .subl0_data_addr_num_log2 ( subl0_data_addr_num_log2  ),
    .subl1_data_addr_num_log2 ( subl1_data_addr_num_log2  ),
    .subl0_data_ratio         ( subl0_data_ratio          ),
    .subl1_data_ratio         ( subl1_data_ratio          ),
    .coef_ena                 ( coef_ena                  ),
    .coef_addr                ( coef_addr                 ),
    .coef_rdata               ( coef_rdata                ),
    .cache_ena                ( cache_ena                 ),
    .cache_wena               ( cache_wena                ),
    .cache_addr               ( cache_addr                ),
    .cache_wdata              ( cache_wdata               ),
    .cache_rdata              ( cache_rdata               ),
    .NN_layer_out             ( NN_layer_out              ),
    .NN_layer_out_vld         ( NN_layer_out_vld          )
);

// FC LAYER计算得到三个NN判定权重结果，找最大值，送到label_dec module解码 //
assign fc_layer_out_vld = (nn_state_s == FC_LAYER) && NN_layer_out_vld;
assign fc_layer_out = fc_layer_out_vld?  NN_layer_out[2:0] : 24'h0;

assign fc_max_index  = ($signed(fc_layer_out[0] >= $signed(fc_layer_out[1]) && $signed(fc_layer_out[0] >= $signed(fc_layer_out[2]))？ 2'd0 :
                       ($signed(fc_layer_out[1] >= $signed(fc_layer_out[0]) && $signed(fc_layer_out[1] >= $signed(fc_layer_out[2]))？ 2'd1 : 2'd2;
assign fc_max_index_vld = fc_layer_out_vld;

// 根据每次NN计算结果fc_max_index，根据决策方式和决策配置，得到当前判定结果dec_result //
label_dec label_dec_inst(
    .clk                   ( clk                    ),
    .rstn                  ( rstn                   ),
    .soft_clr              ( soft_clr               ),
    .rg_label_seq_init_en  ( rg_label_seq_init_en   ),
    .rg_label_dec_mode     ( rg_label_dec_mode      ),
    .rg_label_up_memcnt_th ( rg_label_up_memcnt_th  ),
    .rg_label_dn_memcnt_th ( rg_label_dn_memcnt_th  ),
    .rg_label_memseq_len   ( rg_label_memseq_len    ),
    .fc_max_index          ( fc_max_index           ),
    .fc_max_index_vld      ( fc_max_index_vld       ),
    .dec_result            ( dec_result             ),
    .dec_result_vld        ( dec_result_vld         ),
    .label_dec_done        ( label_dec_done         ),
    .ro_fdt_result_up      ( ro_fdt_result_up       ),
    .ro_fdt_result_down    ( ro_fdt_result_down     )
);


endmodule