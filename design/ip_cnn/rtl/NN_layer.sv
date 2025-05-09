module NN_layer#(
    parameter IN_W      = 224   ,
    parameter IN_L      = 224   ,
    parameter ICHN_L    = 3     ,
    parameter OCHN_L    = 64    ,
    parameter KSIZE     = 3     ,
    parameter STD_L     = 1     ,
    parameter PAD_L     = 1     ,   
    parameter BAT_L     = 64    ,
    parameter ICHN_H    = 64    ,
    parameter OCHN_H    = 64    ,
    parameter STD_H     = 1     ,
    parameter PAD_H     = 1     ,
    parameter BAT_H     = 64    ,
    parameter MAX_PK    = 2     ,
    parameter MAX_PS    = 2
)(
    input               clk                ,
    input               rstn               ,
    input               NN_layer_start     ,
    input               need_bn            ,
    input               need_relu          ,
    /* coef interface */
    input [64:0]        coef_rdata         ,
    output logic        coef_ena           ,
    output logic [15:0] coef_addr          ,
    /* data interface */
    input [63:0]        cache_rdata        ,
    output logic        cache_ena          ,
    output logic        cache_wena         ,
    output logic [15:0] cache_addr         ,
    output logic [15:0] cache_waddr        ,
    output logic        NN_layer_done  
);

logic conv_done;
logic bn_done;
logic relu_done;
logic max_pool_done;

typedef enum logic [2:0] {IDLE, CONV_L, BN_L, RELU_L, CONV_H, BN_H, RELU_H, MAX_POOL} nn_state_t;
nn_state_t nn_state_c, nn_state_n;
always@(posedge clk or negedge rstn) begin
    if(~rstn)
        nn_state_c <= IDLE;
    else 
        nn_state_c <= nn_state_n;
end

always@(*) begin
    nn_state_n = IDLE;
    case(nn_state_c)
        IDLE:
            nn_state_n = NN_layer_start?    CONV_L : IDLE;
        CONV_L:
            nn_state_n = conv_done?     (need_bn?    BN_L : (need_relu?  RELU_L : CONV_H)) : CONV_L;
        BN_L:
            nn_state_n = bn_done?   (need_relu?  RELU_L : BN_L);
        RELU_L:
            nn_state_n = relu_done?     CONV_H : RELU_L;
        CONV_H:
            nn_state_n = conv_done?     (need_bn?    BN_H : (need_relu?  RELU_H : MAX_POOL)) : CONV_H;
        BN_H:
            nn_state_n = bn_done?   (need_relu?  RELU_H : BN_H);
        RELU_H:
            nn_state_n = relu_done?     MAX_POOL : RELU_H;  
        MAX_POOL:
            nn_state_n = max_pool_done?     IDLE : MAX_POOL;      
        default:
            nn_state_n = IDLE;
    endcase
end

logic [9:0] in_width;

conv_cal conv_cal_inst #(
    .KSIZE  (KSIZE  )   ,
    .IN_WMAX(IN_WMAX)    // include padding
)(
    .clk            (clk            ),
    .rstn           (rstn           ),
    .in_width       (in_width       ),  // todo, include padding
    .weight         (weight         ),
    .data           (data           ),
    .data_in_vld    (data_in_vld    ),
    .mac_shift_en   (mac_shift_en   ),
    .mac_sum_out    (mac_sum_out    ),
    .mac_sum_out_vld(mac_sum_out_vld)          
);


endmodule