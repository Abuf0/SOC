//generate sck,csn,rstn to slave
module spi_crmu(
    input spi_sck,
    input spi_csn,
    input spi_rstn,
    input rg_cpha,
    input rg_cpol,
    input [3:0] rg_sck_dly,
    input [3:0] rg_csn_dly,
    input [3:0] rg_mosi_dly,
    output logic sck,   // for read
    output logic sck_inv,   // for write
    output logic csn,
    output logic rstn,
    output logic csn_rstn
);
//TODO for scan
logic sck_sel;
assign sck_sel = rg_cpha ^ rg_cpol; // 0: pos, 1: neg
assign sck = sck_sel?   ~spi_sck:spi_sck;
assign sck_inv = ~sck;
assign csn = spi_csn;
assign csn_rstn = ~spi_csn;
reset_sync u_reset_sync_spi_rstn(.clk(spi_sck),.rstn_a(spi_rstn),.rstn_s(rstn));

endmodule