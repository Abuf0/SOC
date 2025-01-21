module coef_cache_mem(
    input                clk            ,
    input                rstn           ,
    input                cache_ena      ,
    input [3:0]          cache_wena     ,
    input [4:0]          cache_addr     ,
    input [63:0]         cache_wdata    ,
    output logic [63:0]  cache_rdata    ,
    input [3:0]          coef_wena      ,
    input [5:0]          coef_addr      ,
    input [63:0]         coef_wdata     ,
    output logic [63:0]  coef_rdata     
);

logic                cache_mem_cen    ;
logic                cache_mem_wen    ;
logic [3:0]          cache_mem_bwen   ;
logic [4:0]          cache_mem_addr   ;
logic [63:0]         cache_mem_wdata  ;
logic [63:0]         cache_mem_rdata  ;

logic                coef_mem_cen     ;
logic                coef_mem_wen     ;
logic [63:0]         coef_mem_bwen    ;
logic [5:0]          coef_mem_addr    ;
logic [63:0]         coef_mem_wdata   ;
logic [63:0]         coef_mem_rdata   ;

assign cache_mem_cen   = ~cache_ena;
assign cache_mem_wen   = ~(|cache_wena);
assign cache_mem_bwen  = ~cache_wena[3:0];
assign cache_mem_addr  = cache_addr;
assign cache_mem_wdata = cache_wdata;
assign cache_rdata     = cache_mem_rdata;

assign coef_mem_cen   = ~coef_ena;
assign coef_mem_wen   = ~(|coef_wena);
assign coef_mem_bwen  = ~coef_wena[3:0];
assign coef_mem_addr  = coef_addr;
assign coef_mem_wdata = coef_wdata;
assign coef_rdata     = coef_mem_rdata;

// 例化32x64的 cache memory

// 例化48x64的 coef memory

endmodule