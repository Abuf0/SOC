module uart_recv#(
    parameter CLK_FREQ = 50000000              //系统时钟频率
)
(
    input	                clk         ,   //系统时钟
    input                   rstn        ,   //系统复位，低电平有效
    input  [2:0]            bps_mode    ,   // 0:9600,1:19200,2-38400,3-115200,4-230400,5-460800,6-921600
    input  [3:0]            data_num    ,   // 支持1~16bit
    input  [1:0]            check_mode  ,   // 支持00-disable，01-奇校验，10-偶校验，11-Reserved
    input  [1:0]            stop_num    ,   // 支持1~4
    input                   uart_rxd    ,
    input                   uart_en     ,
    output logic            uart_rx_done,
    output logic            rx_flag     ,
    output logic            uart_rx_busy,
    output logic            rx_err_flag ,
    output logic [15:0]     rx_data     
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
        2'd1:   uart_check_bit = ~(^rx_data);
        2'd2:   uart_check_bit = ^rx_data;
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
always@(*) begin
    state_n = IDLE;
    case(state_c)
        IDLE:   state_n = uart_en?  START:IDLE;
        START:  state_n = ~uart_rxd? TRANS:START;
        TRANS:  state_n = trans_done? (check_en?  CHECK:DONE):TRANS;
        CHECK:  state_n = check_done?   DONE:CHECK;
        DONE:   state_n = stop_done?    IDLE:DONE;
        default:state_n = IDLE;
    endcase
end
//always@(*) begin
//    state_n = IDLE;
//    case(state_c)
//        IDLE:   state_n = uart_en?  START:IDLE; // uart_en会和busy握手
//        START:  state_n = TRANS;
//        TRANS:  state_n = trans_done? (check_en?  CHECK:DONE):TRANS;
//        CHECK:  state_n = check_done?   DONE:CHECK;
//        DONE:   state_n = stop_done?    IDLE:DONE;
//        default:state_n = IDLE;
//    endcase
//end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)   
        rx_data <= 'd0;
    else if((state_c == TRANS) && bps_en) 
        rx_data <= {rx_data[14:0],uart_rxd};
    else if(state_c == IDLE)
        rx_data <= 'd0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)   
        rx_err_flag <= 1'b0;
    else if(state_c == IDLE)
        rx_err_flag <= 1'b0;
    else if(state_c == CHECK && bps_en)
        rx_err_flag <= (uart_check_bit != uart_rxd);
end

assign trans_done = (bcnt == data_num);
assign check_en = |check_mode;
assign check_done = 1'b1;
assign stop_done = (bcnt == stop_num);

assign rx_flag = (state_c!=IDLE);
//assign uart_rx_busy = (state_c!=IDLE);

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        uart_rx_busy <= 1'b0;
    else if(uart_en)
        uart_rx_busy <= 1'b1;
    else if(state_c == IDLE)
        uart_rx_busy <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        uart_rx_done <= 1'b0;
    else if(state_c == DONE)
        uart_rx_done <= 1'b1;
    else if(state_c == IDLE)
        uart_rx_done <= 1'b0;
end

endmodule