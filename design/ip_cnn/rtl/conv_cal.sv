module conv_cal#(
    parameter KSIZE     = 3     ,
    parameter IN_WMAX   = 224       // include padding
)(
    input                       clk                      ,
    input                       rstn                     ,
    //input                       conv_enable              ,
    input        [9:0]          in_width                 ,  // todo, include padding
    input signed [7:0]          weight [0:KSIZE*KSIZE-1] ,
    input signed [7:0]          data                     ,
    input                       data_in_vld              ,
    input                       mac_shift_en             ,
    output logic signed [19:0]  mac_sum_out              ,
    output logic                mac_sum_out_vld
);



// 单通道
logic signed [19:0] mac_sum_tmp_in [0:KSIZE*KSIZE-1];
logic signed [19:0] mac_sum_tmp_out [0:KSIZE*KSIZE-1];
logic mac_sum_tmp_out_vld [0:KSIZE*KSIZE-1];

logic signed [19:0] mac_sum_tmp_shifter [0:IN_WMAX+1-KSIZE] [0:KSIZE-1-1];
logic signed [19:0] mac_sum_tmp_shift_in [0:KSIZE-1-1];


genvar i;
generate 
    for(i=0;i<KSIZE*KSIZE;i=i+1) begin
        if(i==0) begin
            assign mac_sum_tmp_in[i] = 'sd0;
        end
        else if(i%KSIZE != 0) begin
            assign mac_sum_tmp_in[i] = mac_sum_tmp_out[i-1];
            if(i%KSIZE == KSIZE-1) begin
                assign mac_sum_tmp_shift_in[i/KSIZE] = mac_sum_tmp_out[i];
            end
        end
        else begin
            assign mac_sum_tmp_in[i] = mac_sum_tmp_shifter[in_width+1-KSIZE][i/KSIZE-1];   
        end

        mac_unit mac_uint_inst(
            .clk            (clk                    ),
            .rstn           (rstn                   ),
            .in_vld         (data_in_vld            ),
            .mult_a         (data                   ),
            .mult_b         (weight[i]              ),
            .c_in           (mac_sum_tmp_in[i]      ),
            .mac_sum_out_vld(mac_sum_tmp_out_vld[i] )
            .mac_sum_out    (mac_sum_tmp_out[i]     ),
        );

    end
endgenerate

assign mac_sum_out = mac_sum_tmp_out[KSIZE*KSIZE-1];
assign mac_sum_out_vld = mac_sum_tmp_out_vld[KSIZE*KSIZE-1];

genvar j;
genvar k;
generate 
    for(j=0;j<KSIZE-1;j=j+1) begin
        for(k=0;k<IN_WMAX;k=k+1) begin
            if(k==0) begin
                always@(posedge clk or negedge rstn) begin
                    if(~rstn)
                        mac_sum_tmp_shifter[k][j] <= 'sd0;
                    else if(mac_shift_en)
                        mac_sum_tmp_shifter[k][j] <= mac_sum_tmp_shift_in[j];
                end
            end
            else begin
                always@(posedge clk or negedge rstn) begin
                    if(~rstn)
                        mac_sum_tmp_shifter[k][j] <= 'sd0;
                    else if(mac_shift_en)
                        mac_sum_tmp_shifter[k][j] <= mac_sum_tmp_shifter[k-1][j];
                end
            end
        end
    end
endgenerate

endmodule