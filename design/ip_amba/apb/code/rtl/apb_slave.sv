module apb_slave #(
    parameter ADDR_WIDTH = 16,  // max = 32
    parameter DATA_WIDTH = 32   // 8,16,32
)
(
    input                           pclk    ,   // From system
    input                           presetn ,   // From system
    input [ADDR_WIDTH-1:0]          paddr   ,   // From master
    input [2:0]                     pprot   ,   // From master
    input                           pnse    ,   // From master
    input                           psel    ,   // From master  
    input                           penable ,   // From master
    input                           pwrite  ,   // From master
    input [DATA_WIDTH-1:0]          pwdata  ,   // From master
    input [DATA_WIDTH/8-1:0]        pstrb   ,   // From master
    output logic                    pready  ,   // To master
    output logic [DATA_WIDTH-1:0]   prdata  ,   // To master
    output logic                    pslverr ,   // To master
    input                           pwakeup     // From master // TODO
    // *** USER DEFINE *** // 
);
// APB的completer一般是低速外设，比如memory，regfile等；
// 此处代码假设completer是regfile
logic [DATA_WIDTH-1:0] strb_ext;
logic [DATA_WIDTH-1:0] memory [0:63];
logic ready_timeout;
logic error_flag;

assign ready_timeout = 1'b1;
assign error_flag = 1'b0;

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
        prdata <= 'd0;
    else if(~pwrite && psel && penable)
        prdata <= memory[paddr[5:0]];
end

always_ff @( posedge pclk or negedge presetn ) begin
    if(~presetn) 
        pready <= 1'b0;
    else if(psel && ~penable)
        pready <= 1'b1; //can be set any value // 1:for no-wait, 0:for wait
    else if(psel && penable && ready_timeout)    // can add condition to extend transfer
        pready <= 1'b1;
    else 
        pready <= 1'b0;
end

always_ff @( posedge pclk or negedge presetn ) begin
    if(~presetn) 
        pslverr <= 1'b0;
    else if(psel && penable && pready && error_flag)  // not required to support pslverr
        pslverr <= 1'b1;
    else 
        pslverr <= 1'b0;
end
endmodule