module onedivonepx #(
    parameter DATA_WD = 32  ,
    parameter N = 8
)(
    input                              clk                  ,
    input                              rstn                 ,
    input                              start_trig           ,
    output logic                       mul_sat_sel          ,
    input signed [DATA_WD-1:0]         val         [0:N-1]  ,
    output logic signed [DATA_WD-1:0]  result      [0:N-1]  ,
    output logic                       result_vld           ,
    /* MUL_SAT interface */
    output logic signed [DATA_WD-1:0]  mul_sat_m1  [0:N-1]  ,
    output logic signed [DATA_WD-1:0]  mul_sat_m2  [0:N-1]  ,
    input logic signed [DATA_WD-1:0]   mul_sat_res [0:N-1]
);

parameter Q31_MIN = 32'h80000000;
parameter Q31_MAX = 32'h7fffffff;
parameter PRD_TIME = 11;
parameter thresh_2 = (1 << 29) -1;
parameter thresh_1 = (1 << 30) -1;

logic signed [DATA_WD-1:0] half_dim [0:N-1];
logic signed [DATA_WD-1:0] x [0:N-1];
logic signed [DATA_WD-1:0] mul_sat_latch [0:N-1];
logic signed [DATA_WD-1:0] half_q31_max;
logic [3:0] tcnt;
logic enable;

assign half_q31_max = 32'h40000000;

assign mul_sat_sel = enable;

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
    else if(tcnt == PRD_TIME-1)
        result_vld <= 1'b1;
    else 
        result_vld <= 1'b0;
end

genvar i;
generate
    for(i=0; i < N; i=i+1) begin
        assign half_dim[i] = (val[i] == Q31_MIN)?   -1 : ((val[i] >>> 1) + $signed(32'h40000000));
        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                x[i] <= 'sd0;
            else if(tcnt == 0)
                x[i] <= mul_sat_res[i] + 32'd1515870810;
            else if(tcnt == 3 || tcnt == 6 || tcnt == 9)
                x[i] <= (mul_sat_latch[i] >  thresh_2)?   (x[i] + Q31_MAX) :
                        (mul_sat_latch[i] < -thresh_2)?  (x[i] + Q31_MIN) : (x[i] + (mul_sat_latch[i] <<< 2));
            else if(tcnt == 10)
                x[i] <= (x[i] >  thresh_1)?  Q31_MAX :
                        (x[i] < -thresh_1)?  Q31_MIN : (x[i] <<< 1);
        end
        assign result[i] = x[i];
        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                mul_sat_latch[i] <= 'sd0;
            else if(enable)
                mul_sat_latch[i] <= mul_sat_res[i];
        end
        always@(*) begin
            case(tcnt)
                'd0: begin
                    mul_sat_m1[i] = half_dim[i];
                    mul_sat_m2[i] = -32'd1010580540;
                end
                'd1, 'd4, 'd7 : begin
                    mul_sat_m1[i] = x[i];
                    mul_sat_m2[i] = half_dim[i];
                end
                'd2, 'd5, 'd8: begin
                    mul_sat_m1[i] = x[i];
                    mul_sat_m2[i] = ((1 << 29) - mul_sat_latch[i]);
                end
                default: begin
                    mul_sat_m1[i] = 'sd0;
                    mul_sat_m2[i] = 'sd0;
                end
            endcase
        end

    end
endgenerate

endmodule