module reg_array #(
    parameter AW = 16,
    parameter DW = 16,
    parameter N = 256
)(
    input           clk           ,
    input           rstn          ,
    input           cen           ,
    input           we            ,
    input [AW-1:0]  addr          ,
    input [DW-1:0]  wdata         ,
    output [DW-1:0] rdata
);

logic [DW-1:0] mem [0:N-1];

always @(posedge clk or negedge rstn) begin
    if(~rstn)
        $readmemh("./img_data.txt",mem);
    else if(~cen && we) begin
        mem[addr] <= wdata;
        `ifdef MEM_INFO
            $display("[W]MEM[%d]=%d\n", addr, wdata);
    end
end

always @(posedge clk or negedge rstn) begin
    if(~rstn)
        rdata <= 'd0;
    else if(~cen && ~we) begin
        rdata <= mem[addr];
        `ifdef MEM_INFO
            $display("[R]MEM[%d]=%d\n", addr, rdata);
    end
end
endmodule