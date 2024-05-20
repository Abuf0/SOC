module spi_top(
    input spi_sck,
    input spi_csn,
    input spi_rstn,
    input rg_cpha,
    input rg_cpol,
    input spi_mosi,
    output logic spi_miso,
    // TO regfile(unsync)
    output logic regfile_wr,
    output logic regfile_rd,
    output logic [15:0] regfile_addr,
    output logic [15:0] wregfile_data,
    input [15:0] rregfile_data,
    // TO FIFO(unsync)
    output logic fifo_rd,
    input [15:0] fifo_rdata
);
logic sck;
logic sck_inv;
logic csn;
logic rstn;
logic csn_rstn;
logic addr_load;
logic data_load;
logic read_load;
logic [15:0] spi_addr;
logic [15:0] spi_wdata;
logic [15:0] spi_rdata;
logic [15:0] wregfile_addr;
logic [15:0] rregfile_addr;

assign regfile_addr = regfile_wr?   wregfile_addr:rregfile_addr;

spi_crmu u_spi_crmu(
     .spi_sck(spi_sck),
     .spi_csn(spi_csn),
     .spi_rstn(spi_rstn),
     .rg_cpha(rg_cpha),
     .rg_cpol(rg_cpol),
     .rg_sck_dly(),
     .rg_csn_dly(),
     .rg_mosi_dly(),
     .sck(sck),   
     .sck_inv(sck_inv),   
     .csn(csn),
     .rstn(rstn),
     .csn_rstn(csn_rstn)
);
spi_rw_ctrl u_spi_rw_ctrl(
     .sck(sck),
     .sck_inv(sck_inv),
     .csn(csn),
     .rstn(rstn),
     .csn_rstn(csn_rstn),
     .mosi(spi_mosi),
     .rdata(spi_rdata),
     .addr(spi_addr),
     .wdata(spi_wdata),
     .addr_load(addr_load),  // for write and read 
     .data_load(data_load),  // for write
     .read_load(read_load),  // for read
     .miso(spi_miso)    
);
spi_wbuf u_spi_wbuf(
    .clk_sys(clk_sys),
    .rstn_sys(rstn_sys),
    .sck(sck),
    .csn(csn),
    .rstn(rstn),
    .addr_load(addr_load),
    .data_load(data_load),
    .spi_waddr(spi_addr),
    .spi_wdata(spi_wdata),
    .regfile_wr(regfile_wr),    // TODO SYNC
    .wregfile_addr(wregfile_addr),
    .wregfile_data(wregfile_data)
);
spi_rbuf u_spi_rbuf(
    .sck(sck),
    .csn(csn),
    .rstn(rstn),
    .csn_rstn(csn_rstn),
    .addr_load(addr_load),
    .read_load(read_load),
    .spi_raddr(spi_addr),  
    .regfile_rd(regfile_rd),     
    .rregfile_addr(rregfile_addr),
    .rregfile_data(rregfile_data),
    .fifo_rd(fifo_rd),
    .fifo_rdata(fifo_rdata),
    .spi_rdata(spi_rdata)   // to miso
);

endmodule