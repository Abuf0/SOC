`timescale 1ns/10ps
module tb();

/***************** defines ***************************/
`define ASSERT_ON
`define FPGA
`define USE_ICG
`define CLK_PERIOD 10

/****************** variable **************************/
logic clk;
logic rstn;
logic counter_enable = 1'b0;
logic in_valid = 1'b0; 
logic signed [7:0] A_in      = 'sd0;
logic signed [7:0] B_in      = 'sd0;
logic signed [14:0] mul_out;
logic out_valid;
logic signed [14:0] mul_out_nonvld;

/**************** simulation init *************/
always #(`CLK_PERIOD/2) clk = ~clk;
initial begin
    clk = 1'b0;
    rstn = 1'b0;
    #(3.3*`CLK_PERIOD)
    rstn = 1'b1;
    #200    // 仿真时长
    $finish(2);
end
/************** test case *********************/
// counter_level_clr_1 //
initial begin
    repeat(20) begin @(negedge clk); end
    repeat(5) begin @(negedge clk); end
    counter_enable = 1'b1;
    repeat(225) begin @(negedge clk); end
    counter_enable = 1'b0;
    repeat(15) begin @(negedge clk); end    
    counter_enable = 1'b1;
    repeat(395) begin @(negedge clk); end
    counter_enable = 1'b0;
    repeat(25) begin @(negedge clk); end
    counter_enable = 1'b1;
    repeat(115) begin @(negedge clk); end
    counter_enable = 1'b0;
end

// mul_unit, mul_unit_nonvld //
initial begin
    repeat(20) begin @(negedge clk); end
    repeat(10) begin
        in_valid = 1'b1;
        A_in = $random;
        B_in = $random;
        @(negedge clk);
    end
    in_valid = 1'b0;
    repeat(10) begin @(negedge clk); end
    repeat(1) begin
        in_valid = 1'b1;
        A_in = $random;
        B_in = $random;
        @(negedge clk);
    end
    in_valid = 1'b0;
    repeat(10) begin @(negedge clk); end
end

/****************** fsdb configuration ********************/
initial begin
    $fsdbDumpfile("tb.fsdb");
    $fsdbDumpvars();
    $fsdbDumpSVA();
end

/******************* module instantiation *******************/
counter_level_clr_1 counter_level_clr_1_inst(
    .clk            (clk            ),
    .rstn           (rstn           ),
    .scan_en        (0              ),
    .enable         (counter_enable ),
    .counter_out    (counter_out_1  )
);

mul_unit mul_unit_inst(
    .clk       (clk             ),
    .rstn      (rstn            ),
    .scan_en   (0               ),
    .in_valid  (in_valid        ),
    .A_in      (A_in            ),
    .B_in      (B_in            ),
    .mul_out   (mul_out         ),
    .out_valid (out_valid       )
);

mul_unit_nonvld mul_unit_nonvld_inst(
    .clk       (clk             ),
    .rstn      (rstn            ),
    .scan_en   (0               ),
    .enable    (in_valid        ),
    .A_in      (A_in            ),
    .B_in      (B_in            ),
    .mul_out   (mul_out_nonvld  )
);

endmodule