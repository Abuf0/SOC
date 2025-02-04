module counter_pulse_clr_1(
    input               clk           ,
    input               rstn          ,
    input               scan_en       ,   // 非scan mode下默认为0
    input               trig          ,// 注意：需要考虑该信号与clk的CDC问题
    output logic [31:0] counter_value
);
logic clk_sys;
logic [31:0] counter;
logic enable;
logic enable_d1;
logic icg_enable;
logic clk_sys_2;

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        enable <= 1'b0;
    else if(trig)   // 此处默认trig同步
        enable <= ~enable;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        enable_d1 <= 1'b0;
    else 
        enable_d1 <= enable;

assign icg_enable = enable || enable_d1;

`ifdef USE_ICG
ckgate_cell u_clk_icg (.clkin(clk),  .enable(icg_enable), .scan_en(scan_en), .clkout(clk_sys));
`else
assign clk_sys = clk;
`endif

always_ff@(posedge clk_sys or negedge rstn) begin
    if(~rstn)
        counter <= 'd0;
    else if(trig && enable)   // 停止并清零
        counter <= 'd0;
    else
        counter <= counter + 1'b1;
end


`ifdef USE_ICG
ckgate_cell u_clk_icg_2 (.clkin(clk),  .enable(icg_enable && trig), .scan_en(scan_en), .clkout(clk_sys_2));
`else
assign clk_sys_2 = clk;
`endif

always_ff@(posedge clk_sys_2 or negedge rstn) begin
    if(~rstn)
        counter_value <= 'd0;
    //else if(trig)   // 停止时给出计数值
    else 
        counter_value <= counter;

endmodule