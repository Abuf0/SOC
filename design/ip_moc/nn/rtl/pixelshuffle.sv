module pixelshuffle #(
    parameter DATA_WB = 4           ,
    parameter DATA_WD = DATA_WB * 8 ,
    parameter ADDR_WD = 16
)(
    input                       clk             ,
    input                       rstn            ,
    /* config */
    input [ADDR_WD-1:0]         rg_src_base     ,
    input [ADDR_WD-1:0]         rg_dest_base    ,
    input [1:0]                 rg_rfactor      ,
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
logic pixshff_on;
logic [15:0] p_cnt;
logic [15:0] h_cnt;
logic [15:0] w_cnt;
logic [2:0] rx_cnt;
logic [2:0] ry_cnt; 
logic [15:0] batch_cnt;

logic rx_end;
logic ry_end;
logic p_end;
logic c_end;
logic w_end;
logic h_end;
logic frame_end;
logic batch_end;

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
        pixshff_done <= 1'b0;
    else if(pixshff_on && batch_end)
        pixshff_done <= 1'b1;
    else
        pixshff_done <= 1'b0;
end

assign p_end = (p_cnt + rg_rfactor > rg_inc-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        p_cnt <= 'd0;
    else if(pixshff_start || pixshff_done)
        p_cnt <= 'd0;
    else if(pixshff_on)
        p_cnt <= p_end?   'd0 : p_cnt + 1'b1;
end

assign rx_end = p_end && (rx_cnt == rg_rfactor-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        rx_cnt <= 'd0;
    else if(pixshff_start || pixshff_done)
        rx_cnt <= 'd0;
    else if(pixshff_on && p_end)
        rx_cnt <= rx_end?   'd0 : rx_cnt + 1'b1;
end

assign ry_end = rx_end && (ry_cnt == rg_rfactor-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        ry_cnt <= 'd0;
    else if(pixshff_start || pixshff_done)
        ry_cnt <= 'd0;
    else if(pixshff_on && rx_end)
        ry_cnt <= ry_end?   'd0 : ry_cnt + 1'b1;
end

assign c_end = p_end && rx_end && ry_end;

assign w_end = c_end && (w_cnt == rg_inw-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        w_cnt <= 'd0;
    else if(pixshff_start || pixshff_done)
        w_cnt <= 'd0;
    else if(pixshff_on && c_end)
        w_cnt <= w_end?   'd0 : w_cnt + 1'b1;
end

assign h_end = w_end && (h_cnt == rg_inh-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        h_cnt <= 'd0;
    else if(pixshff_start || pixshff_done)
        h_cnt <= 'd0;
    else if(pixshff_on && w_end)
        h_cnt <= h_end?   'd0 : h_cnt + 1'b1;
end

assign frame_end = w_end && h_end;

assign batch_end = frame_end && (batch_cnt == rg_batch-1);
always_ff @(posedge clk or negedge rstn) begin
    if(~rstn)
        batch_cnt <= 'd0;
    else if(pixshff_start || pixshff_done)
        batch_cnt <= 'd0;
    else if(pixshff_on && frame_end)
        batch_cnt <= batch_end?   'd0 : batch_cnt + 1'b1;
end

logic [ADDR_WD-1:0] pixel_index_c_head;
logic [ADDR_WD-1:0] pixel_index_p;

logic [ADDR_WD-1:0] pixel_index_next;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem_src_addr <= 'd0;
    else if(pixshff_start)
        mem_src_addr <= rg_src_base;
    else if(pixshff_on) 
        mem_src_addr <= rg_src_base + pixel_index_p[ADDR_WD-1:OFFSET];
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        pixel_index_c_head <= 'd0;
    else if(pixshff_start)
        pixel_index_c_head <= rg_src_base;
    else if(pixshff_on && c_end) 
        pixel_index_c_head <= pixel_index_c_head + rg_inc;
end

// todo with combination logic //
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        pixel_index_p <= 'd0;
    else if(pixshff_start)
        pixel_index_p <= rg_src_base;
    else if(pixshff_on) begin
        if(c_end)
            pixel_index_p <= pixel_index_c_head + rg_inc;
        else if(p_end)
            pixel_index_p <= pixel_index_c_head + ry_cnt * rg_rfactor + rx_cnt;    // todo with add rxy_cnt
        else 
            pixel_index_p <= pixel_index_p + rg_rfactor * rg_rfactor; // todo pre provide r*r
    end
end

endmodule