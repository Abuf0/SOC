`timescale 1ns/10ps
module moce_cfft_tb();
`define SIM
`define DEBUG
parameter ADDR_WIDTH = 32;
parameter DATA_WIDTH = 32;
parameter N = 4;

logic                        clk                    ;
logic                        rstn                   ;
logic                        cfft_start             ;
logic                        cfft_done              ;
logic [15:0]                 rg_fft_len             ;
logic [15:0]                 rg_twid                ;
logic                        rg_ifft_flag           ;
logic                        rg_bitreverse_flag     ;
logic [11:0]                 rg_bitrevlen           ;
logic [ADDR_WIDTH-1:0]       rg_src_data_base   [0:N-1] ;
logic [ADDR_WIDTH-1:0]       rg_dest_data_base  [0:N-1] ;
logic [ADDR_WIDTH-1:0]       rg_wn_base             ;
logic [ADDR_WIDTH-1:0]       rg_rev_base            ;

logic [DATA_WIDTH-1:0]       data_rdata    [0:N-1]  ;
logic [DATA_WIDTH-1:0]       data_wdata    [0:N-1]  ;
logic [DATA_WIDTH/8-1:0]     data_wmask    [0:N-1]  ;
logic                        data_wr       [0:N-1]  ;
logic                        data_rd       [0:N-1]  ;
logic [ADDR_WIDTH-1:0]       data_addr     [0:N-1]  ;

logic [DATA_WIDTH-1:0]       wn_rdata               ;
logic [DATA_WIDTH-1:0]       wn_wdata               ;
logic [DATA_WIDTH/8-1:0]     wn_wmask               ;
logic                        wn_wr                  ;
logic                        wn_rd                  ;
logic [ADDR_WIDTH-1:0]       wn_addr                ;


logic signed [DATA_WIDTH-1:0]    add1_a    ;
logic signed [DATA_WIDTH-1:0]    add1_b    ;
logic signed [DATA_WIDTH-1:0]    add1_sum  ;
logic signed [DATA_WIDTH-1:0]    add2_a    ;
logic signed [DATA_WIDTH-1:0]    add2_b    ;
logic signed [DATA_WIDTH-1:0]    add2_sum  ;
logic signed [DATA_WIDTH-1:0]    add3_a    ;
logic signed [DATA_WIDTH-1:0]    add3_b    ;
logic signed [DATA_WIDTH-1:0]    add3_sum  ;
assign add1_sum = add1_a + add1_b;
assign add2_sum = add2_a + add2_b;
assign add3_sum = add3_a + add3_b;


logic signed [DATA_WIDTH-1:0] mult1_a [0:N-1];
logic signed [DATA_WIDTH-1:0] mult1_b [0:N-1];
logic signed [2*DATA_WIDTH-1:0] mult1_res [0:N-1];
logic signed [DATA_WIDTH-1:0] mult2_a [0:N-1];
logic signed [DATA_WIDTH-1:0] mult2_b [0:N-1];
logic signed [2*DATA_WIDTH-1:0] mult2_res [0:N-1];
logic signed [DATA_WIDTH-1:0] mult3_a [0:N-1];
logic signed [DATA_WIDTH-1:0] mult3_b [0:N-1];
logic signed [2*DATA_WIDTH-1:0] mult3_res [0:N-1];
logic signed [DATA_WIDTH-1:0] mult4_a [0:N-1];
logic signed [DATA_WIDTH-1:0] mult4_b [0:N-1];
logic signed [2*DATA_WIDTH-1:0] mult4_res [0:N-1];

genvar i;
generate
    for(i=0;i<N;i=i+1) begin
        assign mult1_res[i] = mult1_a[i] * mult1_b[i];
        assign mult2_res[i] = mult2_a[i] * mult2_b[i];
        assign mult3_res[i] = mult3_a[i] * mult3_b[i];
        assign mult4_res[i] = mult4_a[i] * mult4_b[i];
    end
endgenerate

moce_cfft # (
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .N(N)
) moce_cfft_inst (
    .clk                (clk                 ) ,
    .rstn               (rstn                ) ,
    .cfft_start         (cfft_start          ) ,
    .cfft_done          (cfft_done           ) ,
    .rg_fft_len         (rg_fft_len          ) ,
    .rg_twid            (rg_twid             ) ,
    .rg_ifft_flag       (rg_ifft_flag        ) ,
    .rg_bitreverse_flag (rg_bitreverse_flag  ) ,
    .rg_bitrevlen       (rg_bitrevlen        ) ,
    .rg_src_data_base   (rg_src_data_base  [0:N-1]  ) ,
    .rg_dest_data_base  (rg_dest_data_base [0:N-1]  ) ,
    .rg_wn_base         (rg_wn_base          ) ,
    .rg_rev_base        (rg_rev_base         ) ,
    .data_rdata         (data_rdata  [0:N-1] ) ,
    .data_wdata         (data_wdata  [0:N-1] ) ,
    .data_wmask         (data_wmask  [0:N-1] ) ,
    .data_wr            (data_wr     [0:N-1] ) ,
    .data_rd            (data_rd     [0:N-1] ) ,
    .data_addr          (data_addr           ) ,
    .wn_rdata           (wn_rdata            ) ,
    .wn_wdata           (wn_wdata            ) ,
    .wn_wmask           (wn_wmask            ) ,
    .wn_wr              (wn_wr               ) ,
    .wn_rd              (wn_rd               ) ,
    .wn_addr            (wn_addr             ) ,
    /******************************************/
    .mult1_a            (mult1_a     [0:N-1] ) ,
    .mult1_b            (mult1_b     [0:N-1] ) ,
    .mult1_res          (mult1_res   [0:N-1] ) ,
    .mult2_a            (mult2_a     [0:N-1] ) ,
    .mult2_b            (mult2_b     [0:N-1] ) ,
    .mult2_res          (mult2_res   [0:N-1] ) ,
    .mult3_a            (mult3_a     [0:N-1] ) ,
    .mult3_b            (mult3_b     [0:N-1] ) ,
    .mult3_res          (mult3_res   [0:N-1] ) ,
    .mult4_a            (mult4_a     [0:N-1] ) ,
    .mult4_b            (mult4_b     [0:N-1] ) ,
    .mult4_res          (mult4_res   [0:N-1] ) 
    //.add1_a             (add1_a              ) ,
    //.add1_b             (add1_b              ) ,
    //.add1_sum           (add1_sum            ) ,
    //.add2_a             (add2_a              ) ,
    //.add2_b             (add2_b              ) ,
    //.add2_sum           (add2_sum            ) ,
    //.add3_a             (add3_a              ) ,
    //.add3_b             (add3_b              ) ,
    //.add3_sum           (add3_sum            ) ,
    /******************************************/
);

always #(100/2) clk = ~clk;
initial begin
    clk=0;
    rstn=0;
    cfft_start = 0;
    rg_fft_len = 128;
    rg_twid = 2;
    rg_ifft_flag = 0;
    rg_bitreverse_flag = 1;
    rg_bitrevlen  = 112;
    rg_src_data_base [0]= 1*4;//0*4;
    rg_dest_data_base [0]= 1000*4;//400*4;
    rg_wn_base   = 2*4;//0+16;
    rg_rev_base  = 384*4 + rg_wn_base;
    #133
    rstn = 1;
    #100
    @(negedge clk);
    cfft_start =1;
    @(negedge clk);
    cfft_start = 0;
    #100000000
    $finish(2);
end

int i;
logic [DATA_WIDTH-1:0] DATA_MEM [0:(1 << 13)-1];
logic [DATA_WIDTH-1:0] WN_MEM [0:(1 << 13)-1];

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn) 
        $readmemb("../model/fft128r/fft_input_binary.txt",DATA_MEM);
    else if(data_wr[0])
        DATA_MEM[data_addr[0]] <= data_wdata[0];
end

initial begin
    $readmemb("../model/fft128r/fft_twiddle_binary.txt",WN_MEM);
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        wn_rdata <= 'd0;
    else if(wn_rd)
        wn_rdata <= WN_MEM[wn_addr];
    else
        wn_rdata <= 'dx;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_rdata[0] <= 'd0;
    else if(data_rd[0])
        data_rdata[0] <= DATA_MEM[data_addr[0]];
    else
        data_rdata[0] <= 'dx;
end



`ifdef SIM
    integer  output_file_bin;
    integer  output_file_dec;
    int j;
    logic [ADDR_WIDTH-1:0] index;
    initial begin
        output_file_bin = $fopen("../rtl/output_data_bin.txt","w+");
        output_file_dec = $fopen("../rtl/output_data_dec.txt","w+");
        index <= (rg_dest_data_base[0] >> 2);
        @(posedge cfft_done);
        for(j=0;j<rg_fft_len*2;j=j+1) begin
            @(posedge clk);
            $fwrite(output_file_bin,"%b\n",DATA_MEM[index]);
            $fwrite(output_file_dec,"%d\n",$signed(DATA_MEM[index]));
            index <= index+1;
        end
            $fclose(output_file_bin);
            $fclose(output_file_dec);
    end

`endif


initial begin
    $fsdbDumpfile("moce_cfft_acc_tb.fsdb");
    $fsdbDumpvars();
    $fsdbDumpSVA();
    $fsdbDumpMDA();
end

endmodule