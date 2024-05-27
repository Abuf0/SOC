module apb_sram#(
    parameter PADDR_WIDTH = 16  ,
    parameter DATA_WIDTH  = 32
)
(
    input                           pclk        ,
    input                           presetn     ,
    input [PADDR_WIDTH-1:0]         paddr       ,
    input                           psel        ,
    input                           penable     ,
    input                           pwrite      ,
    input [DATA_WIDTH-1:0]          pwdata      ,
    input [DATA_WIDTH/8-1:0]        pstrb       ,
    output logic                    pready_o    ,
    output logic [DATA_WIDTH-1:0]   prdata_o
);
logic [DATA_WIDTH-1:0] strb_ext;
logic [DATA_WIDTH-1:0] memory [0:63];
logic ready_timeout;
logic error_flag;

genvar i;
integer j;
generate
    for(i=0;i<DATA_WIDTH;i=i+1)   begin: MEMORY_BLK
        assign strb_ext[i] = {8{pstrb[i/8]}};        
    end
endgenerate
// write
always_ff @( posedge pclk or negedge presetn ) begin
    if(~presetn) begin
        for(j=0;j<64;j=j+1) begin
            memory[j] <= 'd0;
        end
    end
    else if(pwrite && psel && penable) begin
        memory[paddr[5:0]] <= (pwdata & memory[paddr[5:0]]) | 
                         (~strb_ext & ~pwdata & memory[paddr[5:0]]) | 
                         (strb_ext & pwdata & ~memory[paddr[5:0]]);
    end
end
// output
// read
always_ff @( posedge pclk or negedge presetn ) begin
    if(~presetn) 
        prdata_o <= 'd0;
    else if(~pwrite && psel && penable)
        prdata_o <= memory[paddr[5:0]];
end

always_ff @( posedge pclk or negedge presetn ) begin
    if(~presetn) 
        pready_o <= 1'b1;
    else if(psel && ~penable)
        pready_o <= 1'b1; //can be set any value // 1:for no-wait, 0:for wait
    else if(psel && penable && ready_timeout)    // can add condition to extend transfer
        pready_o <= 1'b1;
    else 
        pready_o <= 1'b1;
end

endmodule