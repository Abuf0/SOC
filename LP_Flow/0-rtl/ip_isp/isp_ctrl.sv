module  isp_ctrl# (
    parameter DW = 24   ,   // RGB Data Width as rgb888
    parameter BW = 16   ,   // Bayer Data Width
    parameter H  = 128  ,
    parameter V  = 72   ,
    parameter HW = 11   ,
    parameter VW = 10   
)(
    input        clk                            ,
    input        rstn                           , 
    // ISP global parameter //
    input [15:0] isp_enable                     ,
    //input [3:0]  isp_seq [0:15]                 ,   // ISP顺序，寄存器配置
    input [1:0]  bayer_pattern                  ,
    // DPC module parameter //
    input [BW-1:0] dpc_thres                    ,
    input [BW-1:0] dpc_clip                     ,
    /*
    // BLC module parameter //
    input [BW-1:0] blc_bias [0:3]               ,
    input [BW-1:0] blc_clip                     ,
    // AWB module parameter //
    input [BW-1:0] awb_gain [0:3]               ,
    input [BW-1:0] awb_clip                     ,
    // CNF module parameter //
    input [BW-1:0] cnf_gain [0:3]               ,
    input [BW-1:0] cnf_clip                     ,
    input [BW-1:0] cnf_thres                    ,
    // CFA module parameter //
    input [BW-1:0] cfa_clip                     ,
    // CCM module parameter //
    input [DW-1:0] ccm_coef_r [0:3]             ,
    input [DW-1:0] ccm_coef_g [0:3]             ,
    input [DW-1:0] ccm_coef_b [0:3]             ,
    // CSC module parameter //
    input signed [DW-1:0] csc_coef_r [0:3]      ,
    input signed [DW-1:0] csc_coef_g [0:3]      ,
    input signed [DW-1:0] csc_coef_b [0:3]      ,
    // NLM module parameter //
    input [DW-1:0] nlm_clip                     ,
    // BNF module parameter //
    input [DW-1:0] bnf_dw [0:4][0:4]            ,   
    input [DW-1:0] bnf_rw [0:3]                 ,     
    input [DW-1:0] bnf_rthres [0:2]             ,   
    input [DW-1:0] bnf_clip                     ,     
    // EEH module parameter //
    input signed [4:0] edge_filter [0:2][0:4]   ,
    input [DW-1:0] eeh_rthres [0:1]             ,      
    input [DW-1:0] eeh_gain [0:1]               , 
    input signed [DW:0] eeh_emclip [0:1]        ,      
    // BCC module parameter //
    input [DW-1:0] bcc_brightness               ,
    input [DW-1:0] bcc_contrast                 ,
    input [DW-1:0] bcc_clip                     ,
    // FCS module parameter //
    input [DW/3-1:0] fcs_edge [0:1]             ,
    input [DW/3-1:0] fcs_gain                   ,
    input [DW/3-1:0] fcs_intercept              ,
    input [DW/3-1:0] fcs_slop                   ,
    input [DW/3-1:0] fcs_clip                   ,
    // HSC module parameter //
    input signed [DW/3:0] hue_cos               ,
    input signed [DW/3:0] hue_sin               ,
    input [DW/3-1:0] hsc_saturation             ,
    input [DW/3-1:0] hsc_clip                   ,
    */
    // ISP input //
    input [DW-1:0] pixel_data_in                ,
    input          pixel_data_in_vld            ,
    // ISP output //
    output logic [DW-1:0] pixel_data_out        ,
    output logic pixel_data_out_vld             ,
    output logic isp_one_frame_done                     // isp_done
);

localparam CSC_FIFO_DEEPTH = 16 * H ;
localparam BCC_FIFO_DEEPTH = 4 * H ;
// Fixed index
parameter DPC = 4'd0   ;
parameter BLC = 4'd1   ;
parameter AAF = 4'd2   ;
parameter AWB = 4'd3   ;
parameter CNF = 4'd4   ;
parameter CFA = 4'd5   ;
parameter CCM = 4'd6   ;
parameter GAC = 4'd7   ;
parameter CSC = 4'd8   ;
parameter NLM = 4'd9   ;
parameter BNF = 4'd10  ;
parameter EEH = 4'd11  ;
parameter FCS = 4'd12  ;
parameter HSC = 4'd13  ;
parameter BCC = 4'd15  ;

logic  [BW-1:0]  pixel_data_bayer[0:16];
logic  [DW-1:0]  pixel_data_rgb[0:16];
logic            pixel_data_vld[0:16];
logic            one_frame_done[0:16];

logic  [23:0]    buffer_data_rgb_csc;

logic [DW/3-1:0] yuv_out [0:2]    ;
logic yuv_out_vld               ;

// DPC module
dpc #(
    .DPC_MODE   (0   ), 
    .DW         (BW   ),
    .H          (H    ),
    .V          (V    ),
    .HW         (HW   ),
    .VW         (VW   )
) dpc_inst(
    .clk                (clk               ),
    .rstn               (rstn               ),
    .dpc_en             (isp_enable[DPC]         ), // TODO
    .thres              (dpc_thres               ),
    .clip               (dpc_clip                ),
    .pixel_data_in_vld  (pixel_data_vld[DPC]     ), // TODO
    .pixel_data_in      (pixel_data_bayer[DPC]   ),
    .pixel_data_out_vld (pixel_data_vld[DPC+1]   ),
    .pixel_data_out     (pixel_data_bayer[DPC+1] ),
    .one_frame_done     (one_frame_done[DPC]     )
);
assign pixel_data_rgb[DPC] = pixel_data_in;
assign pixel_data_bayer[DPC] = pixel_data_rgb[DPC][BW-1:0];
assign pixel_data_vld[DPC] = pixel_data_in_vld;

assign pixel_data_out = pixel_data_bayer[DPC+1];
assign pixel_data_out_vld = pixel_data_vld[DPC+1];
assign isp_one_frame_done = one_frame_done[DPC];

endmodule