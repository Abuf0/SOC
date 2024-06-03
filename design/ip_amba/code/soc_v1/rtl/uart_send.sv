module uart_send#(
    parameter CLK_FREQ = 50000000              //系统时钟频率
)
(
    input	                clk         ,   //系统时钟
    input                   rstn        ,   //系统复位，低电平有效
    input  [2:0]            bps_mode    ,   // 0:9600,1:19200,2-38400,3-115200,4-230400,5-460800,6-921600
    input  [3:0]            data_num    ,   // 支持1~16bit
    input  [1:0]            check_mode  ,   // 支持00-disable，01-奇校验，10-偶校验，11-Reserved
    input  [1:0]            stop_num    ,   // 支持1~4
    input                   uart_en     ,   //发送使能信号
    input  [15:0]           uart_din    ,   //待发送数据
    output logic            uart_tx_busy,   //发送忙状态标志 
    //output                  en_flag     ,
    output  logic           tx_flag     ,   //发送过程标志信号
    output  logic [15:0]    tx_data     ,   //寄存发送数据
    //output  logic [3:0]     tx_cnt      ,   //发送数据计数器
    output  logic           uart_txd        //UART发送端口
);
// 起始位：通常1bit-0
// 数据位：5,6,7,8-bit
// 停止位：N个高电平（常用1，2）
//localparam BPS_CNT = CLK_FREQ/UART_BPS;
logic [15:0] bps_cnt;
logic [15:0] uart_bps;
logic [15:0] tcnt;
logic [4:0] bcnt;
logic [15:0] data_mask;
logic [15:0] tx_data_shift;
logic bps_en;
logic trans_done;
logic check_en;
logic check_done;
logic stop_done;
logic uart_check_bit;

typedef enum logic [2:0] {IDLE,START,TRANS,CHECK,DONE} state_t;
state_t state_c,state_n;

assign bps_cnt = CLK_FREQ/uart_bps/100;
always@(*) begin
    uart_bps = 'd96;
    case(bps_mode)
        'd0:    uart_bps = 'd96;
        'd1:    uart_bps = 'd192;
        'd2:    uart_bps = 'd384;
        'd3:    uart_bps = 'd1152;
        'd4:    uart_bps = 'd2304;
        'd5:    uart_bps = 'd4608;
        'd6:    uart_bps = 'd9216;
        default:uart_bps = 'd96;
    endcase
end
always@(*) begin
    uart_check_bit = 1'b0;
    case(check_mode)
        2'd1:   uart_check_bit = ~(^tx_data);
        2'd2:   uart_check_bit = ^tx_data;
        default:uart_check_bit = 1'b0;
    endcase
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        tcnt <= 'd0;
    else if(tcnt == bps_cnt)
        tcnt <= 'd0;
    else
        tcnt <= tcnt+1'b1;
end
assign bps_en = (tcnt == bps_cnt);

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        bcnt <= 'd0;
    else if((state_c != state_n) && bps_en)
        bcnt <= 'd0;
    else if(bps_en)
        bcnt <= bcnt+1'b1;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        state_c <= IDLE;
    else if(bps_en)
        state_c <= state_n;
end
//always@(*) begin
//    state_n = IDLE;
//    case(state_c)
//        IDLE:   state_n = uart_en?  START:IDLE;
//        START:  state_n = ~sta_bit? TRANS:START;
//        TRANS:  state_n = trans_done? (check_en?  CHECK:DONE):TRANS;
//        CHECK:  state_n = check_done?   DONE:CHECK;
//        DONE:   state_n = done_done?    IDLE:DONE;
//        default:state_n = IDLE;
//    endcase
//end
always@(*) begin
    state_n = IDLE;
    case(state_c)
        IDLE:   state_n = uart_en?  START:IDLE; // uart_en会和busy握手
        START:  state_n = TRANS;
        TRANS:  state_n = trans_done? (check_en?  CHECK:DONE):TRANS;
        CHECK:  state_n = check_done?   DONE:CHECK;
        DONE:   state_n = stop_done?    IDLE:DONE;
        default:state_n = IDLE;
    endcase
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        uart_txd <= 1'b1;
    else if(state_c == START)
        uart_txd <= 1'b0;
    else if(state_c == TRANS)
        uart_txd <= tx_data_shift[15];
    else if(state_c == CHECK)
        uart_txd <= uart_check_bit;
    else if(state_c == DONE)
        uart_txd <= 1'b1;
    else
        uart_txd <= 1'b1;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        tx_data <= 'd0;
    else if(state_c == START)
        tx_data <= uart_din & data_mask;
end
assign data_mask = (16'b1 << (data_num)) - 1'b1;

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        tx_data_shift <= 'd0;
    else if(state_c == START)
        tx_data_shift <= (tx_data<<(4'd15-data_num));
    else if((state_c == TRANS) && bps_en)
        tx_data_shift <= {tx_data_shift[14:0],1'b0};
end

assign trans_done = (bcnt == data_num);
assign check_en = |check_mode;
assign check_done = 1'b1;
assign stop_done = (bcnt == stop_num);

assign tx_flag = (state_c!=IDLE);

//assign uart_tx_busy = (state_c!=IDLE);

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        uart_tx_busy <= 1'b0;
    else if(state_n == START)
        uart_tx_busy <= 1'b1;
    else if(state_n == IDLE)
        uart_tx_busy <= 1'b0;
end

endmodule