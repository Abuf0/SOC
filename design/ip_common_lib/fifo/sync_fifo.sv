module sync_fifo#(
    parameter DW     = 16   ,
    parameter DEEPTH = 64
)(
    input                       clk             ,
    input                       rstn            ,
    input                       wr              ,
    input [DW-1:0]              wdata           ,
    input                       rd              ,
    output logic [DW-1:0]       rdata           ,
    output logic                rdata_vld       ,
    output [$clog2(DEEPTH)-1:0] fifo_used       ,
    output logic                fifo_ov_flag    
);

parameter L = $clog2(DEEPTH);

logic [L:0] wptr;
logic [L:0] rptr;
logic [L-1:0] waddr;
logic [L-1:0] raddr;
logic fifo_full;
logic fifo_empty;

assign fifo_used = (wptr[L] ^ rptr[L])?  (DEEPTH + rptr[L-1:0] - wptr[L-1:0]) : (wptr[L-1:0] - rptr[L-1:0]);
assign fifo_full = (fifo_used == DEEPTH);
assign fifo_empty = (fifo_used == 0);

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        wptr <= 'd0;
    else if(~fifo_full && wr)
        wptr <= (wptr == DEEPTH-1)?  'd0 : wptr + 1'b1;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        rptr <= 'd0;
    else if(~fifo_empty && rd)
        rptr <= (rptr == DEEPTH-1)?  'd0 : rptr + 1'b1;
end

logic [DW-1:0] buffer [0:DEEPTH-1];

assign waddr = wptr[L-1:0];
assign raddr = rptr[L-1:0];

always@(posedge clk) begin
    if(~fifo_full && wr)
        buffer[waddr] <= wdata;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        rdata <= 'd0;
        rdata_vld <= 1'b0;
    end
    else if(~fifo_empty && rd) begin
        rdata <= buffer[raddr];
        rdata_vld <= 1'b1;
    end
    else begin
        rdata <= 'd0;
        rdata_vld <= 1'b0;
    end
end

endmodule