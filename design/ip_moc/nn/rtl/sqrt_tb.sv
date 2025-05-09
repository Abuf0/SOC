`timescale  1ns / 10ps

module tb_sqrt;
`define SIM
//`define DUAL_MEM
// softmax Parameters
parameter PERIOD   = 10            ;
parameter DATA_WD  = 64   ;

// softmax Inputs
logic clk                                  = 0 ;
logic rstn                                 = 0 ;
logic sqrt_in_vld                          = 0 ;
logic [DATA_WD-1:0]  sqrt_in               = 0 ;
 
// sqrtu64 Outputs
logic [DATA_WD/2-1:0]    sqrt_out    ;
logic                    sqrt_out_vld ;


//`ifdef SIM
//    integer  output_file_bin;
//    integer  output_file_dec;
//    int j;
//    logic [ADDR_WD-1:0] index;
//    initial begin
//        output_file_dec = $fopen("../rtl/sqrt_output_dec.txt","w+");
//        @(posedge sqrt_out_vld);
//        $fwrite(output_file_dec,"%d\n",sqrt_out);
//    end
//`endif



initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

integer  output_file_dec;
initial
begin
    #(PERIOD*3.3) rstn  =  1;
    output_file_dec = $fopen("../rtl/sqrt_output_dec.txt","w+");
    repeat(5) begin @(negedge clk); end
    for(int i = 2; i < 10002; i=i+1) begin
        @(posedge clk);
        #(PERIOD*0.1)
        sqrt_in_vld = 1;
        sqrt_in = i;
        @(posedge clk);
        #(PERIOD*0.1)
        sqrt_in_vld = 0;
        @(posedge sqrt_out_vld);
        $fwrite(output_file_dec,"%d : %d\n",sqrt_in, sqrt_out);
    end
    #(PERIOD*100)
    $fclose(output_file_dec);
    $finish(2);
end

sqrtu64 #(
    .DATA_WD ( DATA_WD ))
 u_sqrtu64 (
    .clk           ( clk                ),
    .rstn          ( rstn               ),
    .sqrt_in_vld   ( sqrt_in_vld        ),
    .sqrt_in       ( sqrt_in            ),
    .sqrt_out      ( sqrt_out           ),
    .sqrt_out_vld  ( sqrt_out_vld       )
);


initial
begin
    $fsdbDumpfile("sqrt_tb.fsdb");
    $fsdbDumpvars();
    $fsdbDumpSVA();
    $fsdbDumpMDA();
end

endmodule