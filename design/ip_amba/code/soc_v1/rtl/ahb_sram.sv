module ahb_sram
#(
    parameter HADDR_WIDTH   = 32   ,   // 10~64
    parameter DATA_WIDTH    = 128  ,   // 8,16,32,64,128,256,512,1024
    parameter MEM_DEEPTH    = 64   ,
    parameter HBURST_WIDTH  = 3    ,   // 0,3
    parameter HPROT_WIDTH   = 0    ,   // 0,4,7
    parameter HMASTER_WIDTH = 8     // 0~8
)
(
    // ------ From system ------ //
    input                           hclk        ,
    input                           hresetn     ,
    // ------ From master ------ //
    input [HADDR_WIDTH-1:0]         haddr       ,
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
    // ------ To peripheral -----------//
    //output logic                    men_ce      ,
    //output logic                    mem_wr      ,
    //output logic [HADDR_WIDTH-1:0]  mem_addr    ,
    //output logic [DATA_WIDTH-1:0]   mem_wdata   ,
    //output logic [DATA_WIDTH-1:0]   mem_rdata   ,
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
logic [HADDR_WIDTH-1:0] haddr_d1;
logic [DATA_WIDTH-1:0] hwdata_d1;
logic mem_wr;
logic mem_ce;
logic [HADDR_WIDTH-1:0] mem_addr;
logic [DATA_WIDTH-1:0] mem_wdata;
logic [DATA_WIDTH-1:0] mem_rdata;
logic [DATA_WIDTH-1:0] hrdata_old;

logic [DATA_WIDTH-1:0] strb_ext;
logic [DATA_WIDTH-1:0] memory [0:MEM_DEEPTH-1];
logic ready_timeout;
logic error_flag;

parameter MEM_ADDR_LEN = $clog2(MEM_DEEPTH);

genvar i;
integer j;
generate
    for(i=0;i<DATA_WIDTH;i=i+1)   begin: MEMORY_BLK
        assign strb_ext[i] = {8{hwstrb[i/8]}};        
    end
endgenerate
initial begin
    $readmemh("~/SOC/ip_demo/soc_v1/rtl/cm3.txt",memory);
end
// write
/*
always_ff @( posedge hclk or negedge hresetn ) begin
    if(~hresetn) begin
        $readmemh("~/SOC/ip_demo/soc_v1/rtl/cm3.txt",memory);
    end
    else if(mem_ce && mem_wr) begin
        //memory[mem_addr[MEM_ADDR_LEN-1:2]] <= (mem_wdata & memory[mem_addr[MEM_ADDR_LEN-1:2]]) | 
        //                 (~strb_ext & ~mem_wdata & memory[mem_addr[MEM_ADDR_LEN-1:2]]) | 
        //                 (strb_ext & mem_wdata & ~memory[mem_addr[MEM_ADDR_LEN-1:2]]);
        //memory[mem_addr[MEM_ADDR_LEN-1:2]] <= mem_wdata;
        memory[mem_addr[MEM_ADDR_LEN-1:2]] <= hwdata;
    end
end
*/
logic [3:0] byte_sel;
logic [3:0] byte_sel_d1;
logic tx_byte       ;
logic tx_half       ;
logic tx_word       ;
logic byte_at_00    ;
logic byte_at_01    ;
logic byte_at_10    ;
logic byte_at_11    ;
logic half_at_00    ;
logic half_at_10    ;
logic word_at_00    ;
assign tx_byte    = (~hsize[1]) & (~hsize[0]);
assign tx_half    = (~hsize[1]) &  hsize[0];
assign tx_word    =   hsize[1];
assign byte_at_00 = tx_byte & (~haddr[1]) & (~haddr[0]);
assign byte_at_01 = tx_byte & (~haddr[1]) &   haddr[0];
assign byte_at_10 = tx_byte &   haddr[1]  & (~haddr[0]);
assign byte_at_11 = tx_byte &   haddr[1]  &   haddr[0];
assign half_at_00 = tx_half & (~haddr[1]);
assign half_at_10 = tx_half &   haddr[1];
assign word_at_00 = tx_word;
assign byte_sel[0] = word_at_00 | half_at_00 | byte_at_00;
assign byte_sel[1] = word_at_00 | half_at_00 | byte_at_01;
assign byte_sel[2] = word_at_00 | half_at_10 | byte_at_10;
assign byte_sel[3] = word_at_00 | half_at_10 | byte_at_11;

always_ff@(posedge hclk) begin
    if(mem_ce && mem_wr && byte_sel[0])
        memory[mem_addr[MEM_ADDR_LEN-1:2]][7:0] <= hwdata[7:0];
end
always_ff@(posedge hclk) begin
    if(mem_ce && mem_wr && byte_sel[1])
        memory[mem_addr[MEM_ADDR_LEN-1:2]][15:8] <= hwdata[15:8];
end
always_ff@(posedge hclk) begin
    if(mem_ce && mem_wr && byte_sel[2])
        memory[mem_addr[MEM_ADDR_LEN-1:2]][23:16] <= hwdata[23:16];
end
always_ff@(posedge hclk) begin
    if(mem_ce && mem_wr && byte_sel[3])
        memory[mem_addr[MEM_ADDR_LEN-1:2]][31:24] <= hwdata[31:24];
end
// output
// read
/*
always_ff @( posedge hclk or negedge hresetn ) begin
    if(~hresetn) 
        mem_rdata <= 'd0;
    else if(mem_ce && ~mem_wr)
        mem_rdata <= memory[mem_addr[MEM_ADDR_LEN-1:2]];
end
*/
assign mem_rdata = memory[mem_addr[MEM_ADDR_LEN-1:2]];

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
                state_n = htrans[1]?    (hwrite? MEM_W:MEM_R) : IDLE;
            end
            MEM_R: begin
                state_n = htrans[1]?    (hwrite? MEM_W:MEM_R) : IDLE;
            end
            default:    state_n = IDLE;
        endcase
    end
end

always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        mem_ce <= 1'b0;
    else if(state_n == MEM_W | state_n == MEM_R)
        mem_ce <= 1'b1;
    else 
        mem_ce <= 1'b0;
end
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        mem_wr <= 1'b0;
    else if(state_n == MEM_W)
        mem_wr <= 1'b1;
    else 
        mem_wr <= 1'b0;
end
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        mem_addr <= 'b0;
    else if(state_n == MEM_W | state_n == MEM_R)
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
/*
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        hrdata <= 'b0;
    else if(state_n == MEM_R)
        hrdata <= mem_rdata;
end
*/
/*
assign mem_ce = (state_n == MEM_W | state_n == MEM_R);
assign mem_wr = (state_n == MEM_W);
assign mem_addr = haddr;
assign mem_wdata = hwdata;
*/
//assign hrdata = (state_n == MEM_R)? mem_rdata : hrdata_old;
assign hrdata = (state_n == MEM_R)? mem_rdata : 'd0;
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        hrdata_old <= 'b0;
    else 
        hrdata_old <= hrdata;
end

always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        byte_sel_d1 <= 'b0;
    else if(state_n == MEM_W)
        byte_sel_d1 <= byte_sel;
end

assign hexokay = 1'b1;
assign hresp = 1'b0;
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        hreadyout <= 1'b1;
    else if(state_n == MEM_W | state_n == MEM_R)    // can add condition to extend transfer
        hreadyout <= 1'b1;
end

always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)    haddr_d1 <= 'd0;
    else            haddr_d1 <= haddr;
end
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)    hwdata_d1 <= 'd0;
    else            hwdata_d1 <= hwdata;
end
endmodule