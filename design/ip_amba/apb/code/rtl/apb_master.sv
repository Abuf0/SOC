module apb_master #(
    parameter CMD_WIDTH  = 64,
    parameter ADDR_WIDTH = 16,  // max = 32
    parameter DATA_WIDTH = 32,  // 8,16,32
    parameter SLV_NUM    = 4
)
(
    input                           pclk    ,   // From system
    input                           presetn ,   // From system
    input [CMD_WIDTH-1:0]           cmd     ,   // From system
    input                           cmd_vld ,   // From system
    output logic [ADDR_WIDTH-1:0]   paddr   ,   // To slave
    output logic [2:0]              pprot   ,   // To slave     // TODO
    output logic                    pnse    ,   // To slave     // TODO
    output logic [SLV_NUM-1:0]      psel    ,   // To slave     
    output logic                    penable ,   // To slave
    output logic                    pwrite  ,   // To slave
    output logic [DATA_WIDTH-1:0]   pwdata  ,   // To slave
    output logic [DATA_WIDTH/8-1:0] pstrb   ,   // To slave
    input                           pready  ,   // From slave
    input [DATA_WIDTH-1:0]          prdata  ,   // From slave
    input                           pslverr ,   // From slave   // TODO
    output logic                    pwakeup     // To slave     // TODO
    // *** USER DEFINE *** // 
);
/* APB
-- cmd  :64bit;[63:62]:
               [61:60]:
               [59:56]:pstrb
               [55:48]:r/w ,8'b0 -> read,8'b1 -> write
               [47:32]:paddr ,  [47:46]:<00:AHB, 01:APB, 10:xx, 11:xx>
                                [45:42]:0~16 slave seletion, 
                                [41:32]:1KB
               [31: 0]:pwdata
*/

logic [CMD_WIDTH-1:0] cmd_buff;
logic cmd_vld_d1;
logic cmd_vld_sync;
logic transfer_on;
logic next_transfer_on;

// *** cmd_vld sync ** // TODO
always_ff@(posedge pclk or negedge presetn) begin
    if(~presetn)
        {cmd_vld_d1,cmd_vld_sync} <= 2'd0;
    else
        {cmd_vld_d1,cmd_vld_sync} <= {cmd_vld,cmd_vld_d1};
end
always_ff@(posedge pclk or negedge presetn) begin
    if(~presetn)
        cmd_buff <= 'd0;
    else if(cmd_vld_sync)
        cmd_buff <= cmd;
end
typedef enum logic [1:0] {IDLE,SETUP,ACCESS} state_t;
state_t state_c,state_n;
always_ff@(posedge pclk or negedge presetn) begin
    if(~presetn)
        state_c <= IDLE;
    else 
        state_c <= state_n;
end
always @(*) begin
    if(~presetn)
        state_n = IDLE;
    else begin
        state_n = IDLE;
        case(state_c)
            IDLE:   state_n = transfer_on?   SETUP:IDLE;
            SETUP:  state_n = ACCESS;
            ACCESS: begin
                if(~pready)
                    state_n = ACCESS;
                else begin
                    if(cmd_vld_sync) 
                        state_n = next_transfer_on? SETUP:IDLE;
                    else 
                        state_n = ACCESS;
                end
            end
            default:state_n = IDLE;
        endcase
    end
end                 
always_ff@(posedge pclk or negedge presetn) begin
    if(~presetn)
        transfer_on <= 1'b0;
    else if(cmd_buff[47:46]==2'b01 && (cmd_buff[55:48]==8'b0 || cmd_buff[55:48]==8'b1))
        transfer_on <= 1'b1;
    else
        transfer_on <= 1'b0;
end
assign next_transfer_on = (cmd[47:46]==2'b01 && (cmd[55:48]==8'b0 || cmd[55:48]==8'b1));
always_ff@(posedge pclk or negedge presetn) begin
    if(~presetn)
        psel <= 'd0;
    else if(state_c == IDLE && transfer_on)
        psel <= cmd_buff[43:42];
    else if(state_c == IDLE && ~transfer_on)
        psel <= 'd0;
end
always_ff@(posedge pclk or negedge presetn) begin
    if(~presetn)
        paddr <= 'd0;
    else if(state_c == SETUP)
        paddr <= cmd_buff[47:32];
end
always_ff@(posedge pclk or negedge presetn) begin
    if(~presetn)
        pwdata <= 'd0;
    else if(state_c == SETUP)
        pwdata <= cmd_buff[31:0];
end
always_ff@(posedge pclk or negedge presetn) begin
    if(~presetn)
        pwrite <= 'd0;
    else if(state_c == SETUP) begin
        if(cmd_buff[55:48]==8'h0)
            pwrite <= 1'b0;
        else if(cmd_buff[55:48]==8'h01)
            pwrite <= 1'b1;
        // else (not need)
    end
end
always_ff@(posedge pclk or negedge presetn) begin
    if(~presetn)
        pstrb <= 'd0;
    else if(state_c == SETUP)
        pstrb <= cmd_buff[59:56];
end
always_ff@(posedge pclk or negedge presetn) begin
    if(~presetn)
        penable <= 1'b0;
    else if(state_c == SETUP)
        penable <= 1'b1;
    else if(state_c == ACCESS && state_n != ACCESS)
        penable <= 1'b0;
end
assign pprot    = 1'b0;
assign pnse     = 1'b0;
assign pwakeup  = 1'b0;
endmodule