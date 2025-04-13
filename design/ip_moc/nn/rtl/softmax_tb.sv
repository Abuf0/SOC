`timescale  1ns / 10ps

module tb_softmax;

// softmax Parameters
parameter PERIOD   = 10            ;
parameter DATA_WB  = 8             ;
parameter DATA_WD  = DATA_WB * 8   ;
parameter ADDR_WD  = 16            ;
parameter OFFSET   = $clog2(DATA_WB);
parameter DATA_WIDTH = 32;
parameter N = 8;
parameter Q31_MIN = 32'h80000000;
parameter Q31_MAX = 32'h7fffffff;

// softmax Inputs
logic clk                                  = 0 ;
logic rstn                                 = 0 ;
logic [ADDR_WD-1:0]  rg_src_base           = 0 ;
logic [ADDR_WD-1:0]  rg_dest_base          = 0 ;
logic [1:0]  rg_dim                        = 0 ;
logic [63:0] rg_llmulbzp                  = 0 ;
logic [63:0] rg_llmultsc                  = 0 ;
logic [7:0]  rg_llshift                    = 0 ;
logic [31:0] rg_inmultsc                  = 0 ;
logic [7:0]  rg_inshift                    = 0 ;
logic [7:0]  rg_batch                      = 0 ;
logic [15:0] rg_inh                       = 0 ;
logic [15:0] rg_inw                       = 0 ;
logic [15:0] rg_inc                       = 0 ;
logic [15:0] rg_outh                      = 0 ;
logic [15:0] rg_outw                      = 0 ;
logic [15:0] rg_outc                      = 0 ;
logic [DATA_WD-1:0]  mem_src_rdata         = 0 ;
logic [DATA_WD-1:0]  mem_dest_rdata        = 0 ;
logic softmax_start                        = 0 ;

// softmax Outputs
logic                mem_src_rd      ;
logic                mem_src_wr      ;
logic [DATA_WB-1:0]  mem_src_wmask   ;
logic [ADDR_WD-1:0]  mem_src_addr    ;
logic [DATA_WD-1:-0] mem_src_wdata   ;
logic                mem_dest_rd     ;
logic                mem_dest_wr     ;
logic [DATA_WB-1:0]  mem_dest_wmask  ;
logic [ADDR_WD-1:0]  mem_dest_addr   ;
logic [DATA_WD-1:-0] mem_dest_wdata  ;
logic                softmax_done    ;


initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #(PERIOD*3.3) rstn  =  1;
    repeat(5) begin @(negedge clk); end
    rg_batch   = 2 ;
    rg_inw     = 2 ;
    rg_inh     = 2 ;
    rg_inc     = 10 ;  
    rg_dim       = 1;
    rg_llmulbzp  = 0;
    rg_llmultsc  = 1;
    rg_llshift   = 1;
    rg_inmultsc  = 1;
    rg_inshift   = 1;
    @(negedge clk);
    softmax_start = 1;
    @(negedge clk);
    softmax_start = 0;

    #(PERIOD*10000)
    $finish(2);
end

softmax #(
    .DATA_WB ( DATA_WB ),
    .DATA_WD ( DATA_WD ),
    .ADDR_WD ( ADDR_WD ),
    .OFFSET  ( OFFSET  ))
 u_softmax (
    .clk             ( clk                           ),
    .rstn            ( rstn                          ),
    .rg_src_base     ( rg_src_base                   ),
    .rg_dest_base    ( rg_dest_base                  ),
    .rg_dim          ( rg_dim                        ),
    .rg_llmulbzp     ( rg_llmulbzp                   ),
    .rg_llmultsc     ( rg_llmultsc                   ),
    .rg_llshift      ( rg_llshift                    ),
    .rg_inmultsc     ( rg_inmultsc                   ),
    .rg_inshift      ( rg_inshift                    ),
    .rg_batch        ( rg_batch                      ),
    .rg_inh          ( rg_inh                        ),
    .rg_inw          ( rg_inw                        ),
    .rg_inc          ( rg_inc                        ),
    .rg_outh         ( rg_outh                       ),
    .rg_outw         ( rg_outw                       ),
    .rg_outc         ( rg_outc                       ),
    .mem_src_rdata   ( mem_src_rdata                 ),
    .mem_dest_rdata  ( mem_dest_rdata                ),
    .softmax_start   ( softmax_start                 ),

    .mem_src_rd      ( mem_src_rd                    ),
    .mem_src_wr      ( mem_src_wr                    ),
    .mem_src_wmask   ( mem_src_wmask                 ),
    .mem_src_addr    ( mem_src_addr                  ),
    .mem_src_wdata   ( mem_src_wdata                 ),
    .mem_dest_rd     ( mem_dest_rd                   ),
    .mem_dest_wr     ( mem_dest_wr                   ),
    .mem_dest_wmask  ( mem_dest_wmask                ),
    .mem_dest_addr   ( mem_dest_addr                 ),
    .mem_dest_wdata  ( mem_dest_wdata                ),
    .softmax_done    ( softmax_done                  )
);


// DEBUG
// mul_sat
logic   [DATA_WIDTH-1:0]  m1                    = 0 ;
logic   [DATA_WIDTH-1:0]  m2                    = 0 ;
logic                  mul_sat_enable = 0;
logic signed [DATA_WIDTH-1:0]  result   ;
logic signed [2*DATA_WIDTH-1:0] mult_res;
logic signed [DATA_WIDTH-1:0]  mult_a   ;
logic signed [DATA_WIDTH-1:0]  mult_b   ;
assign mult_res = mult_a * mult_b; 
logic signed [2*DATA_WIDTH-1:0] exp_mult_res;
logic signed [DATA_WIDTH-1:0]  exp_mult_a   ;
logic signed [DATA_WIDTH-1:0]  exp_mult_b   ;
assign exp_mult_res = exp_mult_a * exp_mult_b; 
logic signed [2*DATA_WIDTH-1:0] one_mult_res;
logic signed [DATA_WIDTH-1:0]  one_mult_a   ;
logic signed [DATA_WIDTH-1:0]  one_mult_b   ;
assign one_mult_res = one_mult_a * one_mult_b; 
// clz
logic [DATA_WIDTH-1:0]  data_in               = 0 ;
logic [$clog2(DATA_WIDTH):0] zero_cnt;

// exp_on_neg Inputs
logic  exp_start                   = 0 ;
logic  [DATA_WIDTH-1:0]  exp_in_val [0:N-1];
logic  signed [DATA_WIDTH-1:0] exp_mul_sat_res [0:N-1];
logic  signed [DATA_WIDTH-1:0]  add_sum [0:N-1] ;

logic signed [DATA_WIDTH-1:0]  exp_result      [0:N-1] ;
logic                       exp_result_vld ;
logic signed [DATA_WIDTH-1:0]  exp_mul_sat_m1  [0:N-1] ;
logic signed [DATA_WIDTH-1:0]  exp_mul_sat_m2  [0:N-1] ;
logic signed [DATA_WIDTH-1:0]  add_a       [0:N-1] ;
logic signed [DATA_WIDTH-1:0]  add_b       [0:N-1] ;

assign add_sum[0] = add_a[0] + add_b[0];
// onedivonepx Inputs
logic   [DATA_WIDTH-1:0]  one_in_val  [0:N-1];
logic                  one_start = 0;
logic  signed [DATA_WIDTH-1:0] one_mul_sat_res [0:N-1];

// onedivonepx Outputs
logic signed [DATA_WIDTH-1:0]  one_result [0:N-1]  ;
logic                       one_result_vld ;
logic signed [DATA_WIDTH-1:0]  one_mul_sat_m1  [0:N-1] ;
logic signed [DATA_WIDTH-1:0]  one_mul_sat_m2  [0:N-1] ;

initial
begin
    repeat(10) begin @(negedge clk); end
    mul_sat_enable = 1 ;
    @(negedge clk);
    m1  = Q31_MAX ;
    m2  = Q31_MAX ;
    @(negedge clk);
    m1  = Q31_MIN ;
    m2  = Q31_MIN ;
    @(negedge clk);
    m1  = Q31_MAX ;
    m2  = Q31_MIN ;
    @(negedge clk);
    m1  = -4063231 ;
    m2  = 715827883 ;
    @(negedge clk);
    data_in = 32'h3;
    @(negedge clk);
    data_in = 32'hf;
    @(negedge clk);
    data_in = 32'h0;
    exp_in_val[0] = -1;
    exp_start = 1;
    @(negedge clk);
    exp_start = 0;
    repeat(20) begin @(negedge clk); end
    exp_in_val[0] = -100;
    exp_start = 1;
    @(negedge clk);
    exp_start = 0;
    repeat(20) begin @(negedge clk); end
    exp_in_val[0] = -20252026;
    exp_start = 1;
    @(negedge clk);
    exp_start = 0;
    one_in_val[0] = 1;
    one_start = 1;
    @(negedge clk);
    one_start = 0;
    repeat(20) begin @(negedge clk); end
    one_in_val[0] = 10;
    one_start = 1;
    @(negedge clk);
    one_start = 0;
    repeat(20) begin @(negedge clk); end
    one_in_val[0] = -22;
    one_start = 1;
    @(negedge clk);
    one_start = 0;
end

mul_sat #(
    .DATA_WD ( DATA_WIDTH ))
 u_mul_sat (
    .clk       ( clk                    ),
    .rstn      ( rstn                   ),
    .enable    ( mul_sat_enable         ),
    .m1        ( m1                     ),
    .m2        ( m2                     ),
    .mult_res  (mult_res                ),

    .result    (result                  ),
    .mult_a    (mult_a                  ),
    .mult_b    (mult_b                  )
);

clz #(
    .DATA_WD ( DATA_WIDTH ))
 u_clz (
    .data_in    ( data_in          ),
    .zero_cnt   ( zero_cnt         )
);

exp_on_neg #(
    .DATA_WD ( DATA_WIDTH ),
    .N       ( N       ))
 u_exp_on_neg (
    .clk         ( clk                   ),
    .rstn        ( rstn                  ),
    .start_trig  ( exp_start                ),
    .val         ( exp_in_val         [0:N-1]   ),
    .mul_sat_res (  exp_mul_sat_res[0:N-1]   ),
    .add_sum     ( add_sum     [0:N-1]   ),

    .result      ( exp_result      [0:N-1]   ),
    .result_vld  ( exp_result_vld            ),
    .mul_sat_m1  ( exp_mul_sat_m1  [0:N-1]   ),
    .mul_sat_m2  ( exp_mul_sat_m2  [0:N-1]   ),
    .add_a       ( add_a       [0:N-1]   ),
    .add_b       ( add_b       [0:N-1]   )
);

mul_sat #(
    .DATA_WD ( DATA_WIDTH ))
 u_mul_sat_exp (
    .clk       ( clk                    ),
    .rstn      ( rstn                   ),
    .enable    ( 1             ),
    .m1        ( exp_mul_sat_m1[0]                     ),
    .m2        ( exp_mul_sat_m2[0]                     ),
    .mult_res  (exp_mult_res                ),

    .result    (exp_mul_sat_res[0]                  ),
    .mult_a    (exp_mult_a                  ),
    .mult_b    (exp_mult_b                  )
);

onedivonepx #(
    .DATA_WD  ( DATA_WIDTH  ),
    .N        ( N        ))
 u_onedivonepx (
    .clk          ( clk                      ),
    .rstn         ( rstn                     ),
    .start_trig   ( one_start                ),
    .val          ( one_in_val [0:N-1]                      ),
    .mul_sat_res  ( one_mul_sat_res [0:N-1]      ),

    .result       ( one_result      [0:N-1]      ),
    .result_vld   ( one_result_vld               ),
    .mul_sat_m1   ( one_mul_sat_m1  [0:N-1]      ),
    .mul_sat_m2   ( one_mul_sat_m2  [0:N-1]      )
);

mul_sat #(
    .DATA_WD ( DATA_WIDTH ))
 u_mul_sat_one (
    .clk       ( clk                    ),
    .rstn      ( rstn                   ),
    .enable    ( 1             ),
    .m1        ( one_mul_sat_m1[0]                     ),
    .m2        ( one_mul_sat_m2[0]                     ),
    .mult_res  ( one_mult_res                ),

    .result    (one_mul_sat_res[0]                  ),
    .mult_a    (one_mult_a                  ),
    .mult_b    (one_mult_b                  )
);

initial
begin
    $fsdbDumpfile("softmax_tb.fsdb");
    $fsdbDumpvars();
    $fsdbDumpSVA();
    $fsdbDumpMDA();
end

endmodule