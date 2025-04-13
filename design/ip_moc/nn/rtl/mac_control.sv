module mac_control #(
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
    output logic                data_rd             ,
    output logic                data_wr             ,
    output logic [DADDR_WD-1:0] data_raddr          ,
    output logic [DADDR_WD-1:0] data_waddr          ,
    output logic [DDATA_WD-1:0] data_wdata          ,
    input [DDATA_WD-1:0]        data_rdata          ,
    input                       data_wvalid         ,
    input                       data_rvalid         ,
    input [DADDR_WD-1:0]        rg_src_data_base    ,   // bank for read
    input [DADDR_WD-1:0]        rg_dest_data_base   ,   // bank for write
    /* WGT Interface todo replaced by BUS */
    output logic                wgt_rd              ,
    output logic                wgt_wr              ,
    output logic [DADDR_WD-1:0] wgt_raddr           ,
    output logic [DADDR_WD-1:0] wgt_waddr           ,
    output logic [DDATA_WD-1:0] wgt_wdata           ,
    input [DDATA_WD-1:0]        wgt_rdata           ,
    input                       wgt_wvalid          ,
    input                       wgt_rvalid          ,
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
    /* Interface with mac_array */
    output logic [DDATA_WD-1:0] data_to_mac         ,
    output logic                data_to_mac_vld     ,
    output logic [DDATA_WD-1:0] data_to_mac_mask    ,
    output logic [3:0]          data_type           ,
    output logic [DDATA_WD-1:0] wgt_to_mac          ,
    output logic                wgt_to_mac_vld      ,
    output logic                wgt_to_mac_flag     ,   // updata
    output logic [DDATA_WD-1:0] wgt_to_mac_mask     ,
    output logic [3:0]          wgt_type            ,
    output logic [ROW_NUM-1:0]  mac_array_row_mask  ,
    output logic                pingpong_flag       ,
    output logic [5:0]          mac_strip_len       ,
    output logic [6:0]          mac_kernel_size     ,
    output logic [6:0]          mac_chn_slice_num   ,
    input [OUT_WD-1:0]          data_from_mac [0:COL_NUM-1]    ,
    input                       data_from_mac_vld   ,
    /* Interface with top */
    input                       mac_init            ,
    input                       mac_start           ,
    output logic                mac_done     
);

parameter ROW_BW = $clog2(ROW_NUM);
parameter COL_BW = $clog2(COL_NUM);

logic init_done;
logic [6:0] khn_slice_num;
logic [6:0] khn_slice_cnt;
logic [10:0] in_w_pad;
logic [10:0] in_h_pad;
logic [10:0] in_wcnt;
logic [10:0] in_hcnt;

logic [9:0]  stride_w ;
logic [9:0]  stride_h ;

logic one_khn_slice_end;
logic all_khn_end;

logic state_mac;

logic [9:0] mac_kernel_h;
logic [9:0] mac_kernel_w;
logic [6:0] mac_chn_slice_num;
// FSM //
typedef enum logic[1:0] {IDLE, INIT, MAC } state_t;
state_t state_c,state_n;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        state_c <= IDLE;
    else 
        state_c <= state_n;
end
always @(*) begin
    state_n = IDLE;
    case(state_c)
        IDLE:   state_n = mac_init?  INIT : IDLE;
        INIT:   state_n = (init_done && mac_start)?  MAC : INIT;
        MAC:    state_n = mac_done?  IDLE : MAC;
    endcase
end

assign state_mac = (state_c == MAC);
// K/COL_NUM //
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        in_wcnt <= 'd0;
    else if(init_done)
        in_wcnt <= 'd0;
    else if(data_from_mac_vld)
        in_wcnt <= (in_wcnt + stride_w >= in_w_pad)?  'd0 : in_wcnt + stride_w;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        in_hcnt <= 'd0;
    else if(init_done)
        in_hcnt <= 'd0;
    else if(data_from_mac_vld && (in_wcnt + stride_w >= in_w_pad))
        in_hcnt <= (in_hcnt + stride_h >= in_h_pad)?  'd0 : in_hcnt + stride_h;
end

assign one_khn_slice_end = (in_wcnt + stride_w >= in_w_pad) && (in_hcnt + stride_h >= in_h_pad) && data_from_mac_vld;

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        khn_slice_cnt <= 'd0;
    else if(init_done)
        khn_slice_cnt <= 'd0;
    else if(one_khn_slice_end)
        khn_slice_cnt <= (khn_slice_cnt == khn_slice_num-1)?  'd0 : khn_slice_cnt + 1'b1;
end

assign all_khn_end = (khn_slice_cnt == khn_slice_num-1) && one_khn_slice_end;

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mac_done <= 1'b0;
    else if(all_khn_end)
        mac_done <= 1'b1;
    else 
        mac_done <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        init_done <= 1'b0;
    else if(mac_init)
        init_done <= 1'b1;
    else 
        init_done <= 1'b0;
end
// CONTROL to MAC_ARRAY //
logic [6:0] fetch_kslice_num;
logic [9:0] fetch_h_num;    // with pad
logic [9:0] fetch_w_num;    // with pad
logic [6:0] fetch_cslice_num;
logic [6:0] fetch_rxs_num;
logic [6:0] fetch_kcol_num;
logic [6:0] fetch_kslice_cnt;
logic [9:0] fetch_h_cnt;
logic [9:0] fetch_w_cnt;
logic [6:0] fetch_cslice_cnt;
logic [6:0] fetch_rxs_cnt;
logic [6:0] fetch_kcol_cnt;
logic fetch_kslice_end;
logic fetch_frame_end;
logic fetch_h_end;
logic fetch_w_end;
logic fetch_cslice_end;
logic fetch_rxs_end;
logic fetch_kcol_end;

assign fetch_kcol_num = (mac_strip_len > COL_NUM)?    mac_strip_len : COL_NUM;
assign fetch_rxs_num = mac_kernel_w * mac_kernel_h;
assign fetch_cslice_num = mac_chn_slice_num;
assign fetch_kslice_num = mac_khn_slice_num;

assign fetch_kcol_end = (fetch_kcol_cnt ==  fetch_kcol_num-1) && (data_in_vld || wgt_in_vld);
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        fetch_kcol_cnt <= 'd0;
    else if(mac_init)
        fetch_kcol_cnt <= 'd0;
    else if(state_mac && (data_in_vld || wgt_in_vld))   // todo
        fetch_kcol_cnt <= fetch_kcol_end?   'd0 : fetch_kcol_cnt+1;
end

assign fetch_rxs_end = (fetch_rxs_cnt == fetch_rxs_num-1) && (data_in_vld || wgt_in_vld);   // todo
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        fetch_rxs_cnt <= 'd0;
    else if(mac_init)
        fetch_rxs_cnt <= 'd0;
    else if(state_mac && fetch_kcol_end) 
        fetch_rxs_cnt <= fetch_rxs_end?   'd0 : fetch_rxs_cnt+1;
end

assign fetch_cslice_end = (fetch_cslice_cnt == fetch_cslice_num-1) && (data_in_vld || wgt_in_vld);   // todo
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        fetch_cslice_cnt <= 'd0;
    else if(mac_init)
        fetch_cslice_cnt <= 'd0;
    else if(state_mac && fetch_rxs_end)
        fetch_cslice_cnt <= fetch_cslice_end?   'd0 : fetch_cslice_cnt+1;
end

assign fetch_w_end = (fetch_w_cnt+stride_w >= fetch_w_num) && (data_in_vld || wgt_in_vld);   // todo
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        fetch_w_cnt <= 'd0;
    else if(mac_init)
        fetch_w_cnt <= 'd0;
    else if(state_mac && fetch_cslice_end)
        fetch_w_cnt <= fetch_w_end?   'd0 : fetch_w_cnt+stride_w;
end

assign fetch_h_end = (fetch_h_cnt+stride_h >= fetch_h_num) && (data_in_vld || wgt_in_vld);   // todo
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        fetch_h_cnt <= 'd0;
    else if(mac_init)
        fetch_h_cnt <= 'd0;
    else if(state_mac && fetch_w_end)
        fetch_h_cnt <= fetch_h_end?   'd0 : fetch_h_cnt+stride_h;
end

assign fetch_frame_end = (fetch_w_cnt+stride_w >= fetch_w_num) && (fetch_h_cnt+stride_h >= fetch_h_num) && (data_in_vld || wgt_in_vld);   // todo

assign fetch_kslice_end = (fetch_kslice_cnt == fetch_kslice_num-1) && (data_in_vld || wgt_in_vld);   // todo
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        fetch_kslice_cnt <= 'd0;
    else if(mac_init)
        fetch_kslice_cnt <= 'd0;
    else if(state_mac && fetch_frame_end)
        fetch_kslice_cnt <= fetch_kslice_end?   'd0 : fetch_kslice_cnt+1;
end

// INIT //
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_type <= 4'b0000;
    else if(mac_init)
        data_type <= rg_data_type;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        wgt_type <= 4'b0000;
    else if(mac_init)
        wgt_type <= rg_wgt_type;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mac_strip_len <= 'd1;
    else if(mac_init)
        mac_strip_len <= rg_strip_len;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mac_kernel_size <= 'd1;
    else if(mac_init)
        mac_kernel_size <= rg_kernel_h * rg_kernel_w;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mac_kernel_h <= 'd1;
    else if(mac_init)
        mac_kernel_h <= rg_kernel_h;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mac_kernel_w <= 'd1;
    else if(mac_init)
        mac_kernel_w <= rg_kernel_w;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mac_chn_slice_num <= 'd1;
    else if(mac_init)
        mac_chn_slice_num <= ~(|rg_in_c[ROW_BW-1:0])?  (rg_inc >> ROW_BW) : (rg_inc >> ROW_BW) + 1;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mac_khn_slice_num <= 'd1;
    else if(mac_init)
        mac_khn_slice_num <= ~(|rg_out_c[COL_BW-1:0])?  (rg_out_c >> COL_BW) : (rg_out_c >> COL_BW) + 1;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        in_w_pad <= 'd0;
    else if(mac_init)
        in_w_pad <= rg_in_w + (rg_pad_x << 1);
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        in_h_pad <= 'd0;
    else if(mac_init)
        in_h_pad <= rg_in_h + (rg_pad_y << 1);
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        stride_w <= 'd0;
    else if(mac_init)
        stride_w <= rg_stride_w
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        stride_h <= 'd0;
    else if(mac_init)
        stride_h <= rg_stride_h;
end
endmodule