module exp_on_neg #(
    parameter DATA_WD = 32,
    parameter N = 8
)(
    input                              clk                 ,
    input                              rstn                ,
    input                              start_trig          ,
    input signed [DATA_WD-1:0]         val         [0:N-1] ,
    output logic signed [DATA_WD-1:0]  result      [0:N-1] ,
    output logic                       result_vld          ,
    /* MUL_SAT interface */
    output logic                       mul_sat_sel         ,
    output logic signed [DATA_WD-1:0]  mul_sat_m1  [0:N-1] ,
    output logic signed [DATA_WD-1:0]  mul_sat_m2  [0:N-1] ,
    input logic signed [DATA_WD-1:0]   mul_sat_res [0:N-1] ,
    /* todo ADD interface */
    output logic                       add_sel             ,
    output logic signed [DATA_WD-1:0]  add_a       [0:N-1] ,
    output logic signed [DATA_WD-1:0]  add_b       [0:N-1] ,
    input signed [DATA_WD-1:0]         add_sum     [0:N-1] 

);
parameter PRD_TIME = 19;
parameter Q31_MIN = 32'h80000000;
parameter Q31_MAX = 32'h7fffffff;

logic signed [DATA_WD-1:0] val_mod_minus_quarter [0:N-1];
logic signed [DATA_WD-1:0] remainder [0:N-1];
logic signed [DATA_WD-1:0] x [0:N-1];
logic signed [DATA_WD-1:0] x2 [0:N-1];
logic signed [DATA_WD-1:0] mul_sat_x2_x[0:N-1];
logic signed [DATA_WD-1:0] mul_sat_x2_x2[0:N-1];
logic signed [DATA_WD-1:0] mul_sat_x[0:N-1];
//logic signed [DATA_WD-1:0] mul_sat_res[0:N-1];
logic signed [DATA_WD-1:0] div_pow2_mul_sat_x2_x2[0:N-1];
logic signed [DATA_WD-1:0] div_pow2_mul_sat[0:N-1];
logic signed [DATA_WD-1:0] adder_out_1[0:N-1];
logic signed [DATA_WD-1:0] remainder [0:N-1];
logic [DATA_WD-1:0] mask[0:N-1];
logic [DATA_WD-1:0] shift;

logic [4:0] tcnt;
logic enable;
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        enable <= 1'b0;
    else if(start_trig)
        enable <= 1'b1;
    else if(result_vld)
        enable <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        tcnt <= 'd0;
    else if(enable)
        tcnt <= (tcnt == PRD_TIME-1)?   'd0 : tcnt+1;
    else
        tcnt <= 'd0;    // use enable negedge clear
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        result_vld <= 1'b0;
    else if(tcnt == 18)
        result_vld <= 1'b1;
    else 
        result_vld <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        shift <= 'd0;
    else if(tcnt==0)
        shift <= 'd24;
    else if(tcnt >= 11)
        shift <= shift + 1;
end

assign mul_sat_sel = enable && ((tcnt == 1) || (tcnt == 2) || (tcnt == 3) || (tcnt == 5) || (tcnt == 8) || (tcnt >= 11));
assign add_sel = enable && ((tcnt == 4) || (tcnt == 6) || (tcnt == 7) || (tcnt == 9) || (tcnt == 10));

genvar i;
generate
    for(i=0; i < N; i=i+1) begin
        assign val_mod_minus_quarter[i] = val[i][23:0] - (1 << 24);
        //assign x[i] = (val_mod_minus_quarter[i] <<< 5) + (1 << 28);
        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                x[i] <= 'sd0;
            else if(tcnt == 0)
                x[i] <= (val_mod_minus_quarter[i] <<< 5) + (1 << 28);
        end
        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                x2[i] <= 'sd0;
            else if(tcnt == 1)
                x2[i] <= mul_sat_res[i];
        end
        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                mul_sat_x2_x[i] <= 'sd0;
            else if(tcnt == 2 || tcnt == 5 || tcnt == 8)
                mul_sat_x2_x[i] <= mul_sat_res[i];
        end
        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                mul_sat_x2_x2[i] <= 'sd0;
            else if(tcnt == 3)
                mul_sat_x2_x2[i] <= mul_sat_res[i];
        end
        assign div_pow2_mul_sat_x2_x2[i] = mul_sat_x2_x2[i][1]?  (mul_sat_x2_x2[i][DATA_WD-1]?  (mul_sat_x2_x2[i] >>> 2)-1 : (mul_sat_x2_x2[i] >>> 2)+1) : (mul_sat_x2_x2[i] >>> 2);
        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                adder_out_1[i] <= 'sd0;
            else if(tcnt == 4 || tcnt ==6 || tcnt == 7 | tcnt ==9 | tcnt == 10)
                adder_out_1[i] <= add_sum[i];
        end
        //always_ff@(posedge clk or negedge rstn) begin
        //    if(~rstn)
        //        mul_sat_x[i] <= 'sd0;
        //    else if(tcnt == 5)
        //        mul_sat_x[i] <= mul_sat_res[i];
        //end
        assign mul_sat_x[i] = mul_sat_x2_x[i];  // tcnt = 5
        assign div_pow2_mul_sat[i] = adder_out_1[i][0]?  (adder_out_1[i][DATA_WD-1]?  (adder_out_1[i] >>> 1)-1 : (adder_out_1[i] >>> 1)+1) : (adder_out_1[i] >>> 1);
        //always_ff@(posedge clk or negedge rstn) begin
        //    if(~rstn)
        //        mul_sat_res[i] <= 'sd0;
        //    else if(tcnt == 7)
        //        mul_sat_res[i] <= mul_sat_res[i];
        //end
        //assign mul_sat_res[i] = mul_sat_x2_x[i];    // tcnt = 7
        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                result[i] <= 'sd0;
            else if(tcnt == 9)
                result[i] <= add_sum[i];
            else if(tcnt >= 11 && tcnt <= 17)
                result[i] <= (mask[i] & mul_sat_res[i]) ^ (~mask[i] & result[i]);
            else if(tcnt == 18)
                result[i] <= (val[i] == 0)?  Q31_MAX : result[i];
        end
        assign mask[i] = (remainder[i][shift] != 0)?    ~0 : 0;
        assign remainder[i] = adder_out_1[i];   // tcnt >= 10
        always@(*) begin
            case(tcnt)
                'd1: begin
                    mul_sat_m1[i] = x[i];
                    mul_sat_m2[i] = x[i];
                end
                'd2: begin
                    mul_sat_m1[i] = x2[i];
                    mul_sat_m2[i] = x[i];
                end
                'd3: begin
                    mul_sat_m1[i] = x2[i];
                    mul_sat_m2[i] = x2[i];
                end
                'd5: begin
                    mul_sat_m1[i] = adder_out_1[i];
                    mul_sat_m2[i] = 32'd715827883;
                end
                'd8: begin
                    mul_sat_m1[i] = 32'd1895147668;
                    mul_sat_m2[i] = adder_out_1[i];
                end
                'd11: begin 
                    mul_sat_m1[i] = result[i];
                    mul_sat_m2[i] = 32'd1672461947;
                end
                'd12: begin 
                    mul_sat_m1[i] = result[i];
                    mul_sat_m2[i] = 32'd1302514674;
                end
                'd13: begin 
                    mul_sat_m1[i] = result[i];
                    mul_sat_m2[i] = 32'd790015084;
                end
                'd14: begin 
                    mul_sat_m1[i] = result[i];
                    mul_sat_m2[i] = 32'd290630308;
                end
                'd15: begin 
                    mul_sat_m1[i] = result[i];
                    mul_sat_m2[i] = 32'd39332535;
                end
                'd16: begin 
                    mul_sat_m1[i] = result[i];
                    mul_sat_m2[i] = 32'd720401;
                 end
                'd17: begin 
                    mul_sat_m1[i] = result[i];
                    mul_sat_m2[i] = 32'd242;
                end
                default: begin
                    mul_sat_m1[i] = 'sd0;
                    mul_sat_m2[i] = 'sd0;
                end
            endcase
        end
        always@(*) begin
            case(tcnt)
                'd4: begin
                    add_a[i] = mul_sat_x2_x[i];
                    add_b[i] = div_pow2_mul_sat_x2_x2[i];
                end
                'd6: begin
                    add_a[i] = mul_sat_x2_x[i];
                    add_b[i] = x2[i];
                end
                'd7: begin
                    add_a[i] = x[i];
                    add_b[i] = div_pow2_mul_sat[i];
                end
                'd9: begin
                    add_a[i] = 32'd1895147668;
                    add_b[i] = mul_sat_x2_x[i];
                end
                'd10: begin
                    add_a[i] = val_mod_minus_quarter[i];
                    add_b[i] = -val[i];
                end
                default: begin
                    add_a[i] = 'sd0;
                    add_b[i] = 'sd0;
                end
            endcase
        end
    end
endgenerate

endmodule