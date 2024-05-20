module spi_rbuf(
    input sck,
    input csn,
    input rstn,
    input csn_rstn,
    input addr_load,
    input read_load,
    input [15:0] spi_raddr, // spi read address
    // for regfile
    output logic regfile_rd,    // TODO SYNC
    output logic [15:0] rregfile_addr,
    input [15:0] rregfile_data,
    // for FIFO
    output logic  fifo_rd,
    input [15:0] fifo_rdata,

    output logic [15:0] spi_rdata
);
parameter FIFO_ADDR = 16'haaaa;
logic fifo_addr_flag;
assign fifo_addr_flag = (spi_raddr == FIFO_ADDR)?    1'b1:1'b0;

// for fetch real read addr
logic addr_load_d1; // CMD_WR last sck(not valid)
logic addr_load_d2; // CMD_RD first sck(valid)
always_ff@(posedge sck or negedge rstn) begin  
    if(~csn_rstn)
        {addr_load_d1,addr_load_d2} <= 2'd0;
    else 
        {addr_load_d1,addr_load_d2} <= {addr_load,addr_load_d1};
end

//assign regfile_rd =  read_load && ~fifo_addr_flag; // TODO SYNC
always_ff@(posedge sck or negedge csn_rstn) begin  
    if(~csn_rstn)
        regfile_rd <= 1'd0;
    else if((addr_load_d2 || read_load)&& ~fifo_addr_flag)  // when switch to next addr
        regfile_rd <= 1'b1;
    else
        regfile_rd <= 1'b0;
end

always_ff@(posedge sck or negedge rstn) begin   // TODO SYNC, prefetch
    if(~rstn)
        rregfile_addr <= 16'd0;
    else if(addr_load_d2 && ~fifo_addr_flag)    // prefetch start addr after addr_load
        rregfile_addr <= spi_raddr;
    else if(read_load && ~fifo_addr_flag)   // fetch next addr when require next rdata
        rregfile_addr <= rregfile_addr + 16'd2;
end

assign fifo_rd = read_load && fifo_addr_flag; // TODO SYNC

assign spi_rdata = fifo_addr_flag?  fifo_rdata:rregfile_data;

endmodule