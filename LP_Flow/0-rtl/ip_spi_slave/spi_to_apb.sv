module spi_to_apb(
    input               clk_spi     ,
    input               rstn_spi    ,
    input               clk_sys     ,
    input               rstn_sys    ,
    input               reg_wr      ,
    input               reg_rd      ,
    input        [15:0] reg_addr    ,
    input        [15:0] reg_wdata   ,
    output logic [15:0] reg_rdata   ,
    output logic        pwrite      ,
    output logic        psel        ,
    output logic        penable     ,
    output logic [15:0] paddr       ,
    output logic [15:0] pwdata      ,
    input        [15:0] prdata      
);

assign psel = reg_rd | reg_wr;
assign pwrite = reg_wr;
assign paddr = reg_addr;
assign pwdata = reg_wdata;
assign reg_rdata = prdata;
assign penable = psel;  // todo
endmodule