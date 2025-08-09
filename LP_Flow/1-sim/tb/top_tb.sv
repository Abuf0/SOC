`timescale 1ns/10ps
module top_tb();
wire          PAD_SCK                  ;
wire          PAD_CSN                  ;
wire          PAD_MISO                 ;
wire          PAD_MOSI                 ;
wire          PAD_INT                  ;
wire          PAD_MPX                  ;
wire          VDD1                     ;
wire          VDD2                     ;
wire          VDD3                     ;
wire          VSS                      ;


lp_soc_top lp_soc_top_inst(
    .PAD_SCK   (PAD_SCK  ),
    .PAD_CSN   (PAD_CSN  ),
    .PAD_MISO  (PAD_MISO ),
    .PAD_MOSI  (PAD_MOSI ),
    .PAD_INT   (PAD_INT  ),
    .PAD_MPX   (PAD_MPX  ),
    .VDD1      (VDD1     ),
    .VDD2      (VDD2     ),
    .VDD3      (VDD3     ),
    .VSS       (VSS      )
);

`define SIM
`define MEM_INFO

parameter SPI_PRD = 26;
parameter SPI_BK = 10;
parameter SPI_RD_BK = 200 * 8;  // 8 x Tsys

parameter WRITE = 8'hf0;
parameter READ = 8'hf1;
parameter IDLE = 8'hf2;
parameter IMG = 8'hf3;
parameter SLP = 8'hf4;
parameter WAKE = 8'hf5;

task cmd_send(input [7:0] cmd_id);
    logic [3:0] index;
    force PAD_CSN = 0;
    #SPI_BK;
    index = 7;
    for(int i=0; i<8; i=i+1) begin
        force PAD_MOSI = cmd_id[index];
        #(SPI_PRD/2)
        force PAD_SCK = 1;
        #(SPI_PRD/2)
        force PAD_SCK = 0;
        index = index - 1;
    end
    #SPI_BK
    force PAD_CSN = 1;
endtask

task reg_single_write(input [15:0] waddr, [15:0] wdata);
    logic [3:0] index;
    logic [7:0] cmd_write;
    assign cmd_write = WRITE;
    force PAD_CSN = 0;
    #SPI_BK
    index = 7;
    for(int i=0; i<8; i=i+1) begin
        force PAD_MOSI = cmd_write[index];
        #(SPI_PRD/2)
        force PAD_SCK = 1;
        #(SPI_PRD/2)
        force PAD_SCK = 0;
        index = index - 1;
    end
    index = 15;
    for(int i=0; i<16; i=i+1) begin
        force PAD_MOSI = waddr[index];
        #(SPI_PRD/2)
        force PAD_SCK = 1;
        #(SPI_PRD/2)
        force PAD_SCK = 0;
        index = index - 1;
    end
    index = 15;
    for(int i=0; i<16; i=i+1) begin
        force PAD_MOSI = wdata[index];
        #(SPI_PRD/2)
        force PAD_SCK = 1;
        #(SPI_PRD/2)
        force PAD_SCK = 0;
        index = index - 1;
    end
    #SPI_BK
    force PAD_CSN = 1;
endtask

task reg_single_read(input [15:0] raddr, output logic [15:0] rdata);
    logic [3:0] index;
    logic [7:0] cmd_read;
    logic [7:0] cmd_write;
    assign cmd_read = READ;
    assign cmd_write = WRITE;
    force PAD_CSN = 0;
    #SPI_BK
    index = 7;
    for(int i=0; i<8; i=i+1) begin
        force PAD_MOSI = cmd_write[index];
        #(SPI_PRD/2)
        force PAD_SCK = 1;
        #(SPI_PRD/2)
        force PAD_SCK = 0;
        index = index - 1;
    end
    index = 15;
    for(int i=0; i<16; i=i+1) begin
        force PAD_MOSI = raddr[index];
        #(SPI_PRD/2)
        force PAD_SCK = 1;
        #(SPI_PRD/2)
        force PAD_SCK = 0;
        index = index - 1;
    end
    force PAD_CSN = 1;
    #SPI_RD_BK
    force PAD_CSN = 0;
    index = 7;
    for(int i=0; i<8; i=i+1) begin
        force PAD_MOSI = cmd_read[index];
        #(SPI_PRD/2)
        force PAD_SCK = 1;
        #(SPI_PRD/2)
        force PAD_SCK = 0;
        index = index - 1;
    end
    index = 15;
    for(int i=0; i<16; i=i+1) begin
        #(SPI_PRD/2)
        rdata[index] = PAD_MISO;
        force PAD_SCK = 1;
        #(SPI_PRD/2)
        force PAD_SCK = 0;
        index = index - 1;
    end
    #SPI_BK
    force PAD_CSN = 1;
endtask

task fifo_burst_read_head(input [15:0] raddr, output logic [15:0] rdata);
    logic [3:0] index;
    logic [7:0] cmd_read;
    logic [7:0] cmd_write;
    assign cmd_read = READ;
    assign cmd_write = WRITE;
    force PAD_CSN = 0;
    #SPI_BK
    index = 7;
    for(int i=0; i<8; i=i+1) begin
        force PAD_MOSI = cmd_write[index];
        #(SPI_PRD/2)
        force PAD_SCK = 1;
        #(SPI_PRD/2)
        force PAD_SCK = 0;
        index = index - 1;
    end
    index = 15;
    for(int i=0; i<16; i=i+1) begin
        force PAD_MOSI = raddr[index];
        #(SPI_PRD/2)
        force PAD_SCK = 1;
        #(SPI_PRD/2)
        force PAD_SCK = 0;
        index = index - 1;
    end
    force PAD_CSN = 1;
    #SPI_RD_BK
    force PAD_CSN = 0;
    index = 7;
    for(int i=0; i<8; i=i+1) begin
        force PAD_MOSI = cmd_read[index];
        #(SPI_PRD/2)
        force PAD_SCK = 1;
        #(SPI_PRD/2)
        force PAD_SCK = 0;
        index = index - 1;
    end
endtask


task fifo_burst_read_body(output logic [15:0] rdata);
    logic [3:0] index;
    index = 15;
    for(int i=0; i<16; i=i+1) begin
        #(SPI_PRD/2)
        rdata[index] = PAD_MISO;
        force PAD_SCK = 1;
        #(SPI_PRD/2)
        force PAD_SCK = 0;
        index = index - 1;
    end
endtask

logic [15:0] reg_rd_data;
logic [15:0] fifo_rd_data;

initial begin
    force PAD_CSN = 1;    // todo with PAD PU/[D]
    force PAD_SCK = 0;    // todo with PAD PU/[D]
    #12345
    reg_single_write(16'h0012, 16'h0008);
    #1us
    cmd_send(IMG);
    @(posedge PAD_INT);
    reg_single_read(16'h0010, reg_rd_data);
    $display("ro_int_status : %h\n", reg_rd_data);
    if(reg_rd_data[3]) begin
        $display("fifo space ov!!\n");
        #1us
        fifo_burst_read_head(16'h0100, fifo_rd_data);
        repeat(256) begin
            fifo_burst_read_body(fifo_rd_data);
        end
        #SPI_BK
        force PAD_CSN = 1;
    end
    #5ms
    cmd_send(IDLE);
    #3us;
    $finish(2);
end


initial begin
    $fsdbDumpfile("top_tb.fsdb");
    $fsdbDumpvars();
    $fsdbDumpSVA();
    $fsdbDumpMDA();
end

endmodule