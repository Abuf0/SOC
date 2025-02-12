module fsm_e1(
    input               clk             , 
    input               rstn            ,
    input               scan_en         ,
    input               fsm_start_trig  ,
    input [7:0]         mula            ,
    input [7:0]         mulb            ,
    input               din_vld         ,
    output logic [14:0] mul_out         ,
    output logic        mul_out_vld
);

logic counter_hit;
logic mult_done;
logic [6:0] counter;
logic [3:0] mult_cnt;

// FSM //
typedef enum logic [1:0] {S0,S1,S2,S3} state_t;
state_t state_c,state_n;
always@(posedge clk or negedge rstn) begin
    if(~rstn)
        state_c <= S0;
    else  
        state_c <= state_n;
end
always@(*) begin
    state_n = state_c;
    case(state_c)
        S0: state_n = fsm_start_trig?   S1 : S0;
        S1: state_n = counter_hit?      S2 : S1;
        S2: state_n = mult_done?        S3 : S2;
        S3: state_n = counter_hit?      S0 : S3;
        default: state_n = state_c;
    endcase
end

assign counter_hit = (counter == 7'd99);
assign mult_done = (mult_cnt == 4'd9);

`ifdef USE_ICG
logic clk_cnt_gt;
logic clk_mult_gt;
logic icg_cnt_enable;
logic icg_mult_enable;
ckgate_cell u_clk_icg_cnt (.clkin(clk),  .enable(icg_cnt_enable), .scan_en(scan_en), .clkout(clk_cnt_gt));
ckgate_cell u_clk_icg_mult (.clkin(clk),  .enable(icg_mult_enable), .scan_en(scan_en), .clkout(clk_mult_gt));

logic state_2;
logic state_2_d1;
always@(posedge clk or negedge rstn) begin
    if(~rstn)   
        state_2_d1 <= 1'b0;
    else 
        state_2_d1 <= state_2;
end
assign state_2 = (state_c == S2);
assign icg_cnt_enable = (state_c == S1 || state_c == S3);
assign icg_mult_enable = (state_2 | state_2_d1);

// counter //
always@(posedge clk_cnt_gt or negedge rstn) begin
    if(~rstn) 
        counter <= 'd0;
    else if(counter_hit)
        counter <= 'd0;
    else
        counter <= counter + 1'b1;
end

// mult // if not reuse counter //
always@(posedge clk_mult_gt or negedge rstn) begin
    if(~rstn)
        mult_cnt <= 'd0;
    else if(mult_done)
        mult_cnt <= 'd0;
    else if(din_vld)
        mult_cnt <= mult_cnt + 1'b1;
end
always@(posedge clk_mult_gt or negedge rstn) begin
    if(~rstn) 
        mul_out_vld <= 1'b0;
    else if(state_c == S2 && din_vld)
        mul_out_vld <= 1'b1;
    else 
        mul_out_vld <= 1'b0;
end
always@(posedge clk_mult_gt or negedge rstn) begin
    if(~rstn) 
        mul_out <= 'd0;
    else if(din_vld)
        mul_out <= $signed(mula) * $signed(mulb);
end

`else
// counter //
always@(posedge clk or negedge rstn) begin
    if(~rstn) 
        counter <= 'd0;
    else if(counter_hit)
        counter <= 'd0;
    else if(state_c == S1 || state_c == S3)
        counter <= counter + 1'b1;
end

// mult // if not reuse counter //
always@(posedge clk or negedge rstn) begin
    if(~rstn)
        mult_cnt <= 'd0;
    else if(mult_done)
        mult_cnt <= 'd0;
    else if(state_c == S2 && din_vld)
        mult_cnt <= mult_cnt + 1'b1;
end
always@(posedge clk or negedge rstn) begin
    if(~rstn) 
        mul_out_vld <= 1'b0;
    else if(state_c == S2 && din_vld)
        mul_out_vld <= 1'b1;
    else 
        mul_out_vld <= 1'b0;
end
always@(posedge clk or negedge rstn) begin
    if(~rstn) 
        mul_out <= 'd0;
    else if(state_c == S2 && din_vld)
        mul_out <= $signed(mula) * $signed(mulb);
end

`endif

`ifdef ASSERT_ON
logic signed [7:0] A_s,B_s;
logic [14:0] mul_s;
assign A_s = $signed(mula);
assign B_s = $signed(mulb);
assign mul_s = A_s * B_s;

assert property(mul_out_vld_assert)       
    $display("mul_out_vld_assert passed",$time); 
else
    $display("mul_out_vld_assert error",$time);  

assert property(mul_out_assert)       
    $display("mul_out_assert passed",$time); 
else
    $display("mul_out_assert error",$time);  

sequence vld_10_times;
    @(posedge clk) ($past(din_vld,1) && mul_out_vld)[->10];
endsequence

sequence nonvld_100_times;
    @(posedge clk) (mul_out_vld==0)[*100];
endsequence

property mul_out_vld_assert;
    @ (posedge clk) disable iff(!rstn)
    $rose(fsm_start_trig) |=> nonvld_100_times ##[0:$] (vld_10_times ##1 nonvld_100_times);
endproperty

property mul_out_assert;
    longint tmp;
    @ (posedge clk) disable iff(!rstn)
    (din_vld, tmp= mul_s) |-> ##1 (mul_out_vld?  mul_out==tmp : 1'b1);
endproperty

`endif

endmodule
