module nn_top #(
    parameter ROW_NUM    = 32    ,
    parameter COL_NUM    = 32    ,
    parameter MAX_SP_LEN = 40    ,
    parameter IN_WD      = 32*8  ,
    parameter WGT_WD     = 32*8  ,
    parameter MAX_WD     = 32    ,
    parameter OUT_WD     = 12    ,
    parameter DADDR_WD   = 32    ,
    parameter WADDR_WD   = 32    ,
    parameter DDATA_WD   = IN_WD ,
    parameter WDATA_WD   = WGT_WD  
)(
    input                       clk                 ,
    input                       rstn                ,  
    /* DATA Interface todo need 2 data bank, replaced by BUS */
    input [DADDR_WD-1:0]        rg_src_data_base    ,   // bank for read
    input [DADDR_WD-1:0]        rg_dest_data_base   ,   // bank for write
    input [DADDR_WD-1:0]        rg_coef_base        ,
    input [DADDR_WD-1:0]        rg_param_base       ,
    /* SRC MEMORY */
    output logic                src_mem_rd             ,
    output logic                src_mem_wr             ,
    output logic [DADDR_WD-1:0] src_mem_addr           ,
    input [DDATA_WD-1:0]        src_mem_rdata          ,
    output logic [DDATA_WD-1:0] src_mem_wdata          ,
    output logic [DDATA_WD/8-1:0] src_mem_wmask        ,
    /* DEST MEMORY */
    output logic                dest_mem_rd            ,
    output logic                dest_mem_wr            ,
    output logic [DADDR_WD-1:0] dest_mem_addr          ,
    input [DDATA_WD-1:0]        dest_mem_rdata         ,
    output logic [DDATA_WD-1:0] dest_mem_wdata         ,
    output logic [DDATA_WD/8-1:0] dest_mem_wmask       ,

    /* WGT Interface todo replaced by BUS */
    /* WGT MEMORY */
    output logic                wgt_mem_rd             ,
    output logic                wgt_mem_wr             ,
    output logic [DADDR_WD-1:0] wgt_mem_addr           ,
    input [DDATA_WD-1:0]        wgt_mem_rdata          ,
    output logic [DDATA_WD-1:0] wgt_mem_wdata          ,
    output logic [DDATA_WD/8-1:0] wgt_mem_wmask        ,
    /* PARAM MEMORY */
    output logic                param_mem_rd           ,
    output logic [DADDR_WD-1:0] param_mem_addr         ,
    input [DDATA_WD-1:0]        param_mem_rdata        ,
    /* config todo width */
    input [9:0]                 rg_batch_num        ,
    input [9:0]                 rg_in_w             ,   // input
    input [9:0]                 rg_in_h             ,   // input
    input [9:0]                 rg_in_c             ,   // input
    input [9:0]                 rg_kernel_w         ,   // kernel
    input [9:0]                 rg_kernel_h         ,   // kernel
    input [9:0]                 rg_kernel_c         ,   // kernel
    input [9:0]                 rg_out_w            ,   // output
    input [9:0]                 rg_out_h            ,   // output
    input [9:0]                 rg_out_c            ,   // output
    input [3:0]                 rg_pad_x            ,   // pad
    input [3:0]                 rg_pad_y            ,   // pad
    input [1:0]                 rg_pad_mode         ,   // pad
    input [DDATA_WD-1:0]        rg_pad_x_value      ,   // pad
    input [DDATA_WD-1:0]        rg_pad_y_value      ,   // pad
    input [9:0]                 rg_stride_w         ,   // stride
    input [9:0]                 rg_stride_h         ,   // stride
    input [9:0]                 rg_dilat_w          ,   // dilation
    input [9:0]                 rg_dilat_h          ,   // dilation
    input [DDATA_WD-1:0]        rg_inzp             ,   // zeropoint
    input [DDATA_WD-1:0]        rg_outzp            ,   // zeropoint
    input [3:0]                 rg_data_type        ,   // type
    input [3:0]                 rg_wgt_type         ,   // type
    input [9:0]                 rg_strip_len        ,   // stripe
    /* Interface with top top */
    input                       conv_init           ,
    input                       conv_start          ,
    output logic                conv_done     
);

logic [DDATA_WD-1:0] data_to_mac         ;
logic                data_to_mac_vld     ;
logic [DDATA_WD-1:0] data_to_mac_mask    ;
logic [3:0]          data_type           ;
logic [DDATA_WD-1:0] wgt_to_mac          ;
logic                wgt_to_mac_vld      ;
logic                wgt_to_mac_flag     ;
logic [DDATA_WD-1:0] wgt_to_mac_mask     ;
logic [3:0]          wgt_type            ;
logic [ROW_NUM-1:0]  mac_array_row_mask  ;
logic                pingpong_flag       ;
logic [5:0]          mac_strip_len       ;
logic [6:0]          mac_kernel_size     ;
logic [6:0]          mac_chn_slice_num   ;
logic [OUT_WD-1:0]   data_from_mac [0:COL_NUM-1]      ; 
logic                data_from_mac_vld   ;

mac_control #(
    .ROW_NUM   (ROW_NUM   ),
    .COL_NUM   (COL_NUM   ),
    .MAX_SP_LEN(MAX_SP_LEN),
    .IN_WD     (IN_WD     ),
    .WGT_WD    (WGT_WD    ),
    .MAX_WD    (MAX_WD    ),
    .OUT_WD    (OUT_WD    ),
    .DADDR_WD  (DADDR_WD  ),
    .WADDR_WD  (WADDR_WD  ),
    .DDATA_WD  (DDATA_WD  ),
    .WDATA_WD  (WDATA_WD  )       
) mac_control_inst(
    .clk                (clk               ) ,
    .rstn               (rstn              ) ,  
    .rg_src_data_base   (rg_src_data_base  ) ,
    .rg_dest_data_base  (rg_dest_data_base ) ,
    .rg_coef_base       (rg_coef_base      ) ,
    .rg_param_base      (rg_param_base     ) ,
    .src_mem_rd         (src_mem_rd        ) ,
    .src_mem_wr         (src_mem_wr        ) ,
    .src_mem_addr       (src_mem_addr      ) ,
    .src_mem_rdata      (src_mem_rdata     ) ,
    .src_mem_wdata      (src_mem_wdata     ) ,
    .src_mem_wmask      (src_mem_wmask     ) ,  
    .dest_mem_rd        (dest_mem_rd       ) ,
    .dest_mem_wr        (dest_mem_wr       ) ,
    .dest_mem_addr      (dest_mem_addr     ) ,
    .dest_mem_rdata     (dest_mem_rdata    ) ,
    .dest_mem_wdata     (dest_mem_wdata    ) ,
    .dest_mem_wmask     (dest_mem_wmask    ) ,
    .wgt_mem_rd         (wgt_mem_rd        ) ,
    .wgt_mem_wr         (wgt_mem_wr        ) ,
    .wgt_mem_addr       (wgt_mem_addr      ) ,
    .wgt_mem_rdata      (wgt_mem_rdata     ) ,
    .wgt_mem_wdata      (wgt_mem_wdata     ) ,
    .wgt_mem_wmask      (wgt_mem_wmask     ) ,
    .param_mem_rd       (param_mem_rd      ) ,
    .param_mem_addr     (param_mem_addr    ) ,
    .param_mem_rdata    (param_mem_rdata   ) ,
    .rg_batch_num       (rg_batch_num      ) ,
    .rg_in_w            (rg_in_w           ) ,   // input
    .rg_in_h            (rg_in_h           ) ,   // input
    .rg_in_c            (rg_in_c           ) ,   // input
    .rg_kernel_w        (rg_kernel_w       ) ,   // kernel
    .rg_kernel_h        (rg_kernel_h       ) ,   // kernel
    .rg_kernel_c        (rg_kernel_c       ) ,   // kernel
    .rg_out_w           (rg_out_w          ) ,   // output
    .rg_out_h           (rg_out_h          ) ,   // output
    .rg_out_c           (rg_out_c          ) ,   // output
    .rg_pad_x           (rg_pad_x          ) ,   // pad
    .rg_pad_y           (rg_pad_y          ) ,   // pad
    .rg_pad_mode        (rg_pad_mode       ) ,   // pad
    .rg_pad_x_value     (rg_pad_x_value    ) ,   // pad
    .rg_pad_y_value     (rg_pad_y_value    ) ,   // pad
    .rg_stride_w        (rg_stride_w       ) ,   // stride
    .rg_stride_h        (rg_stride_h       ) ,   // stride
    .rg_dilat_w         (rg_dilat_w        ) ,   // dilation
    .rg_dilat_h         (rg_dilat_h        ) ,   // dilation
    .rg_inzp            (rg_inzp           ) ,   // zeropoint
    .rg_outzp           (rg_outzp          ) ,   // zeropoint
    .rg_data_type       (rg_data_type      ) ,   // type
    .rg_wgt_type        (rg_wgt_type       ) ,   // type
    .rg_strip_len       (rg_strip_len      ) ,   // stripe
    .data_to_mac        (data_to_mac       ) ,
    .data_to_mac_vld    (data_to_mac_vld   ) ,
    .data_to_mac_mask   (data_to_mac_mask  ) ,
    .data_type          (data_type         ) ,
    .wgt_to_mac         (wgt_to_mac        ) ,
    .wgt_to_mac_vld     (wgt_to_mac_vld    ) ,
    .wgt_to_mac_flag    (wgt_to_mac_flag   ) ,   // updata
    .wgt_to_mac_mask    (wgt_to_mac_mask   ) ,
    .wgt_type           (wgt_type          ) ,
    .mac_array_row_mask (mac_array_row_mask) ,
    .pingpong_flag      (pingpong_flag     ) ,
    .mac_strip_len      (mac_strip_len     ) ,
    .mac_kernel_size    (mac_kernel_size   ) ,
    .mac_chn_slice_num  (mac_chn_slice_num ) ,
    .data_from_mac      (data_from_mac     ) ,
    .data_from_mac_vld  (data_from_mac_vld ) ,
    .mac_init           (conv_init         ) ,
    .mac_start          (conv_start        ) ,
    .mac_done           (conv_done         )     
);

mac_array #(
    .ROW_NUM    (ROW_NUM   ) ,
    .COL_NUM    (COL_NUM   ) ,
    .MAX_SP_LEN (MAX_SP_LEN) ,
    .IN_WD      (IN_WD     ) ,
    .WGT_WD     (WGT_WD    ) ,
    .MAX_WD     (MAX_WD    ) ,
    .OUT_WD     (OUT_WD    )     
) mac_array_inst (
    .clk             (clk                   ) ,
    .rstn            (rstn                  ) ,
    .data_in         (data_to_mac           ) ,
    .data_in_vld     (data_to_mac_vld       ) ,
    .data_in_mask    (data_to_mac_mask      ) ,
    .data_type       (data_type             ) ,   
    .wgt_in          (wgt_to_mac            ) ,
    .wgt_in_vld      (wgt_to_mac_vld        ) ,
    .wgt_in_flag     (wgt_to_mac_flag       ) ,   
    .wgt_in_mask     (wgt_to_mac_mask       ) ,
    .wgt_type        (wgt_type              ) ,
    .row_mask        (mac_array_row_mask    ) , 
    .pingpong_flag   (pingpong_flag         ) ,   
    .strip_len       (mac_strip_len         ) ,   
    .kernel_size     (mac_kernel_size       ) ,   
    .chn_slice_num   (mac_chn_slice_num     ) ,   
    .data_out        (data_from_mac         ) ,   
    .data_out_vld    (data_from_mac_vld     )
);

endmodule