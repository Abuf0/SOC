module pe_unit#(
    parameter KSIZE     = 3         ,
    parameter IN_WMAX   = 7         ,
    parameter IN_FIFO_DEEPTH = 64   ,
    parameter OUT_FIFO_DEEPTH = 64
)(
    input                           clk                      ,
    input                           rstn                     ,
    input [9:0]                     in_width                 ,  // 不包含pad
    input [9:0]                     in_height                ,  // 不包含pad
    input [2:0]                     stride                   ,
    input [1:0]                     padding                  ,
    input                           pe_enable                ,  // 需要保证enable之前config ready
    /* weight buffer interface*/
    input                           wbuff_wr                 ,
    input [$clog2(KSIZE*KSIZE)-1:0] wbuff_waddr              ,
    input [7:0]                     wbuff_wdata              ,
    /* IFIFO interface*/
    input                           ififo_wr                 ,
    input [19:0]                    ififo_wdata              ,
    output logic [$clog2(IN_FIFO_DEEPTH)-1:0] ififo_used     ,
    output logic                    ififo_ov_flag            ,
    /* OFIFO interface*/
    input                           ofifo_rd                 ,
    output logic [19:0]             ofifo_rdata              ,
    output logic                    ofifo_rdata_vld          ,
    output logic [$clog2(OUT_FIFO_DEEPTH)-1:0] ofifo_used    ,
    output logic                    ofifo_ov_flag
);

logic               conv_cal_enable         ;
logic signed [7:0]  weight [0:KSIZE*KSIZE-1];
logic [7:0]         ififo_rdata             ;
logic signed [7:0]  data                    ;
logic               data_in_vld             ;
logic signed [19:0] conv_out                ;
logic               conv_out_vld            ;
logic               fetch_data              ;

assign conv_cal_enable = pe_enable; 

integer i;
always@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        for(i=0;i<KSIZE*KSIZE;i=i+1) begin
            weight[i] <= 'sd0;
        end
    end
    else if(wbuff_wr) begin
        weight[wbuff_waddr] <= $signed(wbuff_wdata);
    end
end

sync_fifo#(
    .DW    (20              ),
    .DEEPTH(IN_FIFO_DEEPTH  )
) ififo_inst (
    .clk           (clk           ),
    .rstn          (rstn          ),
    .wr            (ififo_wr      ),
    .wdata         (ififo_wdata   ),
    .rd            (fetch_data    ),
    .rdata         (ififo_rdata   ),
    .rdata_vld     (data_in_vld   ),
    .fifo_used     (ififo_used    ),
    .fifo_ov_flag  (ififo_ov_flag )  
);

assign data = $signed(ififo_rdata);

conv_cal_unit#(
    .KSIZE  (3  ),
    .IN_WMAX(8)       // include padding
) conv_cal_unit_inst(
    .clk             (clk             ),
    .rstn            (rstn            ),
    .in_width        (in_width        ),  // 不包含pad
    .in_height       (in_height       ),  // 不包含pad
    .stride          (stride          ),
    .padding         (padding         ),
    .conv_cal_enable (conv_cal_enable ),  // 需要保证enable之前config ready
    .weight          (weight [0:KSIZE*KSIZE-1]    ),  // from weight buffer
    .data            (data            ),  // from input fifo
    .data_in_vld     (data_in_vld     ),  // from input fifo
    .conv_out        (conv_out        ),  // to output fifo
    .conv_out_vld    (conv_out_vld    ),  // to output fifo
    .fetch_data      (fetch_data      )            // to input fifo
);

sync_fifo#(
    .DW    (20               ),
    .DEEPTH(OUT_FIFO_DEEPTH  )
) ofifo_inst (
    .clk           (clk                 ),
    .rstn          (rstn                ),
    .wr            (conv_out_vld        ),
    .wdata         (conv_out            ),
    .rd            (ofifo_rd            ),
    .rdata         (ofifo_rdata         ),
    .rdata_vld     (ofifo_rdata_vld     ),
    .fifo_used     (ofifo_used          ),
    .fifo_ov_flag  (ofifo_ov_flag       )  
);

endmodule