`timescale 1ns/1ps
module pe_cal_tb();

`define CLK_PERIOD 10

parameter KSIZE = 3;
parameter IN_FIFO_DEEPTH = 64;
parameter OUT_FIFO_DEEPTH = 64;
parameter IN_WMAX = 8;

logic               clk                     ;
logic               rstn                    ;
logic        [9:0]  in_width                ;
logic        [9:0]  in_height               ;
logic        [2:0]  stride                  ;
logic        [1:0]  padding                 ;
logic               pe_enable               ;
logic               wbuff_wr                ;
logic [$clog2(KSIZE*KSIZE)-1:0]  wbuff_waddr             ;
logic [19:0]                     wbuff_wdata             ;
logic                            ififo_wr                ;
logic [19:0]                     ififo_wdata             ;
logic [$clog2(IN_FIFO_DEEPTH)-1:0]              ififo_used              ;
logic                            ififo_ov_flag           ;
logic                            ofifo_rd                ;
logic [19:0]                     ofifo_rdata             ;
logic                            ofifo_rdata_vld         ;
logic [$clog2(OUT_FIFO_DEEPTH)-1:0]              ofifo_used              ;
logic                            ofifo_ov_flag           ;

/**************** simulation init *************/
always #(`CLK_PERIOD/2) clk = ~clk;

initial begin
    clk = 1'b0;
    rstn = 1'b0;
    in_width    = 5;
    in_height   = 5;
    stride      = 1;
    padding     = 1;
    pe_enable = 0;
    wbuff_wr = 0;
    wbuff_waddr = 0 ;
    wbuff_wdata = 0 ;
    ififo_wr     = 0; 
    ififo_wdata  = 0; 
    ofifo_rd = 0;
    #(3.3*`CLK_PERIOD)
    rstn = 1'b1;
    in_width    = 5;
    in_height   = 5;
    stride      = 1;
    padding     = 1;
    @(negedge clk);
    wbuff_wr = 1;
    wbuff_waddr = 0;
    wbuff_wdata = 1;
    @(negedge clk);
    wbuff_waddr = 1;
    wbuff_wdata = 1;
    @(negedge clk);
    wbuff_waddr = 2;
    wbuff_wdata = 1;
    @(negedge clk);
    wbuff_waddr = 3;
    wbuff_wdata = 1;
    @(negedge clk);
    wbuff_waddr = 4;
    wbuff_wdata = 1;
    @(negedge clk);
    wbuff_waddr = 5;
    wbuff_wdata = 1;
    @(negedge clk);
    wbuff_waddr = 6;
    wbuff_wdata = 1;
    @(negedge clk);
    wbuff_waddr = 7;
    wbuff_wdata = 1;
    @(negedge clk);
    wbuff_waddr = 8;
    wbuff_wdata = 1;
    @(negedge clk);
    wbuff_wr = 0;

    @(negedge clk);
    ififo_wr    = 1;
    ififo_wdata = 1;
    @(negedge clk);
    ififo_wdata = 2;
    @(negedge clk);
    ififo_wdata = 3;
    @(negedge clk);
    ififo_wdata = 4;
    @(negedge clk);
    ififo_wdata = 5;
    @(negedge clk);
    ififo_wdata = 6;
    @(negedge clk);
    ififo_wdata = 7;
    @(negedge clk);
    ififo_wdata = 8;
    @(negedge clk);
    ififo_wdata = 9;
    @(negedge clk);
    ififo_wdata = 10;
    @(negedge clk);
    ififo_wdata = 11;
    @(negedge clk);
    ififo_wdata = 12;
    @(negedge clk);
    ififo_wdata = 13;
    @(negedge clk);
    ififo_wdata = 14;
    @(negedge clk);
    ififo_wdata = 15;
    @(negedge clk);
    ififo_wdata = 16;
    @(negedge clk);
    ififo_wdata = 17;
    @(negedge clk);
    ififo_wdata = 18;
    @(negedge clk);
    ififo_wdata = 19;
    @(negedge clk);
    ififo_wdata = 20;
    @(negedge clk);
    ififo_wr = 0;

    #30
    @(negedge clk);
    pe_enable = 1;
    #2000    // 仿真时长
    $finish(2);
end

//initial begin
//    $readmemh("./input_data.txt",pe_unit_inst.ififo_inst.buffer);
//end

/****************** fsdb configuration ********************/
initial begin
    $fsdbDumpfile("pe_cal_tb.fsdb");
    $fsdbDumpvars();
    $fsdbDumpSVA();
    $fsdbDumpMDA();
end

/******************* module instantiation *******************/
pe_unit#(
    .KSIZE           (KSIZE          ),
    .IN_WMAX         (IN_WMAX        ),
    .IN_FIFO_DEEPTH  (IN_FIFO_DEEPTH ),
    .OUT_FIFO_DEEPTH (OUT_FIFO_DEEPTH)       
) pe_unit_inst(
    .clk            (clk            ),
    .rstn           (rstn           ),
    .in_width       (in_width       ),  // 不包含pad
    .in_height      (in_height      ),  // 不包含pad
    .stride         (stride         ),
    .padding        (padding        ),
    .pe_enable      (pe_enable      ),  // 需要保证enable之前config ready
    .wbuff_wr       (wbuff_wr       ),
    .wbuff_waddr    (wbuff_waddr    ),
    .wbuff_wdata    (wbuff_wdata    ),
    .ififo_wr       (ififo_wr       ),
    .ififo_wdata    (ififo_wdata    ),
    .ififo_used     (ififo_used     ),
    .ififo_ov_flag  (ififo_ov_flag  ),
    .ofifo_rd       (ofifo_rd       ),
    .ofifo_rdata    (ofifo_rdata    ),
    .ofifo_rdata_vld(ofifo_rdata_vld),
    .ofifo_used     (ofifo_used     ),
    .ofifo_ov_flag  (ofifo_ov_flag  )    
);

endmodule