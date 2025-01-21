module signed_divider #(
    parameter L_DIVN = 16,
    parameter L_DIVR = 5
)(
    input                       clk             ,
    input                       rstn            ,
    input [L_DIVN-1:0]          dividend        ,
    input [L_DIVR-1:0]          divisor         ,
    input                       div_din_vld     ,
    input                       div_busy        ,
    output logic [L_DIVN-1:0]   div_quotient    ,
    output logic [L_DIVR-1:0]   div_remainder   ,
    output logic                div_dout_vld    ,
    output logic                divide_by_0
);

localparam MAX_CNT = L_DIVN - L_DIVR;
localparam L_CNT   = (L_DIVN <= 16)?    4 :
                     (L_DIVN <= 32)?    5 :
                     (L_DIVN <= 64)?    6 : 7;


typedef enum logic [2:0] {IDLE, ADVIR, DIV, DOUT, ERR} state_t;
state_t state_c, state_n;

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        state_c <= IDLE;
    else
        state_c = state_n;
end

always@(*) begin
    load_words = 0;
    shift_dividend = 0;
    shift_divisor = 0;
    subtract = 0;
    div_err = 0;
    div_max = 0;
    case(state_c)
        IDLE: begin
            if(start) begin
                if(divisor == {L_DIVN{1'b0}})   begin   // 除数=0
                    state_n = ERR;
                    div_err = 1'b1;
                end
                else if(divisor == {1'b1,{L_DIVN-1{1'b0}}}) begin // 除数有符号= -2^N
                    state_n = DOUT;
                    div_max = 1'b1;
                end
                else begin
                    state_n = divisor_u[L_DIVR-2]?    DIV : ADVIR;    // 补码转到原码后的次高位
                    load_words = ~divisor_u[L_DIVR-2];
                end
            end
            else begin
                state_n = IDLE;
            end
        end
        ADVIR: begin
            state_n = DIV;
            shift_divisor = 1'b1;
        end
        DIV:
            case({max,sign_bit})
                2'b00: begin
                    state_n = DIV;
                    shift_dividend = 1'b1;
                    subtract = 1'b1;
                end
                2'b01: begin
                    state_n = DIV;
                    shift_dividend = 1'b1;
                end
                2'b10: begin
                    state_n = DOUT;
                    shift_dividend = 1'b1;
                    subtract = 1'b1;
                end
                2'b11: begin
                    state_n = DOUT;
                    shift_dividend = 1'b1;
                end
            endcase
        default:
            state_n = IDLE;
    endcase
end

assign start = div_din_vld && (state_c == IDLE);

// 被除数，除数转换，考虑到了带符号的计算// todo: FDT都是unsigned哈~
assign dividend_u = dividend[L_DIVR-1]?  (~dividend)+1'b1 : dividend;
assign divisor_u = divisor[L_DIVR-1]?  (~divisor)+1'b1 : divisor;

assign msb_divr = divisor_r[L_DIVR-2];  // 除了符号位之外的最高数据有效位bit
assign max = (num_shift_dividend == MAX_CNT + num_shift_divisor);   // 移位除到最高点，可以输出啦
assign sign_bit = comparison[L_DIVR-1]; // 符号位

assign comparison = dividend_r[L_DIVN-1:L_DIVN-L_DIVR] + {1'b1,~divisor_r[L_DIVR-2:0]} + 1'b1;  // 下一次除法的比较
assign remainder_u = dividend_r[L_DIVN-1:DIVN-L_DIVR+1] >> num_shift_divisor;

assign div_busy = (state_s != IDLE);

always@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        divisor_r           <= {L_DIVR-1{1'b0}};
        dividend_r          <= {L_DIVN{1'b0}};
        quotient_u          <= {L_DIVN-1{1'b0}};
        num_shift_dividend  <= {L_CNT{1'b0}};
        num_shift_divisor   <= {L_CNT{1'b0}};
        neg_flag_q          <= 1'b0;
        neg_flag_r          <= 1'b0;
    end
    else if(div_err) begin
        dividend_r          <= {L_DIVN{1'b0}};
        quotient_u          <= {L_DIVN-1{1'b0}};
        num_shift_divisor   <= {L_CNT{1'b0}};
        neg_flag_q          <= 1'b0;
        neg_flag_r          <= 1'b0;
    end
    else if(div_max) begin
        dividend_r          <= {dividend_u[L_DIVR-2:0], {L_DIVN+1-L_DIVR{1'b0}}};
        quotient_u          <= {{L_DIVR-1{1'b0}}, dividend_u[L_DIVN-2:L_DIVR-1]};
        num_shift_divisor   <= {L_CNT{1'b0}};
        neg_flag_q          <= ~dividend[L_DIVN-1];
        neg_flag_r          <= dividend[L_DIVN-1];
    end
    else if(load_words) begin
        divisor_r           <= divisor_u  ;
        dividend_r          <= dividend_u[L_DIVR-2:0] ;
        quotient_u          <= {L_DIVN-1{1'b0}};
        num_shift_dividend  <= {L_CNT{1'b0}};
        num_shift_divisor   <= {L_CNT{1'b0}};
        neg_flag_q          <= dividend[L_DIVN-1]^divisor[L_DIVR-1];
        neg_flag_r          <= dividend[L_DIVN-1];
    end
    else if(shift_divisor) begin 
        divisor_r           <= divisor_r << num_shift_divisor_t;
        num_shift_divisor   <= num_shift_divisor_t;
    end
    else if(shift_dividend) begin
        if(subtract) begin
            dividend_r <= {comparison[L_DIVR-2:0], dividend_r[L_DIVN-L_DIVR-1:0], 1'b0};
            quotient_u <= {quotient_u[L_DIVN-3:0], 1'b1};
        end
        else begin
            dividend_r <= dividend_r<<1;
            quotient_u <= quotient_u<<1;
        end
        
    end
end

always@(*) begin
    num_shift_divisor_t = {L_CNT{1'b0}};
    for(int i=0; i<L_DIVR-1; i++) begin
        if(divisor_r[L_DIVR-2-i]) begin
            num_shift_divisor_t = i;
            break;
        end
    end
end

always@(posedge clk or negedge rstn) begin
    if(~rstn) 
        divide_by_0 <= 1'b0;
    else if(state_s == ERR)
        divide_by_0 <= 1'b1;
    else
        divide_by_0 <= 1'b0;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn) 
        div_dout_vld <= 1'b0;
    else if(state_s == ERR || state_s == DOUT)
        div_dout_vld <= 1'b1;
    else
        div_dout_vld <= 1'b0;
end

always@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        div_quotient  <= {L_DIVN{1'b0}};
        div_remainder <= {L_DIVR{1'b0}};
    end
    else if(load_words) begin
        div_quotient  <= {L_DIVN{1'b0}};
        div_remainder <= {L_DIVR{1'b0}};
    end
    else if(state_s == ERR || state_s == DOUT) begin
        div_quotient  <= neg_flag_q?    {1'b1, ~quotient_u }+1'b1 : {1'b0,quotient_u };
        div_remainder <= neg_flag_r?    {1'b1, ~remainder_u}+1'b1 : {1'b0,remainder_u};
    end
end

endmodule