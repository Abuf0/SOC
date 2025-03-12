`timescale 1ns/10ps
module moce_cfft_tb();
`define SIM
//`define DEBUG_WN
//`define DEBUG_MEM
parameter ADDR_WIDTH = 16;
parameter DATA_WIDTH = 32;
parameter LADDR_WIDTH = 4;

logic                        clk                    ;
logic                        rstn                   ;
logic                        cfft_start             ;
logic                        cfft_done              ;
logic [15:0]                 rg_fft_len             ;
logic [31:0]                 rg_twid                ;
logic                        rg_ifft_flag           ;
logic                        rg_bitreverse_flag     ;
logic [9:0]                  rg_bitrevlen           ;

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

logic [DATA_WIDTH-1:0]       mem1_rdata             ;
logic [DATA_WIDTH-1:0]       mem1_wdata             ;
logic [LADDR_WIDTH-1:0]      mem1_addr              ;
logic                        mem1_wr                ;
logic                        mem1_rd                ;
logic [DATA_WIDTH-1:0]       mem2_rdata             ;
logic [DATA_WIDTH-1:0]       mem2_wdata             ;
logic [LADDR_WIDTH-1:0]      mem2_addr              ;
logic                        mem2_wr                ;
logic                        mem2_rd                ;
logic [DATA_WIDTH-1:0]       mem3_rdata             ;
logic [DATA_WIDTH-1:0]       mem3_wdata             ;
logic [LADDR_WIDTH-1:0]      mem3_addr              ;
logic                        mem3_wr                ;
logic                        mem3_rd                ;
logic [DATA_WIDTH-1:0]       mem4_rdata             ;
logic [DATA_WIDTH-1:0]       mem4_wdata             ;
logic [LADDR_WIDTH-1:0]      mem4_addr              ;
logic                        mem4_wr                ;
logic                        mem4_rd                ;

logic signed [DATA_WIDTH-1:0]    mult1_a   ;
logic signed [DATA_WIDTH-1:0]    mult1_b   ;
logic signed [2*DATA_WIDTH-1:0]  mult1_res ;
logic signed [DATA_WIDTH-1:0]    mult2_a   ;
logic signed [DATA_WIDTH-1:0]    mult2_b   ;
logic signed [2*DATA_WIDTH-1:0]  mult2_res ;
logic signed [DATA_WIDTH-1:0]    add1_a    ;
logic signed [DATA_WIDTH-1:0]    add1_b    ;
logic signed [DATA_WIDTH-1:0]    add1_sum  ;
logic signed [DATA_WIDTH-1:0]    add2_a    ;
logic signed [DATA_WIDTH-1:0]    add2_b    ;
logic signed [DATA_WIDTH-1:0]    add2_sum  ;
logic signed [DATA_WIDTH-1:0]    add3_a    ;
logic signed [DATA_WIDTH-1:0]    add3_b    ;
logic signed [DATA_WIDTH-1:0]    add3_sum  ;

moce_cfft # (
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .LADDR_WIDTH(LADDR_WIDTH)
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
    .mem1_rdata         (mem1_rdata          ) ,
    .mem1_wdata         (mem1_wdata          ) ,
    .mem1_addr          (mem1_addr           ) ,
    .mem1_wr            (mem1_wr             ) ,
    .mem1_rd            (mem1_rd             ) ,
    .mem2_rdata         (mem2_rdata          ) ,
    .mem2_wdata         (mem2_wdata          ) ,
    .mem2_addr          (mem2_addr           ) ,
    .mem2_wr            (mem2_wr             ) ,
    .mem2_rd            (mem2_rd             ) ,
    .mem3_rdata         (mem3_rdata          ) ,
    .mem3_wdata         (mem3_wdata          ) ,
    .mem3_addr          (mem3_addr           ) ,
    .mem3_wr            (mem3_wr             ) ,
    .mem3_rd            (mem3_rd             ) ,
    .mem4_rdata         (mem4_rdata          ) ,
    .mem4_wdata         (mem4_wdata          ) ,
    .mem4_addr          (mem4_addr           ) ,
    .mem4_wr            (mem4_wr             ) ,
    .mem4_rd            (mem4_rd             ) ,
    .mult1_a            (mult1_a             ) ,
    .mult1_b            (mult1_b             ) ,
    .mult1_res          (mult1_res           ) ,
    .mult2_a            (mult2_a             ) ,
    .mult2_b            (mult2_b             ) ,
    .mult2_res          (mult2_res           ) ,
    .add1_a             (add1_a              ) ,
    .add1_b             (add1_b              ) ,
    .add1_sum           (add1_sum            ) ,
    .add2_a             (add2_a              ) ,
    .add2_b             (add2_b              ) ,
    .add2_sum           (add2_sum            ) ,
    .add3_a             (add3_a              ) ,
    .add3_b             (add3_b              ) ,
    .add3_sum           (add3_sum            ) 
);

always #(100/2) clk = ~clk;
initial begin
    clk=0;
    rstn=0;
    cfft_start = 0;
    rg_fft_len = 64;
    rg_twid = 1;
    rg_ifft_flag = 0;
    rg_bitreverse_flag = 0;
    rg_bitrevlen  = 56;
    #133
    rstn = 1;
    #100
    @(negedge clk);
    cfft_start =1;
    @(negedge clk);
    cfft_start = 0;
    #1000000
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

assign mult1_res = mult1_a * mult1_b;
assign mult2_res = mult2_a * mult2_b;
assign add1_sum = add1_a + add1_b;
assign add2_sum = add2_a + add2_b;
assign add3_sum = add3_a + add3_b;

logic [DATA_WIDTH-1:0] mem1_array [0:(1<<LADDR_WIDTH)-1];
always_ff@(posedge clk or negedge rstn) begin
    if(mem1_wr)
        mem1_array[mem1_addr] <= mem1_wdata;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        mem1_rdata <= 'd0;
    end
    else if(mem1_rd)
        mem1_rdata <= mem1_array[mem1_addr];
end

logic [DATA_WIDTH-1:0] mem2_array [0:(1<<LADDR_WIDTH)-1];
always_ff@(posedge clk or negedge rstn) begin
    if(mem2_wr)
        mem2_array[mem2_addr] <= mem2_wdata;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        mem2_rdata <= 'd0;
    end
    else if(mem2_rd)
        mem2_rdata <= mem2_array[mem2_addr];
end

logic [DATA_WIDTH-1:0] mem3_array [0:(1<<LADDR_WIDTH)-1];
always_ff@(posedge clk or negedge rstn) begin
    if(mem3_wr)
        mem3_array[mem3_addr] <= mem3_wdata;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        mem3_rdata <= 'd0;
    end
    else if(mem3_rd)
        mem3_rdata <= mem3_array[mem3_addr];
end

logic [DATA_WIDTH-1:0] mem4_array [0:(1<<LADDR_WIDTH)-1];
always_ff@(posedge clk or negedge rstn) begin
    if(mem4_wr)
        mem4_array[mem4_addr] <= mem4_wdata;
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        mem4_rdata <= 'd0;
    end
    else if(mem4_rd)
        mem4_rdata <= mem4_array[mem4_addr];
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
        @(posedge cfft_done);
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
    $fsdbDumpfile("moce_cfft_tb.fsdb");
    $fsdbDumpvars();
    $fsdbDumpSVA();
    $fsdbDumpMDA();
end

endmodule