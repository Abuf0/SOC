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
    input               rg_label_dec_mode           ,
    input [4:0]         rg_label_up_memcnt_th       ,
    input [4:0]         rg_label_dn_memcnt_th       ,
    input [3:0]         rg_label_memseq_len         ,
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

typedef enum logic [2:0] {IDLE, INPUT_LAYER, HIDDER_LAYER, FC_LAYER, LABEL_DEC, DONE} nn_state_t;
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
        INPUT_LAYER:    nn_state_n = input_layer_done?  HIDDER_LAYER : INPUT_LAYER;
        HIDDER_LAYER:   nn_state_n = hidden_layer_done?  FC_LAYER : HIDDER_LAYER;
        FC_LAYER:   nn_state_n = fc_layer_done?  LABEL_DEC : FC_LAYER;
        LABEL_DEC:  nn_state_n = label_dec_done?  DONE : LABEL_DEC;
        DONE:   nn_state_n = IDLE;
        default:    nn_state_n = IDLE;
end

assign idle_done = (nn_state_s == IDLE) && NN_unit_start;
assign input_layer_done = (nn_state_s == INPUT_LAYER) && NN_layer_done;
assign hidden_layer_done = (nn_state_s == HIDDER_LAYER) && NN_layer_done;
assign fc_layer_done = (nn_state_s == FC_LAYER) && NN_layer_done;
assign label_dec_done = dec_result_vld;

endmodule