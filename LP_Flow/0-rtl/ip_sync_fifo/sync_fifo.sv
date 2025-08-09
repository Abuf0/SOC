module sync_fifo
#(
    parameter DW = 16,
    parameter AW = 8,
    parameter FIFO_DEEPTH = 256
)(
    input                 clk_fifo    ,
    input                 rstn_fifo   ,
    input                 i_wr        ,
    input                 i_rd        ,
    input  [DW-1:0]       i_wdata     ,
    output logic [DW-1:0] o_rdata     ,
    output logic [AW-1:0] o_used      ,
    output logic          fifo_upov_flag,
    output logic          fifo_downov_flag
);

logic [AW:0] wptr;
logic [AW:0] rptr;
logic fifo_empty;
logic fifo_full;
logic mem_cen;
logic mem_we;
logic [AW-1:0] mem_addr;
logic [DW-1:0] mem_wdata;
logic [DW-1:0] mem_rdata;

logic fifo_rd;
logic i_rd_d1;

always_ff@(posedge clk_fifo or negedge rstn_fifo) begin
    if(~rstn_fifo)
        i_rd_d1 <= 1'b0;
    else
        i_rd_d1 <= i_rd;
end
assign fifo_rd = i_rd & ~i_rd_d1;

// todo move full & empty adjustment outside this ip
assign fifo_empty = (rptr == wptr);
assign fifo_full = ((wptr[AW-1:0] == rptr[AW-1:0]) && (wptr[AW] ^ rptr[AW]));
assign o_used = (wptr[AW] ^ rptr[AW])? (FIFO_DEEPTH -rptr[AW-1:0] + wptr[AW-1:0]) : (wptr[AW-1:0] - rptr[AW-1:0]);

always_ff@(posedge clk_fifo or negedge rstn_fifo) begin
    if(~rstn_fifo)
        fifo_upov_flag <= 1'b0;
    else if(fifo_full && i_wr)
        fifo_upov_flag <= 1'b1;
    else
        fifo_upov_flag <= 1'b0;
end

always_ff@(posedge clk_fifo or negedge rstn_fifo) begin
    if(~rstn_fifo)
        fifo_downov_flag <= 1'b0;
    else if(fifo_empty && fifo_rd)
        fifo_downov_flag <= 1'b1;
    else
        fifo_downov_flag <= 1'b0;
end


always_ff @( posedge clk_fifo or negedge rstn_fifo ) begin
    if(~rstn_fifo)
        wptr <= 'd0;
    else if(i_wr && ~fifo_full)
        wptr <= (wptr[AW-1:0] == FIFO_DEEPTH-1)?    {~wptr[AW],{(AW){1'b0}}} : (wptr + 1);
end

always_ff @( posedge clk_fifo or negedge rstn_fifo ) begin
    if(~rstn_fifo)
        rptr <= 'd0;
    else if(fifo_rd && ~fifo_empty)
        rptr <= (rptr[AW-1:0] == FIFO_DEEPTH-1)?    {~rptr[AW],{(AW){1'b0}}} : (rptr + 1);
end

assign mem_cen = ~((i_wr & ~fifo_full) | (fifo_rd & ~fifo_empty));
assign mem_we = i_wr && ~fifo_full;
assign mem_addr = i_wr?  wptr[AW-1:0] : rptr[AW-1:0];
assign mem_wdata = i_wdata;
assign o_rdata = mem_rdata;

// todo replaced with SRAM
reg_array #(.AW(AW), .DW(DW), .N(FIFO_DEEPTH)) mem256x16 (
    .clk(clk_fifo),
    .rstn(rstn_fifo),
    .cen(mem_cen),
    .we(mem_we),
    .addr(mem_addr),
    .wdata(mem_wdata),
    .rdata(mem_rdata)
);
endmodule