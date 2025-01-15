module demo_to_yyy(
    input clk           ,
    input rstn          ,
    input scan_en       ,   // 非scan mode下默认为0
    input icg_enable        // 时钟门控使能，注意：需要考虑该信号与clk的CDC问题
);
logic clk_sys;
logic [31:0] counter;

`ifdef USE_ICG
ckgate_cell u_clk_icg (.clkin(clk),  .enable(icg_enable), .scan_en(scan_en), .clkout(clk_sys));
`else
assign clk_sys = clk;
`endif

always_ff@(posedge clk_sys or negedge rstn) begin
    if(~rstn)
        counter <= 'd0;
    else
        counter <= counter + 1'b1;
end

// 或者↓，dc综合工具也有概率自动插icg //
/* 
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        counter <= 'd0;
    else if(icg_enable)
        counter <= counter + 1'b1;
end
*/

endmodule