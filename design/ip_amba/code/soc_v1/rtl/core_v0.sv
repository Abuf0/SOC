module core_v0#(
    parameter HADDR_WIDTH = 32  ,  
    parameter DATA_WIDTH = 32   ,  
    parameter HBURST_WIDTH = 3  ,
    parameter HPROT_WIDTH = 0   ,   // 0,4,7
    parameter IRQ_LEN = 16  
)
(
    input                                  hclk        ,
    input                                  hresetn     ,
    // ------ From interconnect ------ //
    input                                  hready      ,
    input [DATA_WIDTH-1:0]                 hrdata      ,
    input                                  hresp       ,
    // ------ To interconnect ------ //
    output logic [HADDR_WIDTH-1:0]         haddr       ,
    output logic [HBURST_WIDTH-1:0]        hburst      ,
    output logic                           hmasterlock ,
    output logic [HPROT_WIDTH-1:0]         hprot       ,
    output logic [2:0]                     hsize       ,
    output logic [1:0]                     htrans      ,
    output logic [DATA_WIDTH-1:0]          hwdata      ,
    output logic [DATA_WIDTH/8-1:0]        hwstrb      ,
    output logic                           hwrite      ,      
    // TODO
    input                                  nmi         ,
    input [IRQ_LEN-1:0]                    irq         ,
    output logic                           lockup      ,
    output logic                           sleeping    ,
    output logic                           sysresetreq ,
    input                                  rx_ev       ,
    output logic                           tx_ev          
);

/* model */
assign hmaster = 8'hf2;
assign hprot = 1'b1;    // data acess
assign hnonsec = 1'b0;  // secure
assign hmasterlock = 1'b1;  // always locked
assign hwstrb = -1; // always all strobed

assign hburst = 3'b010; // WRAP-4
assign hsize = 3'b010;  // WORD

typedef enum logic [1:0] {IDLE,BUSY,NONSEQ,SEQ} state_t;
state_t state_c,state_n;
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        state_c <= IDLE;
    else 
        state_c <= state_n;
end
always @(*) begin
    if(~hresetn)
        state_n = IDLE;
    else begin
        state_n = IDLE;
        case(state_c)
            IDLE: begin
                state_n = hready?  NONSEQ:IDLE;
            end
            BUSY: begin
                if(hready) begin
                    state_n = SEQ;   // TODO
                end
                else begin
                    state_n = BUSY;
                end
            end
            NONSEQ: begin
                if(hready) begin
                    state_n = hresp?   IDLE:SEQ;
                end
                else begin
                    state_n = BUSY;
                end
            end
            SEQ:  begin
                if(hready) begin
                    if(hresp)   state_n = IDLE;
                    else        state_n = SEQ;
                end
                else begin
                    state_n = BUSY;    
                end            
            end
            default:state_n = IDLE;
        endcase
    end
end           


always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        haddr <= 32'h20000000;
    else
        haddr <= haddr+'d4;
end

assign htrans = state_c; 

always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        hwrite <= 1'b0;
    else
        hwrite <= haddr[4];
end
endmodule