/*
    High performance pixelshuffle module
*/
module pixshff #(
    parameter DATA_WB = 4           ,
    parameter DATA_WD = DATA_WB * 8 ,
    parameter ADDR_WD = 16
)(
    input                       clk             ,
    input                       rstn            ,
    /* config */
    input [ADDR_WD-1:0]         rg_src_base     ,
    input [ADDR_WD-1:0]         rg_dest_base    ,
    input [2:0]                 rg_rfactor      ,
    input [7:0]                 rg_batch        ,
    input [15:0]                rg_inh          ,
    input [15:0]                rg_inw          ,
    input [15:0]                rg_inc          ,
    input [15:0]                rg_outh         ,
    input [15:0]                rg_outw         ,
    input [15:0]                rg_outc         ,
    /* Source memory interface */
    output logic                mem_src_rd      ,
    output logic                mem_src_wr      ,
    output logic [DATA_WB-1:0]  mem_src_wmask   ,
    output logic [ADDR_WD-1:0]  mem_src_addr    ,
    output logic [DATA_WD-1:-0] mem_src_wdata   ,
    input [DATA_WD-1:0]         mem_src_rdata   ,
    /* Dest memory interface */
    output logic                mem_dest_rd     ,
    output logic                mem_dest_wr     ,
    output logic [DATA_WB-1:0]  mem_dest_wmask  ,
    output logic [ADDR_WD-1:0]  mem_dest_addr   ,
    output logic [DATA_WD-1:-0] mem_dest_wdata  ,
    input [DATA_WD-1:0]         mem_dest_rdata  ,
    /* control */
    input                       pixshff_start   ,
    output logic                pixshff_done    
);
// todo //
parameter OFFSET = $clog2(DATA_WB);
parameter ARR_OFFSET = $clog2(ARR_W);
parameter ARR_W = DATA_WB;
parameter ARR_H = DATA_WB;
parameter ADD_WD = ADDR_WD;
parameter MULT_WD = ADDR_WD; 

logic pixshff_on;
logic pixshff_rd_done;
logic pixshff_rd_on;
logic pixshff_init_done;
logic pixshff_start_d1;
logic pixshff_start_d2;

logic [15:0] ldb_cnt;    // 加载数据到buffer中
logic [2:0] ldr_cnt;  // 几轮加载做完r^2个数
logic [2:0] ldc_cnt;   // 几次循环做完一个channel
logic [15:0] h_cnt;     
logic [15:0] w_cnt;
logic [15:0] batch_cnt;

logic [15:0] ldb_num; 
logic [15:0] addr_ldb_num;
logic [15:0] ldr_num;
logic [15:0] ldc_num;
logic [15:0] last_loop_ldb_num;

logic [4:0] rf_pow2;
logic [4:0] skip_index;
logic [15:0] aligned_inc;
logic [ADDR_WD-1:0] dest_line_step;
logic [ADDR_WD-1:0] dest_chn_step;

logic last_load_loop;

logic ldb_end;
logic ldr_end;
logic ldc_end;
logic c_end;
logic w_end;
logic h_end;
logic frame_end;
logic batch_end;

logic need_t2;  // 有跨地址取数
logic fetch_vld;    // 完整数据取到
logic fetch_cnt;
logic mem_rd_pre;
logic src_rdata_vld;

logic [ADDR_WD-1:0] pixel_index_c_head;
logic [ADDR_WD-1:0] pixel_index_r_head;
logic [ADDR_WD-1:0] pixel_index_p;
logic [ADDR_WD-1:0] mem_src_addr_next;
logic [ADDR_WD-1:0] pixel_index_c_head_next;
logic [ADDR_WD-1:0] pixel_index_r_head_next;
logic [ADDR_WD-1:0] pixel_index_p_head_next;
logic [ADDR_WD-1:0] mem_addr_r_head_next;
logic [ADDR_WD-1:0] mem_addr_rx_head_next;
logic [ADDR_WD-1:0] mem_addr_p_head_next;


logic [DATA_WB-1:0] BUFF_ARRAY [ARR_H-1:0][ARR_W-1:0];
logic first_ldb_loop;
logic xy_flag;
logic [DATA_WD-1:0] rdata_aligned;
logic [DATA_WD-1:0] rdata_t1;
logic [OFFSET-1:0] rdata_offset;

logic [15:0] out_ldc_num;
logic [2:0]  out_rx_cnt; 
logic [2:0]  out_ry_cnt; 
logic [15:0] out_c_cnt; 
logic [15:0] out_w_cnt;
logic [15:0] out_h_cnt;
logic [7:0]  out_batch_cnt;
logic out_rx_end;
logic out_ry_end;
logic out_c_end;
logic out_w_end;
logic out_h_end;
logic out_batch_end;

logic data_out_vld_pre;
logic [4:0] data_out_cnt;
logic [DATA_WD-1:0] data_out;
logic [3:0] buff_index_l;
logic [3:0] buff_index_h;
logic [ADDR_WD-1:0] mem_addr_r_head;
logic [ADDR_WD-1:0] mem_addr_c_head;
logic [ARR_OFFSET-1:0] wmask_offset;

logic xy_flag_d1;
logic xy_flag_d2;
logic [OFFSET-1:0] addr_offset_d1;
logic [OFFSET-1:0] addr_offset_d2;
logic [15:0] ldb_cnt_d1;
logic [15:0] ldb_cnt_d2;
logic need_t2_d1;
logic need_t2_d2;
logic fetch_cnt_d1;
logic fetch_cnt_d2;
logic fetch_vld_d1;
logic fetch_vld_d2;
logic rdata_need_t2;
logic rdata_fetch_cnt;
logic first_ldb_loop_d1;
logic first_ldb_loop_d2;


// ADDs && MULTs behavior model //
logic [ADD_WD-1:0] add1_a;
logic [ADD_WD-1:0] add1_b;
logic [ADD_WD-1:0] add1_sum;
assign add1_sum = add1_a + add1_b;
logic [ADD_WD-1:0] add2_a;
logic [ADD_WD-1:0] add2_b;
logic [ADD_WD-1:0] add2_sum;
assign add2_sum = add2_a + add2_b;
logic [ADD_WD-1:0] add3_a;
logic [ADD_WD-1:0] add3_b;
logic [ADD_WD-1:0] add3_sum;
assign add3_sum = add3_a + add3_b;

logic [MULT_WD-1:0] mult1_a;
logic [MULT_WD-1:0] mult1_b;
logic [2*MULT_WD-1:0] mult1_out;
assign mult1_out = mult1_a * mult1_b;
logic [MULT_WD-1:0] mult2_a;
logic [MULT_WD-1:0] mult2_b;
logic [2*MULT_WD-1:0] mult2_out;
assign mult2_out = mult2_a * mult2_b;

// ADDs && MULTs interface //
assign add1_a = rg_src_base;
assign add1_b = pixel_index_p[ADDR_WD-1:OFFSET];

assign add2_a = c_end?      pixel_index_c_head :
                ldr_end?    pixel_index_r_head :
                ldb_end?    pixel_index_r_head : pixel_index_p;

assign add2_b = c_end?      aligned_inc :
                ldr_end?    mult1_out :    //skip_index * addr_ldb_num : // todo MULT
                ldb_end?    ((ldr_cnt + 1) << ARR_OFFSET) : skip_index;

assign add3_a = out_c_end?     mem_addr_r_head :
                out_rx_end?    mem_addr_c_head : mem_dest_addr ;

assign add3_b = out_c_end?     dest_line_step :
                out_rx_end?    mult2_out :     //dest_chn_step * (out_ry_cnt+1) : // todo MULT
                               out_ldc_num ;

assign mult1_a = pixshff_start_d2?  rg_rfactor : skip_index;
assign mult1_b = pixshff_start_d2?  out_ldc_num : addr_ldb_num;

assign mult2_a = pixshff_start_d2?  rg_outw : dest_chn_step;
assign mult2_b = pixshff_start_d2?  out_ldc_num : (out_ry_cnt+1);

// init--pre caculate //
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        rf_pow2 <= 'd0;
    else if(pixshff_start)  // save MULT
        //rf_pow2 <= rg_rfactor * rg_rfactor;
        rf_pow2 <= (rg_rfactor == 2)?   'd4 :
                   (rg_rfactor == 3)?   'd9 : 'd16;
end

always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        aligned_inc <= 'd0;
    else if(pixshff_start)
        aligned_inc <= (|rg_inc[OFFSET-1:0])?   ((rg_inc[15:OFFSET]+1'b1) << OFFSET) : rg_inc;
end

always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        dest_line_step <= 'd0;
    else if(pixshff_start_d2)
        dest_line_step <= mult1_out; //rg_rfactor * out_ldc_num;
end

always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        dest_chn_step <= 'd0;
    else if(pixshff_start_d2)
        dest_chn_step <= mult2_out;  //rg_outw * out_ldc_num;
end

// TOP control //
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        {pixshff_start_d1,pixshff_start_d2} <= 'b0;
    else
        {pixshff_start_d1,pixshff_start_d2} <= {pixshff_start,pixshff_start_d1};
end

assign pixshff_init_done = pixshff_start_d2;
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        pixshff_on <= 1'b0;
    else if(pixshff_init_done)
        pixshff_on <= 1'b1;
    else if(pixshff_done)
        pixshff_on <= 1'b0;
end

always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        pixshff_done <= 1'b0;
    else if(pixshff_on && out_batch_end)
        pixshff_done <= 1'b1;
    else
        pixshff_done <= 1'b0;
end

always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        pixshff_rd_on <= 1'b0;
    else if(pixshff_init_done)
        pixshff_rd_on <= 1'b1;
    else if(batch_end)//(pixshff_rd_done)
        pixshff_rd_on <= 1'b0;
end

always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        pixshff_rd_done <= 1'b0;
    else if(pixshff_rd_on && batch_end)
        pixshff_rd_done <= 1'b1;
    else
        pixshff_rd_done <= 1'b0;
end

// fetch src data control //
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        ldc_num <= 'd0;
    else if(pixshff_start_d1) begin
        if(rf_pow2 <= (DATA_WB >> 1))
            ldc_num <= rg_outc[15:ARR_OFFSET+1] + (|rg_outc[ARR_OFFSET-1:0]);
        else
            ldc_num <= rg_outc[15:ARR_OFFSET] + (|rg_outc[ARR_OFFSET-1:0]);
    end
end
assign ldr_num = (rf_pow2 <= DATA_WB /*&& (rf_pow2 > (DATA_WB >> 1))*/)?   'd1 : 'd2;  // 只考虑1和2，有需要再拓展
assign addr_ldb_num = (last_load_loop && rg_outc[ARR_OFFSET-1:0] != 0)?    last_loop_ldb_num : 
                                                                      ((rf_pow2 < DATA_WB)?   rf_pow2 : DATA_WB);  // todo 
assign ldb_num = ((rf_pow2 < DATA_WB)?   rf_pow2 : DATA_WB); // considering data out
assign last_load_loop = (ldc_cnt == ldc_num-1);
assign last_loop_ldb_num = (rf_pow2 <= (DATA_WB >> 1))?    (rg_outc[ARR_OFFSET-1:1] + rg_outc[0]) : rg_outc[ARR_OFFSET-1:0];
assign skip_index = (rf_pow2 <= DATA_WB)?   DATA_WB : rf_pow2;
assign first_ldb_loop = pixshff_rd_on && (ldc_cnt == 0) && (ldr_cnt == 0) && (w_cnt == 0) && (h_cnt == 0) && (batch_cnt == 0);

assign ldb_end = fetch_vld && (ldb_cnt == ldb_num-1);
always_ff @(posedge clk or negedge rstn) begin  // special for last out loop
    if(~rstn)
        ldb_cnt <= 'd0;
    else if(pixshff_init_done || pixshff_done)
        ldb_cnt <= 'd0;
    else if(pixshff_on && fetch_vld)
        ldb_cnt <= ldb_end?   'd0 : ldb_cnt + 1'b1;
end

assign ldr_end = ldb_end && (ldr_cnt == ldr_num-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        ldr_cnt <= 'd0;
    else if(pixshff_init_done || pixshff_rd_done)
        ldr_cnt <= 'd0;
    else if(pixshff_rd_on && ldb_end)
        ldr_cnt <= ldr_end?   'd0 : ldr_cnt + 1'b1;
end

assign ldc_end = ldr_end && (ldc_cnt == ldc_num-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        ldc_cnt <= 'd0;
    else if(pixshff_init_done || pixshff_rd_done)
        ldc_cnt <= 'd0;
    else if(pixshff_rd_on && ldr_end)
        ldc_cnt <= ldc_end?   'd0 : ldc_cnt + 1'b1;
end

assign c_end = ldc_end;

assign w_end = c_end && (w_cnt == rg_inw-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        w_cnt <= 'd0;
    else if(pixshff_init_done || pixshff_rd_done)
        w_cnt <= 'd0;
    else if(pixshff_rd_on && c_end)
        w_cnt <= w_end?   'd0 : w_cnt + 1'b1;
end

assign h_end = w_end && (h_cnt == rg_inh-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        h_cnt <= 'd0;
    else if(pixshff_init_done || pixshff_rd_done)
        h_cnt <= 'd0;
    else if(pixshff_rd_on && w_end)
        h_cnt <= h_end?   'd0 : h_cnt + 1'b1;
end

assign frame_end = w_end && h_end;

assign batch_end = frame_end && (batch_cnt == rg_batch-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        batch_cnt <= 'd0;
    else if(pixshff_init_done || pixshff_rd_done)
        batch_cnt <= 'd0;
    else if(pixshff_rd_on && frame_end)
        batch_cnt <= batch_end?   batch_cnt : batch_cnt + 1'b1;
end

// cross address boundry //
assign need_t2 = |pixel_index_p[OFFSET-1:0];    
assign fetch_vld = ~(need_t2 && ~fetch_cnt) && pixshff_on;  // special for last data out

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        {fetch_vld_d2, fetch_cnt_d1} <= 2'd0;
    else if(pixshff_done)
        {fetch_vld_d2, fetch_cnt_d1} <= 2'd0;
    else
        {fetch_vld_d2, fetch_cnt_d1} <= {fetch_vld_d1, fetch_cnt};
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        fetch_cnt <= 1'b0;
    else if(pixshff_init_done || pixshff_done)
        fetch_cnt <= 1'b0;
    else if(pixshff_on) begin
        if(need_t2)
            fetch_cnt <= fetch_cnt + 1;
        else
            fetch_cnt <= 1'b0;
    end
end

// source memory interface //
assign mem_src_addr_next = add1_sum;   
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem_src_addr <= 'd0;
    else if(pixshff_init_done)
        mem_src_addr <= rg_src_base;
    else if(pixshff_rd_on) begin
        if(need_t2 && fetch_cnt)
            mem_src_addr <= mem_src_addr_next + 1;  
        else 
            mem_src_addr <= mem_src_addr_next;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem_src_rd <= 1'b0;
    else if(pixshff_init_done)
        mem_src_rd <= 1'b1;
    else if(pixshff_rd_on && mem_rd_pre)
        mem_src_rd <= 1'b1;
    else 
        mem_src_rd <= 1'b0;
end

assign mem_src_wr = 1'b0;
assign mem_src_wmask = 'd0;
assign mem_src_wdata = 'd0;

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem_rd_pre <= 'd0;
    else if(pixshff_init_done)
        mem_rd_pre <= 1'b1;
    else if(pixshff_rd_on && ((ldb_cnt == ldb_num-1) || (ldb_cnt <= addr_ldb_num-1)))
        mem_rd_pre <= 1'b1;
    else
        mem_rd_pre <= 1'b0;
end

assign pixel_index_c_head_next = add2_sum;  
assign pixel_index_r_head_next = add2_sum;  
assign pixel_index_p_head_next = add2_sum;  

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        pixel_index_c_head <= 'd0;
    else if(pixshff_init_done)
        pixel_index_c_head <= 'd0;
    else if(pixshff_rd_on && c_end) 
        pixel_index_c_head <= pixel_index_c_head_next;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        pixel_index_r_head <= 'd0;
    else if(pixshff_init_done)
        pixel_index_r_head <= 'd0;
    else if(pixshff_rd_on) begin
        if(c_end)
            pixel_index_r_head <= pixel_index_c_head_next;
        else if(ldr_end)
            pixel_index_r_head <= pixel_index_r_head_next;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        pixel_index_p <= 'd0;
    else if(pixshff_init_done)
        pixel_index_p <= 'd0;
    else if(pixshff_rd_on) begin
        if(c_end)
            pixel_index_p <= pixel_index_c_head_next;
        else if(ldr_end)
            pixel_index_p <= pixel_index_r_head_next;
        else if(ldb_end)
            pixel_index_p <= pixel_index_p_head_next;    
        else if(fetch_vld && (ldb_cnt < addr_ldb_num-1))
            pixel_index_p <= pixel_index_p_head_next; 
    end
end

// fetch_vld --> rdata spend 2clk //
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        src_rdata_vld <= 1'b0;
    else if(mem_src_rd)
        src_rdata_vld <= 1'b1;
    else
        src_rdata_vld <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        xy_flag <= 1'b0;
    else if(pixshff_init_done || pixshff_done)
        xy_flag <= 1'b0;
    else if(pixshff_on && ldb_end)
        xy_flag <= ~xy_flag;
end

assign rdata_offset = addr_offset_d2;
assign rdata_need_t2 = need_t2_d2;
assign rdata_fetch_cnt = fetch_cnt_d2;

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        {addr_offset_d1,addr_offset_d2} <= 'd0;
    else if(pixshff_done)
        {addr_offset_d1,addr_offset_d2} <= 'd0;
    else if(pixshff_on)
        {addr_offset_d1,addr_offset_d2} <= {pixel_index_p[OFFSET-1:0], addr_offset_d1};
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        {xy_flag_d2, xy_flag_d1} <= 'd0;
    else if(pixshff_done)
        {xy_flag_d2, xy_flag_d1} <= 'd0;
    else if(pixshff_on)
        {xy_flag_d2, xy_flag_d1} <= {xy_flag_d1, xy_flag};
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        {ldb_cnt_d2, ldb_cnt_d1} <= 'd0;
    else if(pixshff_done)
        {ldb_cnt_d2, ldb_cnt_d1} <= 'd0;
    else if(pixshff_on)
        {ldb_cnt_d2, ldb_cnt_d1} <= {ldb_cnt_d1, ldb_cnt};
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        {first_ldb_loop_d1,first_ldb_loop_d2} <= 'd0;
    else if(pixshff_done)
        {first_ldb_loop_d1,first_ldb_loop_d2} <= 'd0;
    else
        {first_ldb_loop_d1,first_ldb_loop_d2} <= {first_ldb_loop, first_ldb_loop_d1};
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        {need_t2_d2, need_t2_d1} <= 'd0;
    else if(pixshff_done)
        {need_t2_d2, need_t2_d1} <= 'd0;
    else if(pixshff_on)
        {need_t2_d2, need_t2_d1} <= {need_t2_d1, need_t2};
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        {fetch_cnt_d2, fetch_cnt_d1} <= 'd0;
    else if(pixshff_done)
        {fetch_cnt_d2, fetch_cnt_d1} <= 'd0;
    else if(pixshff_on)
        {fetch_cnt_d2, fetch_cnt_d1} <= {fetch_cnt_d1, fetch_cnt};
end

// rdata aligned //
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        rdata_t1 <= 'd0;
    else if(pixshff_on && src_rdata_vld && rdata_need_t2 && ~rdata_fetch_cnt)
        rdata_t1 <= mem_src_rdata;
end

// todo with parameter
always@(*) begin
    rdata_aligned = 'd0;
    case(rdata_offset)
        0 : rdata_aligned = mem_src_rdata;
        1 : rdata_aligned = {mem_src_rdata[8 -1:0], rdata_t1[DATA_WD-1:8 ]};
        2 : rdata_aligned = {mem_src_rdata[16-1:0], rdata_t1[DATA_WD-1:16]};
        3 : rdata_aligned = {mem_src_rdata[24-1:0], rdata_t1[DATA_WD-1:24]};
        4 : rdata_aligned = {mem_src_rdata[32-1:0], rdata_t1[DATA_WD-1:32]};
        5 : rdata_aligned = {mem_src_rdata[40-1:0], rdata_t1[DATA_WD-1:40]};
        6 : rdata_aligned = {mem_src_rdata[48-1:0], rdata_t1[DATA_WD-1:48]};
        7 : rdata_aligned = {mem_src_rdata[56-1:0], rdata_t1[DATA_WD-1:56]};
        default : rdata_aligned = 'd0;
    endcase
end

// data re-arrange //
genvar x,y;
generate
    for(x=0;x<ARR_H;x=x+1) begin : X_BK
        for(y=0;y<ARR_W;y=y+1) begin : Y_BK
            always_ff@(posedge clk or negedge rstn) begin
                if(~rstn)
                    BUFF_ARRAY[x][y] <= 'd0;
                else if(pixshff_on && src_rdata_vld) begin
                    if(rf_pow2 <= (DATA_WB >> 1)) begin
                        if(~xy_flag_d2 && x == ldb_cnt_d2) begin
                            if(rdata_need_t2 && rdata_fetch_cnt)  begin
                                BUFF_ARRAY[x][y] <= rdata_aligned[y*8+7:y*8];
                            end
                            else if(~rdata_need_t2) begin
                                BUFF_ARRAY[x][y] <= mem_src_rdata[y*8+7:y*8];
                            end
                        end
                        else if(xy_flag_d2 && x == (ldb_cnt_d2 + (DATA_WB >> 1))) begin
                            if(rdata_need_t2 && rdata_fetch_cnt)  begin
                                BUFF_ARRAY[x][y] <= rdata_aligned[y*8+7:y*8];
                            end
                            else if(~rdata_need_t2) begin
                                BUFF_ARRAY[x][y] <= mem_src_rdata[y*8+7:y*8];
                            end
                        end
                    end
                    else begin
                        if(~xy_flag_d2 && x == ldb_cnt_d2) begin
                            if(rdata_need_t2 && rdata_fetch_cnt)  begin
                                BUFF_ARRAY[x][y] <= rdata_aligned[y*8+7:y*8];
                            end
                            else if(~rdata_need_t2) begin
                                BUFF_ARRAY[x][y] <= mem_src_rdata[y*8+7:y*8];
                            end
                        end
                        else if(xy_flag_d2 && y == ldb_cnt_d2) begin
                            if(rdata_need_t2 && rdata_fetch_cnt)  begin
                                BUFF_ARRAY[x][y] <= rdata_aligned[x*8+7:x*8];
                            end
                            else if(~rdata_need_t2) begin
                                BUFF_ARRAY[x][y] <= mem_src_rdata[x*8+7:x*8];
                            end
                        end
                    end
                end
            end
        end
    end

endgenerate

assign data_out_vld_pre =  (/*fetch_vld*/fetch_vld_d2 && ~(first_ldb_loop || first_ldb_loop_d2) && ~out_batch_end && ~pixshff_done) && (data_out_cnt < rf_pow2);    // todo with last ldb loop

logic data_out_cnt_vld_pre;
assign data_out_cnt_vld_pre = (/*fetch_vld*/fetch_vld_d2 && ~(first_ldb_loop || first_ldb_loop_d2) && ~out_batch_end && ~pixshff_done);

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_out_cnt <= 'd0;
    else if(pixshff_init_done || pixshff_done)
        data_out_cnt <= 'd0;
    else if((ldb_cnt_d2 == ldb_num-1) && (data_out_cnt >= rf_pow2-1) && /*fetch_vld*/data_out_cnt_vld_pre)
        data_out_cnt <= 'd0;
    else if(data_out_vld_pre) begin 
        data_out_cnt <= (data_out_cnt >= rf_pow2)?     data_out_cnt : data_out_cnt+1;
    end
end
// todo parameter
assign buff_index_l = ldb_cnt_d2;
assign buff_index_h = ldb_cnt_d2 + (DATA_WB >> 1);
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_out <= 'd0;
    else if(data_out_vld_pre) begin   
        if (rf_pow2 <= (DATA_WB >> 1)) begin
            if(xy_flag_d2)
                data_out <= {BUFF_ARRAY[3][buff_index_h],BUFF_ARRAY[3][buff_index_l],BUFF_ARRAY[2][buff_index_h],BUFF_ARRAY[2][buff_index_l],
                             BUFF_ARRAY[1][buff_index_h],BUFF_ARRAY[1][buff_index_l],BUFF_ARRAY[0][buff_index_h],BUFF_ARRAY[0][buff_index_l]};
            else 
               data_out <= {BUFF_ARRAY[7][buff_index_h],BUFF_ARRAY[7][buff_index_l],BUFF_ARRAY[6][buff_index_h],BUFF_ARRAY[6][buff_index_l],
                            BUFF_ARRAY[5][buff_index_h],BUFF_ARRAY[5][buff_index_l],BUFF_ARRAY[4][buff_index_h],BUFF_ARRAY[4][buff_index_l]};            
        end
        else begin
            if(xy_flag_d2)
                data_out <= {BUFF_ARRAY[7][buff_index_l],BUFF_ARRAY[6][buff_index_l],BUFF_ARRAY[5][buff_index_l],BUFF_ARRAY[4][buff_index_l],
                             BUFF_ARRAY[3][buff_index_l],BUFF_ARRAY[2][buff_index_l],BUFF_ARRAY[1][buff_index_l],BUFF_ARRAY[0][buff_index_l]};
            else 
                data_out <= {BUFF_ARRAY[buff_index_l][7],BUFF_ARRAY[buff_index_l][6],BUFF_ARRAY[buff_index_l][5],BUFF_ARRAY[buff_index_l][4],
                             BUFF_ARRAY[buff_index_l][3],BUFF_ARRAY[buff_index_l][2],BUFF_ARRAY[buff_index_l][1],BUFF_ARRAY[buff_index_l][0]};
        end
    end
end

// data out control //
assign out_ldc_num = (rg_outc[15:ARR_OFFSET] + (|rg_outc[ARR_OFFSET-1:0]));   // +1 or +0
assign out_rx_end = mem_dest_wr && (out_rx_cnt == rg_rfactor-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        out_rx_cnt <= 'd0;
    else if(pixshff_init_done || pixshff_done)
        out_rx_cnt <= 'd0;
    else if(mem_dest_wr)
        out_rx_cnt <= out_rx_end?   'd0 : out_rx_cnt + 1'b1;
end

assign out_ry_end = out_rx_end && (out_ry_cnt == rg_rfactor-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        out_ry_cnt <= 'd0;
    else if(pixshff_init_done || pixshff_done)
        out_ry_cnt <= 'd0;
    else if(out_rx_end)
        out_ry_cnt <= out_ry_end?   'd0 : out_ry_cnt + 1'b1;
end

assign out_c_end = out_rx_end && out_ry_end && (out_c_cnt == out_ldc_num-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        out_c_cnt <= 'd0;
    else if(pixshff_init_done || pixshff_done)
        out_c_cnt <= 'd0;
    else if(out_rx_end && out_ry_end)
        out_c_cnt <= out_c_end?   'd0 : out_c_cnt + 1'b1;
end

assign out_w_end = out_c_end && (out_w_cnt == rg_inw-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        out_w_cnt <= 'd0;
    else if(pixshff_init_done || pixshff_done)
        out_w_cnt <= 'd0;
    else if(out_c_end)
        out_w_cnt <= out_w_end?   'd0 : out_w_cnt + 1'b1;
end

assign out_h_end = out_w_end && (out_h_cnt == rg_inh-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        out_h_cnt <= 'd0;
    else if(pixshff_init_done || pixshff_done)
        out_h_cnt <= 'd0;
    else if(out_w_end)
        out_h_cnt <= out_h_end?   'd0 : out_h_cnt + 1'b1;
end

assign out_frame_end = out_w_end && out_h_end;

assign out_batch_end = out_frame_end && (out_batch_cnt == rg_batch-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        out_batch_cnt <= 'd0;
    else if(pixshff_init_done || pixshff_done)
        out_batch_cnt <= 'd0;
    else if(out_frame_end)
        out_batch_cnt <= out_batch_end?   'd0 : out_batch_cnt + 1'b1;
end

// dest memory interface //
assign mem_dest_wdata = data_out;
assign mem_dest_rd = 1'b0;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem_dest_wr <= 1'b0;
    else if(data_out_vld_pre)
        mem_dest_wr <= 1'b1;
    else 
        mem_dest_wr <= 1'b0;
end

assign mem_addr_r_head_next = add3_sum;
assign mem_addr_rx_head_next = add3_sum;
assign mem_addr_p_head_next =  add3_sum;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem_dest_addr <= 'd0;
    else if(pixshff_init_done || pixshff_done)
        mem_dest_addr <= rg_dest_base;
    else begin
        if(out_w_end)
            mem_dest_addr <= mem_dest_addr + 1;
        else if(out_c_end)
            mem_dest_addr <= mem_addr_r_head_next;   
        else if(out_rx_end && out_ry_end)
            mem_dest_addr <= mem_addr_c_head + 1;
        else if(out_rx_end)
            mem_dest_addr <= mem_addr_rx_head_next;   
        else if(mem_dest_wr)
            mem_dest_addr <= mem_addr_p_head_next;   
    end
end

always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        mem_addr_r_head <= 'd0;
    else if(pixshff_init_done || pixshff_done)
        mem_addr_r_head <= rg_dest_base;
    else if(out_w_end)
        mem_addr_r_head <= mem_dest_addr + 1;
    else if(out_c_end)
        mem_addr_r_head <= mem_addr_r_head_next;  
end

always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        mem_addr_c_head <= 'd0;
    else if(pixshff_init_done || pixshff_done)
        mem_addr_c_head <= rg_dest_base;
    else if(out_w_end)
        mem_addr_c_head <= mem_dest_addr + 1;
    else if(out_c_end)
        mem_addr_c_head <= mem_addr_r_head_next;  
    else if(out_rx_end && out_ry_end)
        mem_addr_c_head <= mem_addr_c_head + 1;
end

assign wmask_offset = rg_outc[ARR_OFFSET-1:0];
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem_dest_wmask <= {DATA_WB{1'b1}};
    else if(out_ldc_num == 1)
        mem_dest_wmask <= {{(DATA_WB-wmask_offset){1'b0}},{wmask_offset{1'b1}}} ;
    else if(out_rx_end && out_ry_end) begin
        if(out_c_cnt == out_ldc_num-2)
            mem_dest_wmask <= {{(DATA_WB-wmask_offset){1'b0}},{wmask_offset{1'b1}}} ;
        else
            mem_dest_wmask <= {DATA_WB{1'b1}};
    end
end

endmodule