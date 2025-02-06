module div_clk
#(
    parameter DIV_WID = 4
)(
    input               clk            ,
    input               rstn           ,
    input [DIV_WID-1:0] div_dat_even   ,
    output logic        clk_div_o       
);

logic nodiv;
logic clk_div;
logic [DIV_WID-1:0] div_cnt;
assign nodiv = (div_dat_even == 0);

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        div_cnt <= 'd0;
    else if(~nodiv)
        div_cnt <= (div_cnt == (div_dat_even>>1)-1'b1)?  'd0 : div_cnt+1'b1;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        clk_div <= 1'b0;
    else if(~nodiv)
        clk_div <= (div_cnt == (div_dat_even>>1)-1'b1)?  ~clk_div : clk_div;
end

assign clk_div_o = nodiv?   clk : clk_div;

endmodule