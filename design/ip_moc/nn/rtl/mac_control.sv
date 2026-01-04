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
logic [9:0] kcol_cnt;
logic [3:0]                 in_pad_x      ;
logic [3:0]                 in_pad_y      ;
logic [1:0]                 in_pad_mode   ;
logic [DDATA_WD-1:0]        in_pad_x_value;
logic [DDATA_WD-1:0]        in_pad_y_value;

logic [9:0]  stride_w ;
logic [9:0]  stride_h ;

logic one_khn_slice_end;
logic all_khn_end;

logic state_mac;

logic [9:0] mac_kernel_h;
logic [9:0] mac_kernel_w;
logic [6:0] mac_khn_slice_num;

logic data_rvalid;
logic wgt_rvalid;

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

logic kcol_end;
assign kcol_end = data_from_mac_vld;
// FIX: one data_from_mac_vld generate COL_NUMxkcol output //

/*
assign kcol_end = (kcol_cnt == COL_NUM-1);
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        kcol_cnt <= 'd0;
    else if(init_done)
        kcol_cnt <= 'd0;
    else if(data_from_mac_vld)
        kcol_cnt <= kcol_end?  'd0 : kcol_cnt+COL_NUM;   // todo with COL_NUM for last loop
end
*/
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        in_wcnt <= 'd0;
    else if(init_done)
        in_wcnt <= 'd0;
    else if(data_from_mac_vld && kcol_end)
        in_wcnt <= (in_wcnt + stride_w >= in_w_pad)?  'd0 : in_wcnt + stride_w;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        in_hcnt <= 'd0;
    else if(init_done)
        in_hcnt <= 'd0;
    else if(data_from_mac_vld && (in_wcnt + stride_w >= in_w_pad) && kcol_end)
        in_hcnt <= (in_hcnt + stride_h >= in_h_pad)?  'd0 : in_hcnt + stride_h;
end

assign one_khn_slice_end = (in_wcnt + stride_w >= in_w_pad) && (in_hcnt + stride_h >= in_h_pad) && kcol_end && data_from_mac_vld;

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        khn_slice_cnt <= 'd0;
    else if(init_done)
        khn_slice_cnt <= 'd0;
    else if(one_khn_slice_end)
        khn_slice_cnt <= (khn_slice_cnt == mac_khn_slice_num-1)?  'd0 : khn_slice_cnt + 1'b1;
end

assign all_khn_end = (khn_slice_cnt == mac_khn_slice_num-1) && one_khn_slice_end;

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
    else if(mac_start)
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
logic [6:0] fetch_r_cnt;
logic [6:0] fetch_s_cnt;
logic [6:0] fetch_kcol_cnt;
logic fetch_kslice_end;
logic fetch_frame_end;
logic fetch_h_end;
logic fetch_w_end;
logic fetch_cslice_end;
logic fetch_rxs_end;
logic fetch_kcol_end;

logic fetch_vld;
logic fetch_first_col_loop;
logic fetch_last_col_loop;
logic fetch_padding_x;
logic fetch_padding_y;
logic fetch_padding;
logic fetch_wgt;

assign fetch_kcol_num = (mac_strip_len > COL_NUM)?    mac_strip_len : COL_NUM;
assign fetch_rxs_num = mac_kernel_w * mac_kernel_h;
assign fetch_cslice_num = mac_chn_slice_num;
assign fetch_h_num = in_h_pad;
assign fetch_w_num = in_w_pad;
assign fetch_kslice_num = mac_khn_slice_num;

assign fetch_first_col_loop = state_mac && (fetch_rxs_cnt == 0) && (fetch_cslice_cnt == 0) && (fetch_w_cnt == 0) && (fetch_h_cnt == 0) && (fetch_kslice_cnt == 0);
assign fetch_last_col_loop =  state_mac && (fetch_rxs_cnt == fetch_rxs_num-1) && (fetch_cslice_cnt == fetch_cslice_num-1) && (fetch_w_cnt+stride_w >= fetch_w_num) && (fetch_h_cnt+stride_h >= fetch_h_num) && (fetch_kslice_cnt == fetch_kslice_num-1);
//assign fetch_vld = (fetch_first_col_loop && wgt_to_mac_vld) || (fetch_last_col_loop && data_to_mac_vld) || (~fetch_first_col_loop && ~fetch_last_col_loop && wgt_to_mac_vld && data_to_mac_vld);
assign fetch_padding_x = state_mac && (fetch_w_cnt < in_pad_x || fetch_w_cnt >= in_w_pad-in_pad_x) ;
assign fetch_padding_y = state_mac && (fetch_h_cnt < in_pad_y || fetch_h_cnt >= in_h_pad-in_pad_y) ;
assign fetch_padding = fetch_padding_x || fetch_padding_y;
assign fetch_vld = state_mac;

assign fetch_wgt = state_mac && (fetch_kcol_cnt < COL_NUM);

assign fetch_kcol_end = (fetch_kcol_cnt ==  fetch_kcol_num-1) && fetch_vld;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        fetch_kcol_cnt <= 'd0;
    else if(mac_init || mac_done)
        fetch_kcol_cnt <= 'd0;
    else if(state_mac && fetch_vld && ~fetch_last_col_loop)   
        fetch_kcol_cnt <= fetch_kcol_end?   'd0 : fetch_kcol_cnt+1;
end

assign fetch_rxs_end = (fetch_rxs_cnt == fetch_rxs_num-1) && fetch_kcol_end;   
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        fetch_rxs_cnt <= 'd0;
    else if(mac_init || mac_done)
        fetch_rxs_cnt <= 'd0;
    else if(state_mac && fetch_kcol_end && ~fetch_last_col_loop) 
        fetch_rxs_cnt <= fetch_rxs_end?   'd0 : fetch_rxs_cnt+1;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        fetch_r_cnt <= 'd0;
    else if(mac_init || mac_done)
        fetch_r_cnt <= 'd0;
    else if(state_mac && fetch_kcol_end && ~fetch_last_col_loop) 
        fetch_r_cnt <= (fetch_r_cnt == rg_kernel_w-1)?   'd0 : fetch_r_cnt+1;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        fetch_s_cnt <= 'd0;
    else if(mac_init || mac_done)
        fetch_s_cnt <= 'd0;
    else if(state_mac && fetch_kcol_end && (fetch_r_cnt == rg_kernel_w-1) && ~fetch_last_col_loop) 
        fetch_s_cnt <= (fetch_s_cnt == rg_kernel_h-1)?   'd0 : fetch_s_cnt+1;
end

assign fetch_cslice_end = (fetch_cslice_cnt == fetch_cslice_num-1) && fetch_rxs_end;   
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        fetch_cslice_cnt <= 'd0;
    else if(mac_init || mac_done)
        fetch_cslice_cnt <= 'd0;
    else if(state_mac && fetch_rxs_end && ~fetch_last_col_loop)
        fetch_cslice_cnt <= fetch_cslice_end?   'd0 : fetch_cslice_cnt+1;
end

assign fetch_w_end = (fetch_w_cnt+stride_w >= fetch_w_num) && fetch_vld;   
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        fetch_w_cnt <= 'd0;
    else if(mac_init || mac_done)
        fetch_w_cnt <= 'd0;
    else if(state_mac && (fetch_cslice_cnt == fetch_cslice_num-1) && (fetch_rxs_cnt == fetch_rxs_num-1) && (fetch_kcol_cnt < mac_strip_len) && ~fetch_last_col_loop)
        fetch_w_cnt <= fetch_w_end?   'd0 : fetch_w_cnt+stride_w;
end

assign fetch_h_end = (fetch_h_cnt+stride_h >= fetch_h_num) && fetch_w_end;   
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        fetch_h_cnt <= 'd0;
    else if(mac_init || mac_done)
        fetch_h_cnt <= 'd0;
    else if(state_mac && fetch_w_end && ~fetch_last_col_loop)
        fetch_h_cnt <= fetch_h_end?   'd0 : fetch_h_cnt+stride_h;
end

assign fetch_frame_end = (fetch_w_cnt+stride_w >= fetch_w_num) && (fetch_h_cnt+stride_h >= fetch_h_num) && fetch_h_end;   

assign fetch_kslice_end = (fetch_kslice_cnt == fetch_kslice_num-1) && fetch_frame_end;   
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        fetch_kslice_cnt <= 'd0;
    else if(mac_init || mac_done)
        fetch_kslice_cnt <= 'd0;
    else if(state_mac && fetch_frame_end && ~fetch_last_col_loop)
        fetch_kslice_cnt <= fetch_kslice_end?   'd0 : fetch_kslice_cnt+1;
end


// DATA MEM interface //
logic first_col_loop;
logic last_col_loop;
logic [9:0] col_loop_cnt;
logic [WADDR_WD-1:0] data_raddr_line_base;
logic [WADDR_WD-1:0] data_raddr_strip_head_base;
logic [WADDR_WD-1:0] data_raddr_chn_head_base;
logic [WADDR_WD-1:0] data_raddr_rxs_base;
logic [WADDR_WD-1:0] data_raddr_line_base_next;
logic [WADDR_WD-1:0] data_raddr_strip_head_base_next;
logic [WADDR_WD-1:0] data_raddr_chn_head_base_next;
logic [WADDR_WD-1:0] data_raddr_rxs_base_next;
logic [WADDR_WD-1:0] data_raddr_next;

logic [9:0] fetch_data_x_head;
logic [9:0] fetch_data_y_head;
logic [9:0] fetch_data_x_tail;
logic [9:0] fetch_data_y_tail;
logic [9:0] fetch_data_x_head_next;
logic [9:0] fetch_data_y_head_next;
logic [9:0] fetch_data_x;
logic [9:0] fetch_data_y;
logic [9:0] fetch_data_c;

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        fetch_data_c <= 'd0;
    else if(mac_init || mac_done)
        fetch_data_c <= 'd0;
    else if(fetch_cslice_end)
        fetch_data_c <= 'd0;
    else if(fetch_rxs_end)
        fetch_data_c <= fetch_data_c + 1'b1;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        fetch_data_x_head <= 'd0;
        fetch_data_y_head <= 'd0;
    end
    else if(mac_init || mac_done) begin
        fetch_data_x_head <= 'd0;
        fetch_data_y_head <= 'd0;
    end
    else if(~fetch_padding) begin
        if(fetch_cslice_end) begin
            if(fetch_data_x_tail + stride_w > rg_in_w-1-rg_kernel_w + fetch_r_cnt) begin
                fetch_data_x_head <= 'd0;
                fetch_data_y_head <= fetch_data_y_tail + stride_h;
            end
            else begin
                fetch_data_x_head <= fetch_data_x_tail + stride_w;
            end
        end
        else if(fetch_kcol_end) begin
            if(fetch_data_x_head + stride_w > rg_in_w-1-rg_kernel_w + fetch_r_cnt) begin
                fetch_data_x_head <= 'd0;
                fetch_data_y_head <= fetch_data_y_head + stride_h * fetch_s_cnt;
            end
            else begin
                fetch_data_x_head <= fetch_data_x_head + stride_w * fetch_r_cnt;
            end
        end
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        fetch_data_x_tail <= 'd0;
        fetch_data_y_tail <= 'd0;
    end
    else if(mac_init || mac_done) begin
        fetch_data_x_tail <= 'd0;
        fetch_data_y_tail <= 'd0;
    end
    else if(~fetch_padding) begin   // todo
        if(fetch_kcol_end && (fetch_cslice_cnt == 0)) begin
            if(fetch_data_x + stride_w > rg_in_w-1-rg_kernel_w) begin
                fetch_data_x_tail <= 'd0;
                fetch_data_y_tail <= fetch_data_y + stride_h;
            end
            else begin
                fetch_data_x_tail <= fetch_data_x + stride_w;
            end
        end
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        fetch_data_x <= 'd0;
        fetch_data_y <= 'd0;
    end
    else if(mac_init || mac_done) begin
        fetch_data_x <= 'd0;
        fetch_data_y <= 'd0;
    end
    else if(~fetch_padding) begin   // todo
        if(fetch_kcol_end) begin
            fetch_data_x <= fetch_data_x_head;
            fetch_data_y <= fetch_data_y_head;
        end
        else begin
            if(fetch_data_x + stride_w > rg_in_w-1-rg_kernel_w) begin
                fetch_data_x <= 'd0;
                fetch_data_y <= fetch_data_y + stride_h;
            end
            else begin
                fetch_data_x <= fetch_data_x + stride_w;
            end
        end
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        src_mem_rd <= 1'b0;
    else if(state_mac && ~fetch_first_col_loop && ~fetch_padding)
        src_mem_rd <= 1'b1;
    else
        src_mem_rd <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_rvalid <= 1'b0;
    else if(src_mem_rd)
        data_rvalid <= 1'b1;
    else
        data_rvalid <= 1'b0;
end

///////////////////////// data raddr caculate ///////////////////////
//assign data_raddr_next = fetch_padding_x?   data_raddr_line_base_next :
//                                            (data_raddr + stride_w*mac_chn_slice_num);
assign data_raddr_next = src_mem_addr + stride_w*mac_chn_slice_num;
assign data_raddr_line_base_next = data_raddr_line_base + rg_in_w*mac_chn_slice_num;    // todo with rg_in_w
assign data_raddr_strip_head_base_next = data_raddr_strip_head_base + mac_strip_len*mac_chn_slice_num;
assign data_raddr_chn_head_base_next = data_raddr_chn_head_base + 1'b1;
assign data_raddr_rxs_base_next = data_raddr_rxs_base + 1'b1;   // todo

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        src_mem_addr <= 'd0;
    else if(mac_init)
        src_mem_addr <= rg_src_data_base;   // todo
    //else if(state_mac && ~fetch_first_col_loop && ~fetch_padding) begin
    else if(state_mac && ~fetch_first_col_loop) begin
        if(fetch_kslice_end)    // return to base
            src_mem_addr <= rg_src_data_base;
        else if(fetch_w_end)    // change line
            src_mem_addr <= data_raddr_line_base_next;
        else if(fetch_cslice_end)   // change input-strip
            src_mem_addr <= data_raddr_strip_head_base_next;
        else if(fetch_rxs_end)  // change channel
            src_mem_addr <= data_raddr_chn_head_base_next;
        else if(fetch_kcol_end) // change rxs input
            src_mem_addr <= data_raddr_rxs_base_next;
        else if(kcol_cnt < mac_strip_len)   // change one input
            src_mem_addr <= data_raddr_next;    // todo with stride w h and padding
    end
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_raddr_line_base <= 'd0;
    else if(mac_init)
        data_raddr_line_base <= rg_src_data_base;   // todo
    else if(state_mac && ~fetch_first_col_loop) begin
        if(fetch_w_end)    // change line
            data_raddr_line_base <= data_raddr_line_base_next;
    end
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_raddr_strip_head_base <= 'd0;
    else if(mac_init)
        data_raddr_strip_head_base <= rg_src_data_base; // todo
    else if(state_mac && ~fetch_first_col_loop) begin
        if(fetch_cslice_end)    // change input-strip
            data_raddr_strip_head_base <= data_raddr_strip_head_base_next;
    end
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_raddr_chn_head_base <= 'd0;
    else if(mac_init)
        data_raddr_chn_head_base <= rg_src_data_base;   // todo
    else if(state_mac && ~fetch_first_col_loop) begin
        if(fetch_rxs_end)    // change channel
            data_raddr_chn_head_base <= data_raddr_chn_head_base_next;
    end
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_raddr_rxs_base <= 'd0;
    else if(mac_init)
        data_raddr_rxs_base <= rg_src_data_base;    // todo
    else if(state_mac && ~fetch_first_col_loop) begin
        if(fetch_kcol_end)   // change rxs input
            data_raddr_rxs_base <= data_raddr_rxs_base_next;
    end
end
///////////////////////////////////////////////////////////////////////
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_to_mac <= 'd0;
    else if(state_mac && data_rvalid) begin
        if(fetch_padding_x)
            data_to_mac <= in_pad_x_value;
        else if(fetch_padding_y)
            data_to_mac <= in_pad_y_value;
        else
            data_to_mac <= src_mem_rdata;
    end
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_to_mac_vld <= 'd0;
    else if(state_mac && data_rvalid)
        data_to_mac_vld <= 1'b1;
    else
        data_to_mac_vld <= 1'b0;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_to_mac_mask <= {DDATA_WD{1'b1}};
    else if(state_mac && data_rvalid)
        data_to_mac_mask <= {DDATA_WD{1'b1}};
end
// WEIGHT MEM interface //
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        wgt_mem_rd <= 1'b0;
    else if(state_mac && ~fetch_last_col_loop && fetch_wgt)
        wgt_mem_rd <= 1'b1;
    else
        wgt_mem_rd <= 1'b0;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        wgt_rvalid <= 1'b0;
    else if(wgt_mem_rd)
        wgt_rvalid <= 1'b1;
    else
        wgt_rvalid <= 1'b0;
end
// wgt addr
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        wgt_mem_addr <= 'd0;
    else if(mac_init)
        wgt_mem_addr <= rg_coef_base-1; // todo
    else if(state_mac && ~fetch_last_col_loop && fetch_wgt)
        wgt_mem_addr <= wgt_mem_addr + 1'b1;    // todo
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        wgt_to_mac <= 'd0;
    else if(state_mac && wgt_rvalid)
        wgt_to_mac <= wgt_mem_rdata;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        wgt_to_mac_vld <= 'd0;
    else if(state_mac && wgt_rvalid && fetch_wgt)
        wgt_to_mac_vld <= 1'b1;
    else
        wgt_to_mac_vld <= 1'b0;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        wgt_to_mac_mask <= {WDATA_WD{1'b1}};
    else if(state_mac && wgt_rvalid)
        wgt_to_mac_mask <= {WDATA_WD{1'b1}};
end
/*
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        pingpong_flag <= 1'b0;
    else if(mac_init || mac_done)
        pingpong_flag <= 1'b0;
    else if(state_mac && fetch_kcol_end && data_rvalid)
        pingpong_flag <= ~pingpong_flag;
end
*/
assign pingpong_flag = ~wgt_to_mac_flag;    // todo delete one control
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        wgt_to_mac_flag <= 1'b0;
    else if(mac_init || mac_done)
        wgt_to_mac_flag <= 1'b0;
    else if(state_mac && fetch_kcol_end && wgt_rvalid)
        wgt_to_mac_flag <= ~wgt_to_mac_flag;
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
        mac_chn_slice_num <= ~(|rg_in_c[ROW_BW-1:0])?  (rg_in_c >> ROW_BW) : (rg_in_c >> ROW_BW) + 1;
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
        in_pad_x <= 'd0;
    else if(mac_init)
        in_pad_x <= rg_pad_x;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        in_pad_y <= 'd0;
    else if(mac_init)
        in_pad_y <= rg_pad_y;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        in_pad_x_value <= 'd0;
    else if(mac_init)
        in_pad_x_value <= rg_pad_x_value;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        in_pad_y_value <= 'd0;
    else if(mac_init)
        in_pad_y_value <= rg_pad_y_value;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        stride_w <= 'd0;
    else if(mac_init)
        stride_w <= rg_stride_w;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        stride_h <= 'd0;
    else if(mac_init)
        stride_h <= rg_stride_h;
end
endmodule