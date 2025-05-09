`timescale 1ns/1ps
module conv_cal_tb();

`define CLK_PERIOD 10


logic               clk                     ;
logic               rstn                    ;
logic        [9:0]  in_width                ;
logic        [9:0]  in_height               ;
logic        [2:0]  stride                  ;
logic        [1:0]  padding                 ;
logic               conv_cal_enable         ;
logic signed [7:0]  weight [0:8];
logic signed [7:0]  data                    ;
logic               data_in_vld             ;
logic signed [19:0] conv_out                ;
logic               conv_out_vld            ;
logic               fetch_data              ;

/**************** simulation init *************/
always #(`CLK_PERIOD/2) clk = ~clk;

initial begin
    clk = 1'b0;
    rstn = 1'b0;
    in_width    = 5;
    in_height   = 5;
    stride      = 1;
    padding     = 1;
    conv_cal_enable = 0;
    #(3.3*`CLK_PERIOD)
    rstn = 1'b1;
    in_width    = 5;
    in_height   = 5;
    stride      = 1;
    padding     = 1;
    #30
    @(negedge clk);
    conv_cal_enable = 1;
    #2000    // 仿真时长
    $finish(2);
end

always@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        data_in_vld <= 1'b0;
        data <= 'sd0;
        weight[0] <= 1;
        weight[1] <= 1;
        weight[2] <= 1;
        weight[3] <= 1;
        weight[4] <= 1;
        weight[5] <= 1;
        weight[6] <= 1;
        weight[7] <= 1;
        weight[8] <= 1;
    end
    else if(conv_cal_enable && fetch_data) begin
       data_in_vld <= 1'b1;
       data <= {$random}%10; 
    end
    else begin
        data_in_vld <= 1'b0;
    end
end


/****************** fsdb configuration ********************/
initial begin
    $fsdbDumpfile("conv_cal_tb.fsdb");
    $fsdbDumpvars();
    $fsdbDumpSVA();
    $fsdbDumpMDA();
end

/******************* module instantiation *******************/
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
    .weight          (weight [0:8]    ),  // from weight buffer
    .data            (data            ),  // from input fifo
    .data_in_vld     (data_in_vld     ),  // from input fifo
    .conv_out        (conv_out        ),  // to output fifo
    .conv_out_vld    (conv_out_vld    ),  // to output fifo
    .fetch_data      (fetch_data      )            // to input fifo
);



endmodule