`timescale 1ns/1ps
module tb();

/***************** defines ***************************/
`define ASSERT_ON
`define FPGA
`define USE_ICG
`define CLK_PERIOD 10

/****************** variable **************************/
logic clk;
logic rstn;
logic fsm_start_trig = 0;
logic din_vld = 1'b0; 
logic signed [7:0] mula      = 'sd0;
logic signed [7:0] mulb      = 'sd0;
logic signed [14:0] mul_out;
logic mul_out_vld;

/**************** simulation init *************/
always #(`CLK_PERIOD/2) clk = ~clk;

initial begin
    clk = 1'b0;
    rstn = 1'b0;
    #(3.3*`CLK_PERIOD)
    rstn = 1'b1;
    #5000    // 仿真时长
    $finish(2);
end

/************** test case *********************/
initial begin
    repeat(100) begin @(negedge clk); end
    fsm_start_trig = 1;
    @(negedge clk);
    fsm_start_trig = 0;
    repeat(10) begin @(negedge clk); end
    repeat(10) begin
        din_vld = 1'b1;
        mula = $random;
        mulb = $random;
        @(negedge clk);
    end
    din_vld = 1'b0;

    repeat(110) begin @(negedge clk); end
    repeat(200) begin
        din_vld = $random;
        mula = $random;
        mulb = $random;
        @(negedge clk);
    end
    din_vld = 1'b0;
    repeat(10) begin @(negedge clk); end
    repeat(10) begin
        din_vld = 1'b1;
        mula = $random;
        mulb = $random;
        @(negedge clk);
    end
    din_vld = 1'b0;
    repeat(10) begin @(negedge clk); end
end


/****************** fsdb configuration ********************/
initial begin
    $fsdbDumpfile("tb.fsdb");
    $fsdbDumpvars();
    $fsdbDumpSVA();
end

/******************* module instantiation *******************/
fsm_e1 fsm_e1_inst(
    .clk            (clk            ), 
    .rstn           (rstn           ),
    .scan_en        (0              ),
    .fsm_start_trig (fsm_start_trig ),
    .mula           (mula           ),
    .mulb           (mulb           ),
    .din_vld        (din_vld        ),
    .mul_out        (mul_out        ),
    .mul_out_vld    (mul_out_vld    )   
);



endmodule
