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
parameter OFFSET = $clog2(DATA_WB);
parameter ARR_OFFSET = $clog2(ARR_W);
parameter ARR_W = DATA_WB;
parameter ARR_H = DATA_WB;

logic pixshff_on;
logic pixshff_rd_start;
logic pixshff_rd_done;
logic pixshff_rd_on;

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
logic [4:0] rf_pow2;
logic [4:0] skip_index;
logic [15:0] aligned_inc;
logic [15:0] last_loop_ldb_num;

logic last_load_loop;

logic ldb_end;
logic ldr_end;
logic ldc_end;
logic w_end;
logic h_end;
logic frame_end;
logic batch_end;

logic need_t2;  // 有跨地址取数
logic fetch_vld;    // 完整数据取到
logic fetch_cnt;


logic src_rdata_vld;

logic mem_rd_pre;

logic first_ldb_loop;
logic last_ldb_loop;

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
logic last_data_out_loop;

assign ldc_num = rg_outc[15:ARR_OFFSET] + (|rg_outc[ARR_OFFSET-1:0]);
assign ldr_num = (rf_pow2 <= DATA_WB)?   'd1 : 'd2;  // 只考虑1和2，有需要再拓展
assign addr_ldb_num = (last_load_loop && rg_outc[ARR_OFFSET-1:0] != 0)?    last_loop_ldb_num : 
                                                                      ((rf_pow2 < DATA_WB)?   rf_pow2 : DATA_WB);  // todo 
assign ldb_num = ((rf_pow2 < DATA_WB)?   rf_pow2 : DATA_WB); // considering data out
assign last_load_loop = (ldc_cnt == ldc_num-1);
assign last_loop_ldb_num = (rf_pow2 <= (DATA_WB >> 1))?    (rg_outc[ARR_OFFSET-1:1] + rg_outc[0]) : rg_outc[ARR_OFFSET-1:0];
assign skip_index = (rf_pow2 <= DATA_WB)?   DATA_WB : rf_pow2;

assign first_ldb_loop = pixshff_rd_on && (ldc_cnt == 0) && (ldr_cnt == 0) && (w_cnt == 0) && (h_cnt == 0) && (batch_cnt == 0);
assign last_ldb_loop = (ldc_cnt == ldc_num-1) && (ldr_cnt == ldr_num-1) && (w_cnt == rg_inw-1) && (h_cnt == rg_inc-1) && (batch_cnt == rg_batch-1);

always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        pixshff_on <= 1'b0;
    else if(pixshff_start)
        pixshff_on <= 1'b1;
    else if(pixshff_done)
        pixshff_on <= 1'b0;
end

always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        pixshff_rd_on <= 1'b0;
    else if(pixshff_start)
        pixshff_rd_on <= 1'b1;
    else if(pixshff_rd_done)
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
        rf_pow2 <= 'd0;
    else if(pixshff_start)
        rf_pow2 <= rg_rfactor * rg_rfactor;
end

always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        aligned_inc <= 'd0;
    else if(pixshff_start)
        aligned_inc <= (|rg_inc[OFFSET-1:0])?   ((rg_inc[15:OFFSET]+1'b1) << OFFSET) : rg_inc;
end

assign ldb_end = fetch_vld && (ldb_cnt == ldb_num-1);
always_ff @(posedge clk or negedge rstn) begin  // special for last out loop
    if(~rstn)
        ldb_cnt <= 'd0;
    else if(pixshff_start || pixshff_done)
        ldb_cnt <= 'd0;
    else if(pixshff_on && fetch_vld)
        ldb_cnt <= ldb_end?   'd0 : ldb_cnt + 1'b1;
end

assign ldr_end = ldb_end && (ldr_cnt == ldr_num-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        ldr_cnt <= 'd0;
    else if(pixshff_start || pixshff_rd_done)
        ldr_cnt <= 'd0;
    else if(pixshff_rd_on && ldb_end)
        ldr_cnt <= ldr_end?   'd0 : ldr_cnt + 1'b1;
end

assign ldc_end = ldr_end && (ldc_cnt == ldc_num-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        ldc_cnt <= 'd0;
    else if(pixshff_start || pixshff_rd_done)
        ldc_cnt <= 'd0;
    else if(pixshff_rd_on && ldr_end)
        ldc_cnt <= ldc_end?   'd0 : ldc_cnt + 1'b1;
end

assign c_end = ldc_end;

assign w_end = c_end && (w_cnt == rg_inw-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        w_cnt <= 'd0;
    else if(pixshff_start || pixshff_rd_done)
        w_cnt <= 'd0;
    else if(pixshff_rd_on && c_end)
        w_cnt <= w_end?   'd0 : w_cnt + 1'b1;
end

assign h_end = w_end && (h_cnt == rg_inh-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        h_cnt <= 'd0;
    else if(pixshff_start || pixshff_rd_done)
        h_cnt <= 'd0;
    else if(pixshff_rd_on && w_end)
        h_cnt <= h_end?   'd0 : h_cnt + 1'b1;
end

assign frame_end = w_end && h_end;

assign batch_end = frame_end && (batch_cnt == rg_batch-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        batch_cnt <= 'd0;
    else if(pixshff_start || pixshff_rd_done)
        batch_cnt <= 'd0;
    else if(pixshff_rd_on && frame_end)
        batch_cnt <= batch_end?   batch_cnt : batch_cnt + 1'b1;
end

logic [ADDR_WD-1:0] pixel_index_c_head;
logic [ADDR_WD-1:0] pixel_index_r_head;

logic [ADDR_WD-1:0] pixel_index_p;

assign need_t2 = |pixel_index_p[OFFSET-1:0];
assign fetch_vld = ~(need_t2 && ~fetch_cnt) && pixshff_on;

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        fetch_cnt <= 1'b0;
    else if(pixshff_start)
        fetch_cnt <= 1'b0;
    else if(pixshff_on) begin
        if(need_t2)
            fetch_cnt <= fetch_cnt + 1;
        else
            fetch_cnt <= 1'b0;
    end
    else if(pixshff_done)
        fetch_cnt <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem_src_addr <= 'd0;
    else if(pixshff_start)
        mem_src_addr <= rg_src_base;
    else if(pixshff_rd_on) begin
        if(need_t2 && fetch_cnt)
            mem_src_addr <= rg_src_base + pixel_index_p[ADDR_WD-1:OFFSET] + 1;
        else 
            mem_src_addr <= rg_src_base + pixel_index_p[ADDR_WD-1:OFFSET];
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem_src_rd <= 1'b0;
    else if(pixshff_start)
        mem_src_rd <= 1'b1;
    else if(pixshff_rd_on && mem_rd_pre)
        mem_src_rd <= 1'b1;
    else 
        mem_src_rd <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        pixel_index_c_head <= 'd0;
    else if(pixshff_start)
        pixel_index_c_head <= 'd0;
    else if(pixshff_rd_on && c_end) 
        pixel_index_c_head <= pixel_index_c_head + aligned_inc;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        pixel_index_r_head <= 'd0;
    else if(pixshff_start)
        pixel_index_r_head <= 'd0;
    else if(pixshff_rd_on) begin
        if(c_end)
            pixel_index_r_head <= pixel_index_c_head + aligned_inc;
        else if(ldr_end)
            pixel_index_r_head <= pixel_index_r_head + skip_index * addr_ldb_num;
    end
end

// todo with combination logic //
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        pixel_index_p <= 'd0;
    else if(pixshff_start)
        pixel_index_p <= 'd0;
    else if(pixshff_rd_on) begin
        if(c_end)
            pixel_index_p <= pixel_index_c_head + aligned_inc;
        else if(ldr_end)
            pixel_index_p <= pixel_index_r_head + skip_index * addr_ldb_num;
        else if(ldb_end)
            pixel_index_p <= pixel_index_r_head + (ldr_cnt + 1) * ARR_W;    // todo with add rxy_cnt
        else if(fetch_vld && (ldb_cnt < addr_ldb_num-1))
            pixel_index_p <= pixel_index_p + skip_index; // todo pre provide r*r
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem_rd_pre <= 'd0;
    else if(pixshff_start)
        mem_rd_pre <= 1'b1;
    else if(pixshff_rd_on && ((ldb_cnt == ldb_num-1) || (ldb_cnt <= addr_ldb_num-1)))
        mem_rd_pre <= 1'b1;
    else
        mem_rd_pre <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        src_rdata_vld <= 1'b0;
    else if(mem_src_rd)
        src_rdata_vld <= 1'b1;
    else
        src_rdata_vld <= 1'b0;
end

logic xy_flag;
logic xy_flag_d1;
logic xy_flag_d2;
logic [DATA_WD-1:0] rdata_aligned;
logic [DATA_WD-1:0] rdata_t1;
logic [OFFSET-1:0] addr_offset_d1;
logic [OFFSET-1:0] addr_offset_d2;
logic [OFFSET-1:0] rdata_offset;
logic [15:0] ldb_cnt_d1;
logic [15:0] ldb_cnt_d2;
logic need_t2_d1;
logic need_t2_d2;
logic fetch_cnt_d1;
logic fetch_cnt_d2;
logic rdata_need_t2;
logic rdata_fetch_cnt;
logic first_ldb_loop_d1;
logic first_ldb_loop_d2;

//assign addr_offset = pixel_index_p[OFFSET-1:0];
assign rdata_offset = addr_offset_d2;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        {addr_offset_d1,addr_offset_d2} <= 'd0;
    else if(pixshff_on)
        {addr_offset_d1,addr_offset_d2} <= {pixel_index_p[OFFSET-1:0], addr_offset_d1};
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        xy_flag <= 1'b0;
    else if(pixshff_start || pixshff_done)
        xy_flag <= 1'b0;
    else if(pixshff_on && ldb_end)
        xy_flag <= ~xy_flag;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        {xy_flag_d2, xy_flag_d1} <= 'd0;
    else if(pixshff_on)
        {xy_flag_d2, xy_flag_d1} <= {xy_flag_d1, xy_flag};
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        {ldb_cnt_d2, ldb_cnt_d1} <= 'd0;
    else if(pixshff_on)
        {ldb_cnt_d2, ldb_cnt_d1} <= {ldb_cnt_d1, ldb_cnt};
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        {first_ldb_loop_d1,first_ldb_loop_d2} <= 'd0;
    else
        {first_ldb_loop_d1,first_ldb_loop_d2} <= {first_ldb_loop, first_ldb_loop_d1};
end

assign rdata_need_t2 = need_t2_d2;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        {need_t2_d2, need_t2_d1} <= 'd0;
    else if(pixshff_on)
        {need_t2_d2, need_t2_d1} <= {need_t2_d1, need_t2};
end

assign rdata_fetch_cnt = fetch_cnt_d2;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        {fetch_cnt_d2, fetch_cnt_d1} <= 'd0;
    else if(pixshff_on)
        {fetch_cnt_d2, fetch_cnt_d1} <= {fetch_cnt_d1, fetch_cnt};
end


always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        rdata_t1 <= 'd0;
    else if(pixshff_on && src_rdata_vld && rdata_need_t2 && ~rdata_fetch_cnt)
        rdata_t1 <= mem_src_rdata;
end
//assign rdata_aligned = {mem_src_rdata[DATA_WD-1:8*addr_offset],rdata_t1[8*addr_offset-1:0]};

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

logic [DATA_WB-1:0] BUFF_ARRAY [ARR_H-1:0][ARR_W-1:0];
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

logic data_out_vld_pre;
logic [3:0] data_out_cnt;
assign last_data_out_loop = pixshff_on && ~pixshff_rd_on && ~out_batch_end && ~pixshff_done;
assign data_out_vld_pre =  (fetch_vld && ~(first_ldb_loop || first_ldb_loop_d2) && ~out_batch_end && ~pixshff_done) && (data_out_cnt < rf_pow2);    // todo with last ldb loop

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_out_cnt <= 'd0;
    else if(pixshff_start || pixshff_done)
        data_out_cnt <= 'd0;
    else if((ldb_cnt_d2 == ldb_num-1) && (data_out_cnt >= rf_pow2))
        data_out_cnt <= 'd0;
    else if(data_out_vld_pre) begin 
        data_out_cnt <= (data_out_cnt >= rf_pow2)?     data_out_cnt : data_out_cnt+1;
    end
end
// todo parameter
logic [DATA_WD-1:0] data_out;
logic [3:0] buff_index_l;
logic [3:0] buff_index_h;
assign buff_index_l = ldb_cnt_d2;
assign buff_index_h = ldb_cnt_d2 + (DATA_WB >> 1);
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_out <= 'd0;
    else if(data_out_vld_pre) begin   // todo not first loop
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

assign out_rx_end = mem_dest_wr && (out_rx_cnt == rg_rfactor-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        out_rx_cnt <= 'd0;
    else if(pixshff_start || pixshff_done)
        out_rx_cnt <= 'd0;
    else if(mem_dest_wr)
        out_rx_cnt <= out_rx_end?   'd0 : out_rx_cnt + 1'b1;
end

assign out_ry_end = out_rx_end && (out_ry_cnt == rg_rfactor-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        out_ry_cnt <= 'd0;
    else if(pixshff_start || pixshff_done)
        out_ry_cnt <= 'd0;
    else if(out_rx_end)
        out_ry_cnt <= out_ry_end?   'd0 : out_ry_cnt + 1'b1;
end

assign out_c_end = out_rx_end && out_ry_end && (out_c_cnt == ldc_num-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        out_c_cnt <= 'd0;
    else if(pixshff_start || pixshff_done)
        out_c_cnt <= 'd0;
    else if(out_rx_end && out_ry_end)
        out_c_cnt <= out_c_end?   'd0 : out_c_cnt + 1'b1;
end

assign out_w_end = out_c_end && (out_w_cnt == rg_inw-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        out_w_cnt <= 'd0;
    else if(pixshff_start || pixshff_done)
        out_w_cnt <= 'd0;
    else if(out_c_end)
        out_w_cnt <= out_w_end?   'd0 : out_w_cnt + 1'b1;
end

assign out_h_end = out_w_end && (out_h_cnt == rg_inh-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        out_h_cnt <= 'd0;
    else if(pixshff_start || pixshff_done)
        out_h_cnt <= 'd0;
    else if(out_w_end)
        out_h_cnt <= out_h_end?   'd0 : out_h_cnt + 1'b1;
end

assign out_frame_end = out_w_end && out_h_end;

assign out_batch_end = out_frame_end && (out_batch_cnt == rg_batch-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        out_batch_cnt <= 'd0;
    else if(pixshff_start || pixshff_done)
        out_batch_cnt <= 'd0;
    else if(out_frame_end)
        out_batch_cnt <= out_batch_end?   'd0 : out_batch_cnt + 1'b1;
end

logic [ADDR_WD-1:0] mem_addr_r_head;
logic [ADDR_WD-1:0] mem_addr_c_head;

always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        mem_addr_r_head <= 'd0;
    else if(pixshff_start || pixshff_done)
        mem_addr_r_head <= rg_dest_base;
    else if(out_w_end)
        mem_addr_r_head <= mem_dest_addr + 1;
    else if(out_c_end)
        mem_addr_r_head <= mem_addr_r_head + rg_rfactor * ldc_num;  // todo pre caculate
end

always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        mem_addr_c_head <= 'd0;
    else if(pixshff_start || pixshff_done)
        mem_addr_c_head <= rg_dest_base;
    else if(out_w_end)
        mem_addr_c_head <= mem_dest_addr + 1;
    else if(out_c_end)
        mem_addr_c_head <= mem_addr_r_head + rg_rfactor * ldc_num;  // todo pre caculate
    else if(out_rx_end && out_ry_end)
        mem_addr_c_head <= mem_addr_r_head + 1;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem_dest_addr <= 'd0;
    else if(pixshff_start || pixshff_done)
        mem_dest_addr <= rg_dest_base;
    else begin
        if(out_w_end)
            mem_dest_addr <= mem_dest_addr + 1;
        else if(out_c_end)
            mem_dest_addr <= mem_addr_r_head + rg_rfactor * ldc_num;
        else if(out_rx_end && out_ry_end)
            mem_dest_addr <= mem_addr_r_head + 1;
        else if(out_rx_end)
            mem_dest_addr <= mem_addr_c_head + rg_outw * ldc_num * (out_ry_cnt+1);   // todo simplify
        else if(mem_dest_wr)
            mem_dest_addr <= mem_dest_addr + ldc_num;
    end
end

logic [ARR_OFFSET-1:0] wmask_offset;
assign wmask_offset = rg_outc[ARR_OFFSET-1:0];

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem_dest_wmask <= {DATA_WD{1'b1}};
    else if(ldc_num == 1)
        mem_dest_wmask <= {{(DATA_WB-wmask_offset){1'b0}},{wmask_offset{1'b1}}} ;
    else if(out_rx_end && out_ry_end) begin
        if(out_c_cnt == ldc_num-2)
            mem_dest_wmask <= {{(DATA_WB-wmask_offset){1'b0}},{wmask_offset{1'b1}}} ;
        else
            mem_dest_wmask <= {DATA_WD{1'b1}};
    end
end

endmodule