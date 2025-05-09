`timescale 1ns/10ps
module radix4_tb();
`define SIM
//`define DEBUG_WN
//`define DEBUG_MEM
parameter ADDR_WIDTH = 16;
parameter DATA_WIDTH = 32;

logic                        clk                    ;
logic                        rstn                   ;
logic                        fft_start              ;
logic                        fft_done               ;
logic [15:0]                 rg_fft_len             ;
logic [31:0]                 rg_twid                ;
logic                        rg_ifft_flag           ;
logic                        rg_bitreverse_flag     ;
logic [DATA_WIDTH-1:0]       data_rdata             ;
logic [DATA_WIDTH-1:0]       data_wdata             ;
logic [DATA_WIDTH/8-1:0]     data_wmask             ;
logic                        data_wr                ;
logic                        data_rd                ;
logic [ADDR_WIDTH-1:0]       data_addr              ;
logic [DATA_WIDTH-1:0]       wn_rdata               ;
logic [DATA_WIDTH-1:0]       wn_wdata               ;
logic [DATA_WIDTH/8-1:0]     wn_wmask               ;
logic                        wn_wr                  ;
logic                        wn_rd                  ;
logic [ADDR_WIDTH-1:0]       wn_addr                ;
logic [DATA_WIDTH-1:0]       lb_rdata               ;
logic [DATA_WIDTH-1:0]       lb_wdata               ;
logic                        lb_wr                  ;
logic                        lb_rd                  ;

logic                        pre_start              ;
logic                        pre_done               ;
logic                        post_start             ;
logic                        post_done              ;
logic                        reverse_start          ;
logic                        reverse_done           ;
logic [9:0]                  rg_bitrevlen           ;

logic [11:0] fft_len;
logic need_4by2;
assign need_4by2 = (rg_fft_len == 32 || rg_fft_len == 128 || rg_fft_len == 512 || rg_fft_len == 2048);
assign fft_len = need_4by2?  (rg_fft_len>>1) : rg_fft_len;

radix4 # (
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH)
) radix_inst (
    .clk                (clk                 ) ,
    .rstn               (rstn                ) ,
    .fft_start          (fft_start           ) ,
    .fft_done           (fft_done            ) ,
    .fft_len            (fft_len             ) ,
    .rg_twid            (rg_twid             ) ,
    .rg_ifft_flag       (rg_ifft_flag        ) ,
    .rg_bitreverse_flag (rg_bitreverse_flag  ) ,
    .data_rdata         (data_rdata          ) ,
    .data_wdata         (data_wdata          ) ,
    .data_wmask         (data_wmask          ) ,
    .data_wr            (data_wr             ) ,
    .data_rd            (data_rd             ) ,
    .data_addr          (data_addr           ) ,
    .wn_rdata           (wn_rdata            ) ,
    .wn_wdata           (wn_wdata            ) ,
    .wn_wmask           (wn_wmask            ) ,
    .wn_wr              (wn_wr               ) ,
    .wn_rd              (wn_rd               ) ,
    .wn_addr            (wn_addr             ) ,
    .lb_rdata           (lb_rdata            ) ,
    .lb_wdata           (lb_wdata            ) ,
    .lb_wr              (lb_wr               ) ,
    .lb_rd              (lb_rd               ) ,
    .pre_start          (pre_start           ) ,
    .pre_done           (pre_done            ) ,
    .post_start         (post_start          ) ,
    .post_done          (post_done           ) ,
    .reverse_start      (reverse_start       ) ,
    .reverse_done       (reverse_done        ) ,
    .rg_bitrevlen       (rg_bitrevlen        )    
);

always #(100/2) clk = ~clk;
initial begin
    clk=0;
    rstn=0;
    fft_start = 0;
    rg_fft_len = 64;
    rg_twid = 1;
    rg_ifft_flag = 0;
    rg_bitreverse_flag = 0;
    pre_start     = 0;
    post_start    = 0;
    reverse_start = 0;
    rg_bitrevlen  = 56;
    #133
    rstn = 1;
    #100
    @(negedge clk);
    fft_start =1;
    @(negedge clk);
    fft_start = 0;
    #400000
    @(negedge clk);
    pre_start =1;
    @(negedge clk);
    pre_start = 0;
    #400000
    @(negedge clk);
    post_start =1;
    @(negedge clk);
    post_start = 0;
    #400000
    @(negedge clk);
    reverse_start =1;
    @(negedge clk);
    reverse_start = 0;
    #400000
    $finish(2);
end

int i;
logic [DATA_WIDTH-1:0] DATA_MEM [0:(1 << 13)-1];
logic [DATA_WIDTH-1:0] WN_MEM [0:(1 << 13)-1];

`ifdef DEBUG_MEM
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        $readmemh("../model/fft_input_debug.txt",DATA_MEM);
    end
    else if(data_wr)
        DATA_MEM[data_addr] <= data_wdata;
end
`else
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn) 
        $readmemb("../model/fft_input_binary.txt",DATA_MEM);
    else if(data_wr)
        DATA_MEM[data_addr] <= data_wdata;
end
`endif

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_rdata <= 'd0;
    else if(data_rd)
        data_rdata <= DATA_MEM[data_addr];
    else
        data_rdata <= 'dx;
end

`ifdef SIM
    integer  output_file_bin;
    integer  output_file_dec;
    int j;
    logic [ADDR_WIDTH-1:0] index;
    initial begin
        output_file_bin = $fopen("../rtl/output_data_bin.txt","w+");
        output_file_dec = $fopen("../rtl/output_data_dec.txt","w+");
        index <= 0;
        @(posedge fft_done);
        for(j=0;j<rg_fft_len*2;j=j+1) begin
            @(negedge clk);
            $fwrite(output_file_bin,"%b\n",DATA_MEM[index]);
            $fwrite(output_file_dec,"%d\n",$signed(DATA_MEM[index]));
            index <= index+1;
        end
            $fclose(output_file_bin);
            $fclose(output_file_dec);
    end

`endif

`ifdef DEBUG_WN
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        wn_rdata <= 'd0;
    else if(wn_rd)
        wn_rdata <= 32'h8000;
    else
        wn_rdata <= 'dx;
end
`else
initial begin
    $readmemb("../model/fft_twiddle_binary.txt",WN_MEM);
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        wn_rdata <= 'd0;
    else if(wn_rd)
        wn_rdata <= WN_MEM[wn_addr];
    else
        wn_rdata <= 'dx;
end
`endif
initial begin
    $fsdbDumpfile("radix4_tb.fsdb");
    $fsdbDumpvars();
    $fsdbDumpSVA();
    $fsdbDumpMDA();
end

endmodule