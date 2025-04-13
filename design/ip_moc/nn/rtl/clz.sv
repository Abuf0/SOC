module clz #(
    parameter DATA_WD = 32,
    parameter N = 8
)(
    input                               clk         ,
    input                               rstn        ,
    input                               clz_start   ,
    input        [DATA_WD-1:0]          clz_in [0:N-1]    ,
    input        [2:0]                  ClzTable [0:15],
    output logic [$clog2(DATA_WD):0]    zero_cnt[0:N-1]    ,
    output logic                        clz_vld     
);

//logic [2:0] ClzTable [0:15];

logic clz_on;
logic [1:0] tcnt;
logic [DATA_WD-1:0] data [0:N-1];

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        clz_on <= 'd0;
    else if(clz_start)
        clz_on <= 1'b1;
    else if(clz_on && (tcnt == 3))
        clz_on <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        tcnt <= 'd0;
    else if(clz_on)
        tcnt <= (tcnt == 3)?    'd0 : (tcnt+1);
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        clz_vld <= 'd0;
    else if(clz_on && (tcnt == 3))
        clz_vld <= 1'b1;
    else
        clz_vld <= 1'b0;
end


genvar i;
generate
    for(i=0;i<N;i=i+1) begin
        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                data[i] <= 'd0;
            else if(clz_start)
                data[i] <= clz_in[i];
            else if(clz_on) begin
                if((tcnt == 0) && (data[i] & 32'hffff0000) == 32'h0)
                    data[i] <= (data[i] << 16);
                else if((tcnt == 1) && (data[i] & 32'hff000000) == 32'h0)
                    data[i] <= (data[i] << 8);
                else if((tcnt == 2) && (data[i] & 32'hf0000000) == 32'h0)
                    data[i] <= (data[i] << 4);
            end
        end

        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                zero_cnt[i] <= 'd0;
            else if(clz_start)
                zero_cnt[i] <= 'd0;
            else if(clz_on) begin
                if((tcnt == 0) && (data[i] & 32'hffff0000) == 32'h0)
                    zero_cnt[i] <= zero_cnt[i] + 16;
                else if((tcnt == 1) && (data[i] & 32'hff000000) == 32'h0)
                    zero_cnt[i] <= zero_cnt[i] + 8;
                else if((tcnt == 2) && (data[i] & 32'hf0000000) == 32'h0)
                    zero_cnt[i] <= zero_cnt[i] + 4;
                else if(tcnt == 3)
                    zero_cnt[i] <= zero_cnt[i] + ClzTable[data[i] >> 28];
            end
        end
    end
endgenerate

endmodule