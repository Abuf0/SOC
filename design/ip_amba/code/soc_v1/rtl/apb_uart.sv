module apb_uart#(
    parameter CLK_FREQ = 20000000   ,
    parameter ADDR_WIDTH = 16       ,
    parameter DATA_WIDTH  = 32
)
(
    input                           pclk        ,
    input                           presetn     ,
    input [ADDR_WIDTH-1:0]          paddr       ,
    input                           psel        ,
    input                           penable     ,
    input                           pwrite      ,
    input [DATA_WIDTH-1:0]          pwdata      ,
    input [DATA_WIDTH/8-1:0]        pstrb       ,
    output logic                    pready_o    ,
    output logic [DATA_WIDTH-1:0]   prdata_o    ,
    input                           uart_rxd    ,
    output logic                    uart_txd
);
logic [2:0]     bps_mode        ;   // config
logic [3:0]     data_num        ;   // config
logic [1:0]     check_mode      ;   // config
logic [1:0]     stop_num        ;   // config
logic           uart_en         ;
logic [15:0]    uart_din        ;
logic           uart_tx_busy    ;
logic           tx_flag         ;
logic [15:0]    tx_data         ;
logic           uart_rx_done    ;
logic           rx_flag         ;
logic           uart_rx_busy    ;
logic           rx_err_flag     ;
logic [15:0]    rx_data         ;   

typedef enum logic [1:0] {IDLE,SETUP,WORK} state_t;
state_t state_c,state_n;

always_ff@(posedge pclk or negedge presetn) begin
    if(~presetn)
        state_c <= IDLE;
    else
        state_c <= state_n;
end

always@(*) begin
    state_n = IDLE;
    case(state_c)
        IDLE:   state_n = (psel && penable)?  SETUP:IDLE;
        SETUP:  state_n = (psel && penable)?  (setup_done?  WORK:SETUP):IDLE;
        WORK:   state_n = (psel && penable)?  WORK:IDLE;
        default:state_n = IDLE;
    endcase
end

always_ff @( posedge pclk or negedge presetn ) begin
    if(~presetn) 
        prdata_o <= 'd0;
    else if(~pwrite && (state_c == WORK))
        prdata_o <= {{(DATA_WIDTH-16){1'b0}},rx_data};
end

assign uart_din = (state_c == WORK)?  pwdata : 'd0; // TODO: pstrb

assign pready_o = ~(uart_tx_busy | uart_rx_busy);

always_ff@(posedge pclk or negedge presetn) begin
    if(~pready)
        uart_en <= 1'b0;
    else if(state_c == SETUP && setup_done)
        uart_en <= 1'b1;
    else if(state_c == IDLE)
        uart_en <= 1'b0;
end

always_ff@(posedge pclk or negedge presetn) begin
    if(~pready)
        {bps_mode,data_num,check_mode,stop_num} <= {3'd0,4'd7,2'd1,2'd0};
    else if(state_c == SETUP)
        {bps_mode,data_num,check_mode,stop_num} <= pwdata[10:0];
    else if(state_c == IDLE)    // 每次重新启动uart都会重新config一下
        {bps_mode,data_num,check_mode,stop_num} <= {3'd0,4'd7,2'd1,2'd0};
end


uart_send #(
    .CLK_FREQ ( CLK_FREQ ))
uart_sent_inst (
    .clk            ( pclk          ),
    .rstn           ( presetn       ),
    .bps_mode       ( bps_mode      ),
    .data_num       ( data_num      ),
    .check_mode     ( check_mode    ),
    .stop_num       ( stop_num      ),
    .uart_en        ( uart_en       ),
    .uart_din       ( uart_din      ),
    .uart_tx_busy   ( uart_tx_busy  ),
    .tx_flag        ( tx_flag       ),
    .tx_data        ( tx_data       ),
    .uart_txd       ( uart_txd      )
);

uart_recv #(
    .CLK_FREQ ( CLK_FREQ ))
uart_recv_inst (
    .clk           ( pclk           ),
    .rstn          ( presetn        ),
    .bps_mode      ( bps_mode       ),
    .data_num      ( data_num       ),
    .check_mode    ( check_mode     ),
    .stop_num      ( stop_num       ),
    .uart_rxd      ( uart_rxd       ),
    .uart_en       ( uart_en        ),
    .uart_rx_done  ( uart_rx_done   ),
    .rx_flag       ( rx_flag        ),
    .uart_rx_busy  ( uart_rx_busy   ),
    .rx_err_flag   ( rx_err_flag    ),
    .rx_data       ( rx_data        )
);
endmodule