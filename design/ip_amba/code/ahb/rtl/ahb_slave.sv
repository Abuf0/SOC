module ahb_slave
#(
    parameter ADDR_WIDTH    = 32   ,   // 10~64
    parameter DATA_WIDTH    = 128  ,   // 8,16,32,64,128,256,512,1024
    parameter HBURST_WIDTH  = 3  ,   // 0,3
    parameter HPROT_WIDTH   = 0   ,   // 0,4,7
    parameter HMASTER_WIDTH = 8     // 0~8
)
(
    // ------ From system ------ //
    input                           hclk        ,
    input                           hresetn     ,
    // ------ From master ------ //
    input [ADDR_WIDTH-1:0]          haddr       ,
    input [HBURST_WIDTH-1:0]        hburst      ,
    input                           hmasterlock ,
    input [HPROT_WIDTH-1:0]         hprot       ,
    input [2:0]                     hsize       ,
    input                           hnonsec     ,
    input [HMASTER_WIDTH-1:0]       hmaster     ,
    input [1:0]                     htrans      ,
    input [DATA_WIDTH-1:0]          hwdata      ,
    input [DATA_WIDTH/8-1:0]        hwstrb      ,
    input                           hwrite      ,
    // ------ From interconnect ------ //
    input                           hsel        ,
    input                           hready      ,
    // ------ To interconnect ------ //
    output logic [DATA_WIDTH-1:0]   hrdata      ,
    output logic                    hreadyout   ,
    output logic                    hresp       ,
    output logic                    hexokay     
);
// AHB的从机一般是一些高速设备，比如memory之类；
// 此处代码假设slave是memory
// 以下定义了mem接口
/*
    mem_wr
    mem_ce
    mem_addr
    mem_wdata
    mem_rdata
*/
logic mem_wr;
logic mem_ce;
logic [ADDR_WIDTH-1:0] mem_addr;
logic [DATA_WIDTH-1:0] mem_wdata;
logic [DATA_WIDTH-1:0] mem_rdata;
logic transfer_on;
assign transfer_on = hsel && hready && htrans[1];   // HTRANS = NONSEQ/SEQ
typedef enum logic [1:0] {IDLE,MEM_W,MEM_R} state_t;
state_t state_c,state_n;
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        state_c <= IDLE;
    else
        state_c <= state_n;
end
always@(*) begin
    if(~hresetn)
        state_n = IDLE;
    else begin
        state_n = IDLE;
        case(state_c) 
            IDLE: begin
                state_n = (transfer_on && hwrite)?  MEM_W :
                          (transfer_on && ~hwrite)? MEM_R :
                          IDLE;
            end
            MEM_W: begin
                state_n = htrans[1]?    MEM_W : IDLE;
            end
            MEM_R: begin
                state_n = htrans[1]?    MEM_R : IDLE;
            end
            default:    state_n = IDLE;
        endcase
    end
end
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        mem_ce <= 1'b0;
    else if(state_c == MEM_W | state_c == MEM_R)
        mem_ce <= 1'b1;
    else 
        mem_ce <= 1'b0;
end
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        mem_wr <= 1'b0;
    else if(state_c == MEM_W)
        mem_wr <= 1'b1;
    else 
        mem_wr <= 1'b0;
end
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        mem_addr <= 'b0;
    else if(state_c == MEM_W | state_c == MEM_R)
        mem_addr <= haddr;
    else 
        mem_addr <= 'b0;
end
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        mem_wdata <= 'b0;
    else if(state_c == MEM_W)
        mem_wdata <= hwdata;
end
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        hrdata <= 'b0;
    else if(state_c == MEM_R)
        hrdata <= mem_rdata;
end
assign hexokay = 1'b1;
assign hresp = 1'b0;
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        hreadyout <= 1'b1;
    else if(state_c == MEM_W | state_c == MEM_R)    // can add condition to extend transfer
        hreadyout <= 1'b1;
end
endmodule