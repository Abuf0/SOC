module ahb2apb_bridge #(
    parameter HADDR_WIDTH   = 32    ,  // max = 32
    parameter PADDR_WIDTH   = 16    ,
    parameter DATA_WIDTH    = 32    ,  // 8,16,32
    parameter HBURST_WIDTH  = 3     ,   // 0,3
    parameter PSLV_NUM      = 5     ,
    parameter PSLV_LEN      = 32
)
(
    // with AHB
    input                           hclk                    ,   // From AHB
    input                           hresetn                 ,   // From AHB
    input [HADDR_WIDTH-1:0]         haddr                   ,   // From AHB
    input [HBURST_WIDTH-1:0]        hburst                  ,   // From AHB
    input [2:0]                     hsize                   ,   // From AHB
    input [1:0]                     htrans                  ,   // From AHB
    input [DATA_WIDTH-1:0]          hwdata                  ,   // From AHB
    input [DATA_WIDTH/8-1:0]        hwstrb                  ,   // From AHB
    input                           hwrite                  ,   // From AHB
    input                           hsel_i                  ,   // From AHB
    input                           hready_i                ,   // From AHB
    output logic                    hready_o                ,   // To AHB
    output logic                    hresp_o                 ,   // To AHB
    output logic                    hexokay_o               ,   // To AHB
    output logic [DATA_WIDTH-1:0]   hrdata_o                ,   // To AHB
    // with APB         
    input                           pclk                    ,   // From APB
    input                           presetn                 ,   // From APB
    output logic [PADDR_WIDTH-1:0]  paddr                   ,   // To APB
    output logic [PSLV_NUM-1:0]     psel                    ,   // To APB
    output logic                    penable                 ,   // To APB
    output logic                    pwrite                  ,   // To APB
    output logic [DATA_WIDTH-1:0]   pwdata                  ,   // To APB
    output logic [DATA_WIDTH/8-1:0] pstrb                   ,   // To APB
    input                           pready_i [0:PSLV_LEN-1] ,   // From APBs
    input [DATA_WIDTH-1:0]          prdata_i [0:PSLV_LEN-1]      // From APBs
);

/* APB Slave List */
// 0. UART                               0x40000000~0x4000ffff
// 1. SPI                                0x40010000~0x4001ffff
// 2. I2C                                0x40020000~0x4002ffff  
// 3. Memory                             0x40030000~0x4003ffff  
// 4. LED                                0x40040000~0x4004ffff   
// Reserved

logic [PSLV_NUM-1:0] psel_tmp;
always@(*) begin
    case(haddr[PADDR_WIDTH+15:PADDR_WIDTH])
        16'h0:  psel_tmp = 'b1;
        16'h1:  psel_tmp = 'b10;
        16'h2:  psel_tmp = 'b100;
        16'h3:  psel_tmp = 'b1000;
        16'h4:  psel_tmp = 'b10000;
        default:psel_tmp = 'b0;
    endcase
end

typedef enum logic [1:0] {IDLE,SETUP,ACCESS} state_t;
state_t state_c,state_n;
always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        state_c <= IDLE;
    else 
        state_c <= state_n;
end

always@(*) begin
    state_n = IDLE;
    case(state_c)
        IDLE:   state_n = hsel_i?   SETUP:IDLE;
        SETUP:  state_n = hready_i? ACCESS:SETUP;
        ACCESS: state_n = hsel_i?   ACCESS:IDLE;
        default:state_n = IDLE;
    endcase
end
always_ff@(posedge pclk or negedge presetn) begin
    if(~presetn) begin
        paddr <= 'd0;
        psel <= 'd0;
        penable <= 'd0;
        pwrite <= 'd0;
        pwdata <= 'd0;
        pstrb <= 'd0;
    end
    else if(state_c == IDLE)   begin
        paddr <= 'd0;
        psel <= 'd0;
        penable <= 'd0;
        pwrite <= 'd0;
        pwdata <= 'd0;
        pstrb <= 'd0;
    end
    else if(state_c == SETUP)  begin    // Lock AHB information
        paddr <= haddr[PADDR_WIDTH-1:0];
        //psel <= ({{(PSLV_NUM-1){1'b0}},1'b1} << haddr[PADDR_WIDTH+3:PADDR_WIDTH]);
        psel <= psel_tmp;
        penable <= 1'b1;
        pwrite <= hwrite;
        pwdata <= hwdata;
        pstrb <= hwstrb;
    end
end

always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        hrdata_o <= 'd0;
    else if(state_c == ACCESS)
        hrdata_o <= prdata_i[psel];
end

always_ff@(posedge hclk or negedge hresetn) begin
    if(~hresetn)
        hready_o <= 1'b1;
    else if(state_c == ACCESS)
        hready_o <= pready_i[psel];
    else 
        hready_o <= 1'b1;
end

assign hresp_o   = 1'b0;
assign hexokay_o = 1'b1;

endmodule