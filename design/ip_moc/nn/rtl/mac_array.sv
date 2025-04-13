module mac_array #(
    parameter ROW_NUM    = 32    ,
    parameter COL_NUM    = 32    ,
    parameter MAX_SP_LEN = 40    ,
    parameter IN_WD      = 32*8  ,
    parameter WGT_WD     = 32*8  ,
    parameter MAX_WD     = 32    ,
    parameter OUT_WD     = 12
)(
    input                                   clk                         ,
    input                                   rstn                        ,
    input [IN_WD-1:0]                       data_in                     ,
    input                                   data_in_vld                 ,
    input [IN_WD-1:0]                       data_in_mask                ,
    input [3:0]                             data_type                   ,   // [3]: i/u, [1:0] :8,16,32
    input [WGT_WD-1:0]                      wgt_in                      ,
    input                                   wgt_in_vld                  ,
    input                                   wgt_in_flag                 ,   // 0: RWA, 1: RWB
    input [WGT_WD-1:0]                      wgt_in_mask                 ,
    input [3:0]                             wgt_type                    ,
    input [ROW_NUM-1:0]                     row_mask                    , 
    input                                   pingpong_flag               ,   // 0: A, 1: B
    input [5:0]                             strip_len                   ,    // proposed more than COL_NUM
    input [6:0]                             kernel_size                 ,   // RXS
    input [6:0]                             chn_slice_num               ,   // ≈ chn / ROW_NUM
    output logic signed [OUT_WD-1:0]        data_out [0:COL_NUM-1]      ,   // todo: consider BW, maybe push into fifo
    output logic                            data_out_vld
);

logic [COL_NUM-1:0] wgt_in_en_seq;
logic [OUT_WD-1:0] mac_out_temp [0:COL_NUM-1];
logic mac_out_temp_vld [0:COL_NUM-1];
logic signed [OUT_WD-1:0] buffer [0:MAX_SP_LEN-1] [0:COL_NUM-1];
logic [6:0] k_cnt;
logic [6:0] sp_cnt;
logic [6:0] chn_cnt;
logic one_strip_end;
logic one_chn_slice_end;
logic one_accsum_end;
logic one_accsum_vld;
logic one_accsum_vld_d1;


// update weight //
assign wgt_in_vld_seq = {COL_NUM{wgt_in_vld}} & wgt_in_en_seq;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        wgt_in_en_seq <= 'd1;
    else if(wgt_in_vld)
        wgt_in_en_seq <= {wgt_in_en_seq[COL_NUM-2:0],wgt_in_en_seq[COL_NUM-1]};
end
// acc_sum control //
assign one_strip_end = (sp_cnt == strip_len-1) && (&mac_out_temp_vld);
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        sp_cnt <= 'd0;
    else if(&mac_out_temp_vld)  // todo: 都是同时的，只给一个就行
        sp_cnt <= one_strip_end?  'd0 : sp_cnt+1'b1;
end

assign one_chn_slice_end = (k_cnt == kernel_size-1) && one_strip_end;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        chn_cnt <= 'd0;
    else if(one_strip_end)
        chn_cnt <= one_chn_slice_end?  'd0 : chn_cnt+1'b1;
end

assign one_accsum_end = (chn_cnt == chn_slice_num-1) && one_chn_slice_end;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        k_cnt <= 'd0;
    else if(one_chn_slice_end)
        k_cnt <= one_accsum_end?  'd0 : k_cnt+1'b1;
end

assign one_accsum_vld = (&mac_out_temp_vld) && (k_cnt == kernel_size-1);

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        {one_accsum_vld_d1, data_out_vld} <= 2'b0;
    else
        {one_accsum_vld_d1, data_out_vld} <= {one_accsum_vld, one_accsum_vld_d1};
end

genvar i;
generate
    for(i=0;i<COL_NUM;i=i+1) begin : COL_ARRAY
        mac_col #(
            .ROW_NUM( ROW_NUM ),
            .IN_WD  ( IN_WD   ),
            .WGT_WD ( WGT_WD  ),
            .MAX_WD ( MAX_WD  ),
            .OUT_WD ( OUT_WD  )
        ) mac_col_inst(
            .clk           ( clk                ),
            .rstn          ( rstn               ),
            .data_in       ( data_in            ),
            .data_in_vld   ( data_in_vld        ),
            .data_in_mask  ( data_in_mask       ),
            .data_type     ( data_type          ),
            .wgt_in        ( wgt_in             ),
            .wgt_in_vld    ( wgt_in_vld_seq[i]  ),
            .wgt_in_flag   ( wgt_in_flag        ),
            .wgt_in_mask   ( wgt_in_mask        ),
            .wgt_type      ( wgt_type           ),
            .row_mask      ( row_mask           ),
            .pingpong_flag ( pingpong_flag      ),
            .data_out      ( mac_out_temp[i]    ),
            .data_out_vld  ( mac_out_temp_vld[i])
        );
    end

    integer j;
    always_ff@(posedge clk or negedge rstn) begin
        if(~rstn) begin
            for(j=0;j<MAX_SP_LEN;j=j+1)
                buffer[j][i] <= 'sd0;
        end
        else if(mac_out_temp_vld[i]) begin
            if(k_cnt == 0)
                buffer[sp_cnt][i] <= mac_out_temp[i];
            else 
                buffer[sp_cnt][i] <= mac_out_temp[i] + buffer[sp_cnt][i];   // todo replaced by ADDER
        end
    end

    always_ff@(posedge clk or negedge rstn) begin
        if(~rstn)
            data_out[i] <= 'sd0;
        else if(one_accsum_vld_d1)
            data_out[i] <= buffer[sp_cnt][i];
    end

endgenerate

endmodule