module counter_level_clr_1(
    input           clk           ,
    input           rstn          ,
    input           scan_en       ,   // 非scan mode下默认为0
    input           enable        ,// 时钟门控使能，注意：需要考虑该信号与clk的CDC问题
    output logic    counter_out 
);
logic [31:0] counter;

`ifdef USE_ICG
logic clk_gt;
logic enable_d1;
logic icg_enable;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        enable_d1 <= 1'b0;
    else 
        enable_d1 <= enable;
end 

assign icg_enable = enable || enable_d1;

ckgate_cell u_clk_icg (.clkin(clk),  .enable(icg_enable), .scan_en(scan_en), .clkout(clk_gt));

always_ff@(posedge clk_gt or negedge rstn) begin
    if(~rstn)
        counter <= 'd0;
    else if(~enable || counter == 32'd99)
        counter <= 'd0;
    else
        counter <= counter + 1'b1;
end

always_ff@(posedge clk_gt or negedge rstn) begin
    if(~rstn)
        counter_out <= 1'b0;
    else if(enable && counter == 32'd99)
        counter_out <= 1'b1;
    else 
        counter_out <= 1'b0;
end

`else

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        counter <= 'd0;
    else if(~enable || counter == 32'd99)
        counter <= 'd0;
    else
        counter <= counter + 1'b1;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        counter_out <= 1'b0;
    else if(enable && counter == 32'd99)
        counter_out <= 1'b1;
    else 
        counter_out <= 1'b0;
end

`endif



`ifdef ASSERT_ON

assert property(counter_out_assert_1)       
    $display("counter out 1 passed",$time);          
else
    $display("counter out 1 error",$time);           

assert property(counter_out_assert_2)       
    $display("counter out 2 passed",$time);      
else
    $display("counter out 2 error",$time);       

property counter_out_assert_1;
    @ (posedge clk) disable iff(!rstn)
    $rose(enable) |=>##99 $rose(counter_out) ;
endproperty

property counter_out_assert_2;
    @ (posedge clk) disable iff(!rstn)
    $rose(counter_out) |=> (enable[*100] |-> ##0 $rose(counter_out)) ;
endproperty

`endif

endmodule