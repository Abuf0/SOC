module ahb_master
#(
    parameter ADDR_WIDTH    = 16   ,   // 10~64
    parameter DATA_WIDTH    = 128  ,   // 8,16,32,64,128,256,512,1024
    parameter SLV_NUM       = 4   ,   // hsel
    parameter CMD_WIDTH     = 64    ,   // 
    parameter HBURST_WIDTH  = 3  ,   // 0,3
    parameter HPROT_WIDTH   = 0   ,   // 0,4,7
    parameter HMASTER_WIDTH = 8     // 0~8
)
(
    // ------ From system ------ //
    input                                  hclk        ,
    input                                  hresetn     ,
    input [CMD_WIDTH-1:0]                  cmd         ,
    input                                  cmd_vld     ,
    // ------ From master ------ //
    //output logic [ADDR_WIDTH-1:0]          haddr       ,
    output logic [HBURST_WIDTH-1:0]        hburst      ,
    output logic                           hmasterlock ,
    output logic [HPROT_WIDTH-1:0]         hprot       ,
    output logic [2:0]                     hsize       ,
    output logic                           hnonsec     ,
    output logic [HMASTER_WIDTH-1:0]       hmaster     ,
    output logic [1:0]                     htrans      ,
    output logic [DATA_WIDTH-1:0]          hwdata      ,
    output logic [DATA_WIDTH/8-1:0]        hwstrb      ,
    output logic                           hwrite      ,
    // ------ From interconnect ------ //
    input                                  hready      ,
    input [DATA_WIDTH-1:0]                 hrdata      ,
    input                                  hresp       ,
    // ------ To interconnect ------ //
    output logic [ADDR_WIDTH-1:0]          haddr       
);
/* AHB
-- cmd  :64bit;[63:62]:
               [61:60]:
               [59:56]:pstrb
               [55:48]:r/w ,8'b0 -> read,8'b1 -> write
               [47:32]:haddr ,  [47:46]:<00:AHB, 01:APB, 10:xx, 11:xx>
                                [45:42]:0~16 slave seletion, 
                                [41:32]:1KB
               [31: 0]:hwdata
*/

logic [CMD_WIDTH-1:0] cmd_buff;
logic cmd_vld_d1;
logic cmd_vld_sync;
logic transfer_on;
logic seq_done;
logic [1:0] scnt;

// *** cmd_vld sync ** // TODO
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        {cmd_vld_d1,cmd_vld_sync} <= 2'd0;
    else
        {cmd_vld_d1,cmd_vld_sync} <= {cmd_vld,cmd_vld_d1};
end
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        cmd_buff <= 'd0;
    else if(cmd_vld_sync)
        cmd_buff <= cmd;
end

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
                state_n = (transfer_on && hready)?  NONSEQ:IDLE;
            end
            BUSY: begin
                if(hready) begin
                    state_n = seq_done? IDLE:SEQ;   // TODO
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
                    else        state_n = seq_done? IDLE:SEQ;
                end
                else begin
                    state_n = BUSY;    
                end            
            end
            default:state_n = IDLE;
        endcase
    end
end           
/*
我感觉具体的传输模式是因地制宜的，是事前确定的，
这里选择：Four-beat wrapping burst, WRAP4
*/  
/*    
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        transfer_on <= 1'b0;
    else if(cmd_buff[47:46]==2'b00 && (cmd_buff[55:49]==8'b0 || cmd_buff[55:49]==8'b1))
        transfer_on <= 1'b1;
    else
        transfer_on <= 1'b0;
end
*/
assign transfer_on = cmd_vld_sync && (cmd[47:46]==2'b00 && (cmd[55:49]==8'b0 || cmd[55:49]==8'b1));
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        seq_done <= 1'b0;
    else if(state_c == SEQ && scnt == 2'd3)
        seq_done <= 1'b1;
    else 
        seq_done <= 1'b0;
end
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        scnt <= 2'd0;
    else if(state_n == SEQ)
        scnt <= scnt+1'b1;
    else if(state_c ==  IDLE)
        scnt <= 2'd0;
end

assign htrans = state_c;     
assign hmaster = 8'hf1;
assign hprot = 1'b1;    // data acess
assign hnonsec = 1'b0;  // secure
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        hburst <= 'd0;
    else if(state_c == IDLE && state_n != IDLE)
        hburst <= 3'b010;   // WRAP-4
end
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        hsize <= 'd0;
    else if(state_c == IDLE && state_n != IDLE)
        hsize <= 3'b010;   // WORD
end
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        hwrite <= 1'b0;
    else if(state_c == IDLE && state_n != IDLE)
        hwrite <= (cmd_buff[55:48]==8'h01)?  1'b1:1'b0;  
end
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        hwstrb <= 'd0;
    else if(state_c == IDLE && state_n != IDLE)
        hwstrb <= cmd_buff[59:56]; 
end
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        hwdata <= 'd0;
    else if(state_c == IDLE && state_n != IDLE && (cmd_buff[55:48]==8'h01))
        hwdata <= cmd_buff[31:0]; 
end
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        hmasterlock <= 1'b0;
    else if(state_c == IDLE && state_n != IDLE)
        hmasterlock <= 1'b1; 
    else if(state_n == IDLE)
        hmasterlock <= 1'b0;
end
logic [ADDR_WIDTH-1:0] haddr_next;
assign haddr_next = haddr + 'd4;
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        haddr <= 'd0;
    else if(state_c == IDLE && state_n == NONSEQ)
        haddr <= cmd_buff[47:32];   // start addr
    else if(state_n == SEQ) begin
        if(haddr[3:0] > haddr_next[3:0])    // 16-byte boundary
            haddr <= haddr_next & {{(ADDR_WIDTH-5){1'b1}},5'b01111};
    end
    else if(hresp==1'b1) begin
        haddr <= cmd_buff[47:32]; 
    end
end
endmodule