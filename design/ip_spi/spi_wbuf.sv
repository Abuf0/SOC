module spi_wbuf(
    input clk_sys,
    input rstn_sys,
    input sck,
    input csn,
    input rstn,
    input addr_load,
    input data_load,
    input [15:0] spi_waddr,
    input [15:0] spi_wdata,
    output logic regfile_wr,    // TODO SYNC
    output logic [15:0] wregfile_addr,
    output logic [15:0] wregfile_data
);
parameter FIFO_ADDR = 16'haaaa;
logic fifo_addr_flag;
logic wreg_addr_load;   // delay 1d for addr_load
assign fifo_addr_flag = (spi_waddr==FIFO_ADDR)?  1'b1:1'b0;

always_ff@(posedge sck or negedge rstn) begin
    if(~rstn)
        wreg_addr_load <= 1'b0;
    else if(~fifo_addr_flag)
        wreg_addr_load <= addr_load;
end

always_ff@(posedge sck or negedge rstn) begin
    if(~rstn)
        wregfile_addr <= 1'b0;
    else if(wreg_addr_load) // load start addr
        wregfile_addr <= spi_waddr;
    else if(~fifo_addr_flag && data_load)   // waddr+2 for dataload
        wregfile_addr <= wregfile_addr + 16'd2;
end

assign regfile_wr = ~fifo_addr_flag && data_load;
assign wregfile_data = spi_wdata;

endmodule