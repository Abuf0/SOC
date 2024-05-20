module spi_tb();
logic spi_sck;
logic spi_csn;
logic spi_rstn;
logic rg_cpha;
logic rg_cpol;
logic spi_mosi;
logic spi_miso;
logic regfile_wr;
logic regfile_rd;
logic [15:0] regfile_addr;
logic [15:0] wregfile_data;
logic [15:0] rregfile_data;
logic fifo_rd;
logic [15:0] fifo_rdata;

logic spi_sck_real;
logic sck_en_init;
assign spi_sck_real = (~spi_csn || sck_en_init) & spi_sck;

always # 10 spi_sck = ~spi_sck;

initial begin
    spi_sck=0;
    spi_rstn=0;
    spi_csn=1;
    spi_mosi=0;
    rg_cpha=0;
    rg_cpol=0;
    sck_en_init = 1;
    #133
    spi_rstn=1;
    @(negedge spi_sck);
    @(negedge spi_sck);
    @(negedge spi_sck);
    #3 sck_en_init = 0;
    #133
    @(negedge spi_sck);
    #2
    spi_csn=0;
    //@(negedge spi_sck);
    spi_mosi=1;
    @(negedge spi_sck);
    spi_mosi=1;
    @(negedge spi_sck);
    spi_mosi=1;
    @(negedge spi_sck);
    spi_mosi=1;
    @(negedge spi_sck);
    spi_mosi=0;
    @(negedge spi_sck);
    spi_mosi=0;
    @(negedge spi_sck);
    spi_mosi=0;
    @(negedge spi_sck);
    spi_mosi=0;
    repeat(8) begin // addr=5555
        @(negedge spi_sck);
        spi_mosi=0;
        @(negedge spi_sck);
        rregfile_data=16'hf1f2;
        spi_mosi=1;
    end
    @(negedge spi_sck);
    #2
    spi_csn=1;
    #133
    @(negedge spi_sck);
    #2
    spi_csn=0;
    //@(negedge spi_sck);
    spi_mosi=1;
    @(negedge spi_sck);
    spi_mosi=1;
    @(negedge spi_sck);
    spi_mosi=1;
    @(negedge spi_sck);
    spi_mosi=1;
    @(negedge spi_sck);
    spi_mosi=0;
    @(negedge spi_sck);
    spi_mosi=0;
    @(negedge spi_sck);
    spi_mosi=0;
    @(negedge spi_sck);
    spi_mosi=1;
    repeat(8) begin // read
        @(negedge spi_sck);
        spi_mosi=0;
        @(negedge spi_sck);
        rregfile_data=16'hf3f4;
        spi_mosi=1;
    end
    repeat(8) begin // read
    @(negedge spi_sck);
    spi_mosi=0;
    rregfile_data=16'hf5f6;
    @(negedge spi_sck);
    spi_mosi=1;
    end
    repeat(8) begin // read
    @(negedge spi_sck);
    spi_mosi=1;
    rregfile_data=16'hf7f8;
    @(negedge spi_sck);
    spi_mosi=1;
    end
    @(negedge spi_sck);
    #2
    spi_csn=1;
    #133
    @(posedge spi_sck);
    #2
    spi_csn=0;
    //@(negedge spi_sck);
    spi_mosi=1;
    @(negedge spi_sck);
    spi_mosi=1;
    @(negedge spi_sck);
    spi_mosi=1;
    @(negedge spi_sck);
    spi_mosi=1;
    @(negedge spi_sck);
    spi_mosi=0;
    @(negedge spi_sck);
    spi_mosi=0;
    @(negedge spi_sck);
    spi_mosi=0;
    @(negedge spi_sck);
    spi_mosi=0;
    repeat(8) begin // addr=00000
        @(negedge spi_sck);
        spi_mosi=0;
        @(negedge spi_sck);
        rregfile_data=16'hf0f0;
        spi_mosi=0;
    end
    repeat(8) begin // data=ffff
    @(negedge spi_sck);
    spi_mosi=1;
    @(negedge spi_sck);
    rregfile_data=16'hf0f0;
    spi_mosi=1;
    end
    repeat(8) begin // data=aaaa
    @(negedge spi_sck);
    spi_mosi=1;
    @(negedge spi_sck);
    rregfile_data=16'hf0f0;
    spi_mosi=0;
    end
    @(negedge spi_sck);
    #2
    spi_csn=1;
    #133
    $finish(2);
end


spi_top u_spi_top(
    .spi_sck(spi_sck_real),
    .spi_csn(spi_csn),
    .spi_rstn(spi_rstn),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso),
    .rg_cpha(rg_cpha),
    .rg_cpol(rg_cpol),
    .regfile_wr(regfile_wr),
    .regfile_rd(regfile_rd),
    .regfile_addr(regfile_addr),
    .wregfile_data(wregfile_data),
    .rregfile_data(rregfile_data),
    .fifo_rd(fifo_rd),
    .fifo_rdata(fifo_rdata)
);

initial begin
    $fsdbDumpfile("spi_tb.fsdb");
    $fsdbDumpvars();
end

endmodule