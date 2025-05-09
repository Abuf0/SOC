module variable_shift_reg#(
    parameter WIDTH = 8 ,
    parameter LEN = 3
)(
    input                       clk     ,
    input                       rstn    ,
    input                       enable  ,
    input [$clog2(LEN)-1:0]     addr    ,
    input [WIDTH-1:0]           din     ,
    output logic [WIDTH-1:0]    dout
);
logic [WIDTH-1] shifter [0:LEN-1];
genvar i;
for(i=0;i<LEN;i=i+1) begin
    if(i==0) begin
        always@(posedge clk or negedge rstn) begin
            if(~rstn)
                shifter[i] <= 'sd0;
            else if(enable)
                shifter[i] <= din;
        end
    end
    else begin
        always@(posedge clk or negedge rstn) begin
            if(~rstn)
                shifter[i] <= 'sd0;
            else if(enable)
                shifter[i] <= shifter[i-1];
        end
    end
end
assign dout = shifter[addr];
endmodule