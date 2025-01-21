module Sqrt_unsigned(
    input               clk        , 
    input               rstn       ,     
    input [31:0]        din        ,      
    input               din_vld    ,     
    output logic [15:0] dout       ,       
    output logic        dout_vld        
);

always@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        root <= 16'h0;
        rem_1 <= 16'h0;
        cnt <= 4'd0;
        work_p <= 1'b0;
        detain <= 32'h0;
    end
    else begin
        if(din_vld) begin
            detain <= din<<<2;
        end
        if(din_vld) begin
            work_p <= 1'b1;
        end
        else if(cnt_ov) begin
            work_p <= 1'b0;
        end
        if(work) begin
            if(cnt_ov) begin
                cnt <= 4'd0;
            end
            else begin
                cnt <= cnt + 4'd1;
            end
        end
        if(work_p) begin
            detain <= detain <<< 2;
            if(if1<=temp_rem) begin
                root <= (tmp_root | 16'h1);
                rem_1 <= temp_rem - if1;
            end
            else begin
                root <= (root <<< 1);
                rem_1 <= temp_rem;
            end
        end
        else begin
            if(work_neg) begin
                root <= 16'h0;
                rem_1 <= 16'h0;
            end
        end
    end
end

always@(posedge clk or negedge rstn) begin
    if(~rstn)
        work_neg <= 1'b0;
    else if(cnt_ov)
        work_neg <= 1'b1;
    else
        work_neg <= 1'b0;
end

assign dout_vld = work_neg;
assign dout = dout_vld? root : 16'h0;

endmodule