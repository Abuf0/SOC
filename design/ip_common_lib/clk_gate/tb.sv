`timescale 1ns/1ps
module tb();

/***************** defines ***************************/
`define ASSERT_ON
`define FPGA
`define USE_ICG
`define CLK_PERIOD 10
`define CLK_DST_PERIOD 25

/****************** variable **************************/
parameter DIV_WID = 4;
parameter PULSE_NUM = 4;
logic clk;
logic rstn;
logic counter_enable = 1'b0;
logic in_valid = 1'b0; 
logic signed [7:0] A_in      = 'sd0;
logic signed [7:0] B_in      = 'sd0;
logic signed [14:0] mul_out;
logic out_valid;
logic signed [14:0] mul_out_nonvld;
logic rg_mpx_en = 1'b0;
logic [1:0] rg_mpx_sel = 2'd0;                   
logic [DIV_WID-1:0] div_dat_even = 4;
logic mpx_in = 0;        
logic mpx_out;
logic clk_dst ;      
logic rstn_dst;      
logic [PULSE_NUM-1:0] pulse_async_in = 0;
logic [PULSE_NUM-1:0] pulse_sync_out;

/**************** simulation init *************/
always #(`CLK_PERIOD/2) clk = ~clk;

initial begin
    clk = 1'b0;
    rstn = 1'b0;
    rstn_dst = 1'b0;
    #(3.3*`CLK_PERIOD)
    rstn = 1'b1;
    rstn_dst = 1'b1;
    #2000    // 仿真时长
    $finish(2);
end

initial begin
    clk_dst = 1'b0;
    #(0.3*`CLK_PERIOD)
    forever #(`CLK_DST_PERIOD/2) clk_dst = ~clk_dst;
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

// mpx_hgt //
logic [2:0] seq = 0;
initial begin
    repeat(20) begin @(negedge clk); end
    repeat(5) begin @(negedge clk); end
    rg_mpx_en = 1'b1;
    repeat(20) begin @(negedge clk); end
    rg_mpx_sel = 2'b0;
    repeat(20) begin @(negedge clk); end
    rg_mpx_sel = 2'd1;
    repeat(20) begin @(negedge clk); end
    rg_mpx_sel = 2'd2;
    repeat(20) begin 
        @(negedge clk); 
        seq = $random;
        mpx_in = (seq == 3);
    end
    repeat(20) begin @(negedge clk); end
    rg_mpx_sel = 2'd1;
    div_dat_even = 4'd12;
    repeat(100) begin @(negedge clk); end
end


// lp_pulse_sync //
initial begin
    repeat(20) begin @(negedge clk); end
    repeat(5) begin @(negedge clk); end
    repeat(10) begin
        pulse_async_in = $random;
        @(negedge clk);
        pulse_async_in = 0;
        repeat(10) begin @(negedge clk); end
    end
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

mpx_hgt #( .DIV_WID(DIV_WID) ) mpx_hgt_inst(
    .rg_mpx_en    (rg_mpx_en    ),
    .rg_mpx_sel   (rg_mpx_sel   ),
    .clk          (clk          ),
    .rstn         (rstn         ),
    .scan_en      (0            ),
    .div_dat_even (div_dat_even ),
    .mpx_in       (mpx_in       ),
    .mpx_out      (mpx_out      )   
);

lp_pulse_sync #( .NUM(PULSE_NUM) ) lp_pulse_sync_inst(
    .clk_src        (clk            ),
    .rstn_src       (rstn           ),
    .clk_dst        (clk_dst        ),
    .rstn_dst       (rstn_dst       ),
    .scan_en        (0              ),
    .pulse_async_in (pulse_async_in ),
    .pulse_sync_out (pulse_sync_out )      
);


endmodule