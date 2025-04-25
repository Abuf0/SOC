module sqrtu64 #(
    parameter DATA_WD = 64
)(
    input                           clk            ,
    input                           rstn           ,
    input                           sqrt_in_vld    ,
    input [DATA_WD-1:0]             sqrt_in        ,
    output logic [DATA_WD/2-1:0]    sqrt_out       ,
    output logic                    sqrt_out_vld   
);

logic [DATA_WD-1:0] temp;
logic [DATA_WD-1:0] data_temp;
logic [$clog2(DATA_WD)-2:0] vbit;
logic [DATA_WD-1:0] vdelt;
logic skip;
logic sqrt_on;

// ADDs behaviour model //
logic signed [DATA_WD-1:0] add1_a;
logic signed [DATA_WD-1:0] add1_b;
logic signed [DATA_WD-1:0] add1_sum;
logic signed [DATA_WD-1:0] add2_a;
logic signed [DATA_WD-1:0] add2_b;
logic signed [DATA_WD-1:0] add2_sum;
logic signed [DATA_WD-1:0] add3_a;
logic signed [DATA_WD-1:0] add3_b;
logic signed [DATA_WD-1:0] add3_sum;
assign add1_sum = add1_a + add1_b;
assign add2_sum = add2_a + add2_b;
assign add3_sum = add3_a + add3_b;
// end //

assign skip = sqrt_in_vld && (sqrt_in <= 1);
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        sqrt_on <= 1'b0;
    else if(sqrt_in_vld)
        sqrt_on <= 1'b1;
    else if(sqrt_out_vld)
        sqrt_on <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        sqrt_out_vld <= 1'b0;
    else if(sqrt_in_vld && skip)
        sqrt_out_vld <= 1'b1;
    else if(sqrt_on && (vbit == 0))
        sqrt_out_vld <= 1'b1;
    else
        sqrt_out_vld <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        vbit <= -1;
    else if(sqrt_out_vld)
        vbit <= -1;
    else if(sqrt_on)
        vbit <= vbit - 1;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        vdelt <= (1 << (DATA_WD/2-1));
    else if(sqrt_out_vld)
        vdelt <= (1 << (DATA_WD/2-1));
    else if(sqrt_on)
        vdelt <= (vdelt >> 1);
end

assign add1_a = (sqrt_out << 1);
assign add1_b = vdelt;
assign temp = (add1_sum << vbit);
//assign temp = (((sqrt_out << 1) + vdelt) << vbit);  // todo ADD64

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_temp <= 'd0;
    else if(sqrt_in_vld)
        data_temp <= sqrt_in;
    else if(sqrt_on && (data_temp >= temp))
        //data_temp <= data_temp - temp;  // todo ADD64
        data_temp <= add2_sum;
end 
assign add2_a = data_temp;
assign add2_b = -temp;

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        sqrt_out <= 'd0;
    else if(sqrt_in_vld)
        sqrt_out <= skip?   sqrt_in : 'd0;
    else if(sqrt_on && (data_temp >= temp))
        //sqrt_out <= sqrt_out + vdelt;  // todo ADD64
        sqrt_out <= add3_sum;
end 
assign add3_a = sqrt_out;
assign add3_b =  vdelt;

endmodule