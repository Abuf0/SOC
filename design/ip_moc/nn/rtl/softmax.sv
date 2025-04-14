module softmax #(
    parameter DATA_WB = 8           ,
    parameter DATA_WD = DATA_WB * 8 ,
    parameter ADDR_WD = 16
)
(
    input                       clk             ,
    input                       rstn            ,
    /* config */
    input [ADDR_WD-1:0]         rg_src_base     ,
    input [ADDR_WD-1:0]         rg_dest_base    ,
    input [1:0]                 rg_dim          ,   // 1:C, 2:H, 3:W
    input [63:0]                rg_llmulbzp     ,
    input [63:0]                rg_llmultsc     ,
    input [7:0]                 rg_llshift      ,   // 0-64
    input [31:0]                rg_inmultsc     ,
    input [7:0]                 rg_inshift      ,   // 0-64
    input [7:0]                 rg_batch        ,
    input [15:0]                rg_inh          ,
    input [15:0]                rg_inw          ,
    input [15:0]                rg_inc          ,
    input [15:0]                rg_outh         ,
    input [15:0]                rg_outw         ,
    input [15:0]                rg_outc         ,
    `ifdef DUAL_MEM
    /* Source memory interface */
    output logic                mem_src_rd      ,
    output logic                mem_src_wr      ,
    output logic [DATA_WB-1:0]  mem_src_wmask   ,
    output logic [ADDR_WD-1:0]  mem_src_addr    ,
    output logic [DATA_WD-1:0] mem_src_wdata   ,
    input [DATA_WD-1:0]         mem_src_rdata   ,
    /* Dest memory interface */
    output logic                mem_dest_rd     ,
    output logic                mem_dest_wr     ,
    output logic [DATA_WB-1:0]  mem_dest_wmask  ,
    output logic [ADDR_WD-1:0]  mem_dest_addr   ,
    output logic [DATA_WD-1:0] mem_dest_wdata  ,
    input [DATA_WD-1:0]         mem_dest_rdata  ,
    `else
    output logic                mem_rd      ,
    output logic                mem_wr      ,
    output logic [DATA_WB-1:0]  mem_wmask   ,
    output logic [ADDR_WD-1:0]  mem_addr    ,
    output logic [DATA_WD-1:0] mem_wdata   ,
    input [DATA_WD-1:0]         mem_rdata   ,
    `endif
    /* control */
    input                       softmax_start   ,
    output logic                softmax_done        
);

// softmax Parameters
parameter OFFSET   = $clog2(DATA_WB);
parameter INT32_WD = 32;
parameter INT64_WD = 64;
parameter N = 8;
parameter Q31_MIN = 32'h80000000;
parameter Q31_MAX = 32'h7fffffff;

logic signed [2*INT32_WD-1:0] mult_res [0:N-1];
logic signed [INT32_WD-1:0]   mult_a  [0:N-1]  ;
logic signed [INT32_WD-1:0]   mult_b  [0:N-1]  ;
logic signed [INT32_WD-1:0]   add_sum [0:N-1] ;
logic signed [INT32_WD-1:0]   add_a   [0:N-1] ;
logic signed [INT32_WD-1:0]   add_b   [0:N-1] ;

logic signed [2*INT64_WD-1:0] mult64_res [0:N-1];
logic signed [INT64_WD-1:0]   mult64_a  [0:N-1]  ;
logic signed [INT64_WD-1:0]   mult64_b  [0:N-1]  ;
logic signed [INT64_WD-1:0]   add64_sum [0:N-1] ;
logic signed [INT64_WD-1:0]   add64_a   [0:N-1] ;
logic signed [INT64_WD-1:0]   add64_b   [0:N-1] ;

logic signed [INT32_WD-1:0]   exp_add_sum [0:N-1] ;
logic signed [INT32_WD-1:0]   exp_add_a   [0:N-1] ;
logic signed [INT32_WD-1:0]   exp_add_b   [0:N-1] ;

logic signed [INT32_WD-1:0]   ctrl_add_sum [0:N-1]        ;
logic signed [INT32_WD-1:0]   ctrl_add_a   [0:N-1]        ;
logic signed [INT32_WD-1:0]   ctrl_add_b   [0:N-1]        ;
logic signed [2*INT32_WD-1:0] ctrl_mult_res [0:N-1]       ;
logic signed [INT32_WD-1:0]   ctrl_mult_a  [0:N-1]        ;
logic signed [INT32_WD-1:0]   ctrl_mult_b  [0:N-1]        ;

logic signed [INT64_WD-1:0]   ctrl_add64_sum [0:N-1]        ;
logic signed [INT64_WD-1:0]   ctrl_add64_a   [0:N-1]        ;
logic signed [INT64_WD-1:0]   ctrl_add64_b   [0:N-1]        ;
logic signed [2*INT64_WD-1:0] ctrl_mult64_res [0:N-1]       ;
logic signed [INT64_WD-1:0]   ctrl_mult64_a  [0:N-1]        ;
logic signed [INT64_WD-1:0]   ctrl_mult64_b  [0:N-1]        ;

logic signed [INT32_WD-1:0]     ctrl_mul_sat_m1 [0:N-1]     ;
logic signed [INT32_WD-1:0]     ctrl_mul_sat_m2 [0:N-1]     ;
logic signed [INT32_WD-1:0]     ctrl_mul_sat_res [0:N-1]   ;

logic signed [2*INT32_WD-1:0] sat_mult_res [0:N-1];
logic signed [INT32_WD-1:0]   sat_mult_a  [0:N-1]  ;
logic signed [INT32_WD-1:0]   sat_mult_b  [0:N-1]  ;

logic signed [INT32_WD-1:0]  m1 [0:N-1];
logic signed [INT32_WD-1:0]  m2 [0:N-1];
logic mul_sat_enable;
logic signed [INT32_WD-1:0]  mul_sat_res [0:N-1];

logic signed [INT32_WD-1:0]  exp_mul_sat_m1 [0:N-1];
logic signed [INT32_WD-1:0]  exp_mul_sat_m2 [0:N-1];
logic signed [INT32_WD-1:0]  exp_mul_sat_res [0:N-1];

logic exp_start;
logic signed [INT32_WD-1:0]  exp_in_val     [0:N-1]   ;
logic signed [INT32_WD-1:0]  exp_result     [0:N-1]   ;
logic exp_result_vld           ;

logic one_start;
logic signed [INT32_WD-1:0]  one_mul_sat_m1 [0:N-1];
logic signed [INT32_WD-1:0]  one_mul_sat_m2 [0:N-1];
logic signed [INT32_WD-1:0]  one_mul_sat_res [0:N-1];

logic signed [INT32_WD-1:0]  one_in_val     [0:N-1]   ;
logic signed [INT32_WD-1:0]  one_result     [0:N-1]   ;
logic one_result_vld           ;

logic [INT32_WD-1:0] clz_in [0:N-1];
logic [$clog2(INT32_WD):0] zero_cnt[0:N-1];

logic exp_mul_sat_sel;
logic exp_add_sel;
logic one_mul_sat_sel;
logic ctrl_mul_sat_sel;
logic ctrl_add_sel;
logic ctrl_mult_sel;
logic ctrl_add64_sel;
logic ctrl_mult64_sel;
logic                       exp_start          ;           
logic signed [INT32_WD-1:0] exp_in_val  [0:N-1];
logic signed [INT32_WD-1:0] exp_result  [0:N-1];
logic                       exp_result_vld     ;

logic                       one_start          ;    
logic signed [INT32_WD-1:0] one_in_val  [0:N-1];
logic signed [INT32_WD-1:0] one_result  [0:N-1];
logic                       one_result_vld     ;

logic [2:0] ClzTable [0:15];
logic clz_start ;
logic clz_vld   ;

softmax_ctrl #(
    .DATA_WB ( DATA_WB ),
    .DATA_WD ( DATA_WD ),
    .ADDR_WD ( ADDR_WD ),
    .OFFSET  ( OFFSET  ),
    .N       ( N       ),
    .INT32_WD( INT32_WD),
    .INT64_WD( INT64_WD))
 u_softmax_ctrl (
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
    .softmax_start   ( softmax_start                 ),

    .add_sel         ( ctrl_add_sel              ),
    .add_sum         ( ctrl_add_sum [0:N-1]      ),
    .add_a           ( ctrl_add_a   [0:N-1]      ),
    .add_b           ( ctrl_add_b   [0:N-1]      ),
    .mult_sel        ( ctrl_mult_sel             ),
    .mult_res        ( ctrl_mult_res [0:N-1]     ),
    .mult_a          ( ctrl_mult_a  [0:N-1]      ),
    .mult_b          ( ctrl_mult_b  [0:N-1]      ),

    .add64_sel         ( ctrl_add64_sel              ),
    .add64_sum         ( ctrl_add64_sum [0:N-1]      ),
    .add64_a           ( ctrl_add64_a   [0:N-1]      ),
    .add64_b           ( ctrl_add64_b   [0:N-1]      ),
    .mult64_sel        ( ctrl_mult64_sel             ),
    .mult64_res        ( ctrl_mult64_res [0:N-1]     ),
    .mult64_a          ( ctrl_mult64_a  [0:N-1]      ),
    .mult64_b          ( ctrl_mult64_b  [0:N-1]      ),

    .mul_sat_sel     ( ctrl_mul_sat_sel          ),
    .mul_sat_m1      ( ctrl_mul_sat_m1 [0:N-1]   ),
    .mul_sat_m2      ( ctrl_mul_sat_m2 [0:N-1]   ),
    .mul_sat_res     ( ctrl_mul_sat_res [0:N-1]  ),

    .exp_start       ( exp_start                 ),    
    .exp_in_val      ( exp_in_val  [0:N-1]       ),
    .exp_result      ( exp_result  [0:N-1]       ),
    .exp_result_vld  ( exp_result_vld            ),    
    .one_start       ( one_start                 ),    
    .one_in_val      ( one_in_val  [0:N-1]       ),
    .one_result      ( one_result  [0:N-1]       ),
    .one_result_vld  ( one_result_vld            ),  

    .clz_in          ( clz_in [0:N-1]            ),
    .zero_cnt        ( zero_cnt[0:N-1]           ),
    .clz_start       ( clz_start                 ),
    .clz_vld         ( clz_vld                   ),
    `ifdef DUAL_MEM
    .mem_src_rdata   ( mem_src_rdata                 ),
    .mem_src_rd      ( mem_src_rd                    ),
    .mem_src_wr      ( mem_src_wr                    ),
    .mem_src_wmask   ( mem_src_wmask                 ),
    .mem_src_addr    ( mem_src_addr                  ),
    .mem_src_wdata   ( mem_src_wdata                 ),

    .mem_dest_rdata  ( mem_dest_rdata                ),
    .mem_dest_rd     ( mem_dest_rd                   ),
    .mem_dest_wr     ( mem_dest_wr                   ),
    .mem_dest_wmask  ( mem_dest_wmask                ),
    .mem_dest_addr   ( mem_dest_addr                 ),
    .mem_dest_wdata  ( mem_dest_wdata                ),
    `else
    .mem_rdata   ( mem_rdata                 ),
    .mem_rd      ( mem_rd                    ),
    .mem_wr      ( mem_wr                    ),
    .mem_wmask   ( mem_wmask                 ),
    .mem_addr    ( mem_addr                  ),
    .mem_wdata   ( mem_wdata                 ),
    `endif

    .softmax_done    ( softmax_done                  )
);

assign mul_sat_enable = exp_mul_sat_sel || one_mul_sat_sel || ctrl_mul_sat_sel;
assign ClzTable = {3'd4, 3'd3, 3'd2, 3'd2, 3'd1, 3'd1, 3'd1, 3'd1, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0};

clz #(
   .DATA_WD ( INT32_WD ),
   .N       ( N        ))
u_clz (
   .clk       ( clk              ),
   .rstn      ( rstn             ),
   .clz_in    ( clz_in[0:N-1]    ),
   .clz_start ( clz_start        ),
   .clz_vld   ( clz_vld          ),
   .ClzTable  ( ClzTable[0:15]   ),
   .zero_cnt  ( zero_cnt[0:N-1]  )
);

genvar i;
generate 
    for(i=0; i<N; i=i+1) begin
        mul_sat #(
            .DATA_WD ( INT32_WD ))
        u_mul_sat (
           .clk       ( clk                    ),
           .rstn      ( rstn                   ),
           .enable    ( mul_sat_enable         ),
           .m1        ( m1[i]                  ),
           .m2        ( m2[i]                  ),
           .mult_res  ( sat_mult_res[i]        ),
           .result    ( mul_sat_res[i]        ),
           .mult_a    ( sat_mult_a[i]          ),
           .mult_b    ( sat_mult_b[i]          )
        );

    assign mult_res[i] = mult_a[i] * mult_b[i]; 
    assign add_sum[i] = add_a[i] + add_b[i];
    assign mult64_res[i] = mult64_a[i] * mult64_b[i]; 
    assign add64_sum[i] = add64_a[i] + add64_b[i];
    // MUL_SAT connection
    assign m1[i] = ctrl_mul_sat_sel?    ctrl_mul_sat_m1[i] :
                   exp_mul_sat_sel?     exp_mul_sat_m1[i] :
                   one_mul_sat_sel?     one_mul_sat_m1[i] : 'sd0;

    assign m2[i] = ctrl_mul_sat_sel?    ctrl_mul_sat_m2[i] :
                   exp_mul_sat_sel?     exp_mul_sat_m2[i] :
                   one_mul_sat_sel?     one_mul_sat_m2[i] : 'sd0;
    
    assign ctrl_mul_sat_res[i] = mul_sat_res[i];
    assign exp_mul_sat_res[i] = mul_sat_res[i];
    assign one_mul_sat_res[i] = mul_sat_res[i];

    // MULT connection
    assign mult_a[i] = ctrl_mult_sel?    ctrl_mult_a[i] : 
                       mul_sat_enable?   sat_mult_a[i] : 'sd0;
    assign mult_b[i] = ctrl_mult_sel?    ctrl_mult_b[i] : 
                       mul_sat_enable?   sat_mult_b[i] : 'sd0;
    assign ctrl_mult_res[i] = mult_res[i];
    assign sat_mult_res[i] = mult_res[i];

    // ADD connection
    assign add_a[i] = ctrl_add_sel?    ctrl_add_a[i] : 
                      exp_add_sel?     exp_add_a[i] : 'sd0;
    assign add_b[i] = ctrl_add_sel?    ctrl_add_b[i] : 
                      exp_add_sel?     exp_add_b[i] : 'sd0;
    assign ctrl_add_sum[i] = add_sum[i];
    assign exp_add_sum[i]  = add_sum[i];

    // MULT64 connection
    assign mult64_a[i] = ctrl_mult64_sel?   ctrl_mult64_a[i] : 'sd0;
    assign mult64_b[i] = ctrl_mult64_sel?   ctrl_mult64_b[i] : 'sd0;
    assign ctrl_mult64_res[i] = mult64_res[i];

    // ADD64 connection
    assign add64_a[i] = ctrl_add64_sel?   ctrl_add64_a[i] : 'sd0;
    assign add64_b[i] = ctrl_add64_sel?   ctrl_add64_b[i] : 'sd0;
    assign ctrl_add64_sum[i] = add64_sum[i];

    end

endgenerate

exp_on_neg #(
    .DATA_WD ( INT32_WD ),
    .N       ( N       ))
 u_exp_on_neg (
    .clk         ( clk                      ),
    .rstn        ( rstn                     ),
    .start_trig  ( exp_start                ),
    .mul_sat_sel ( exp_mul_sat_sel          ),
    .val         ( exp_in_val     [0:N-1]   ),
    .mul_sat_res ( exp_mul_sat_res[0:N-1]   ),
    .add_sum     ( exp_add_sum    [0:N-1]   ),
    .result      ( exp_result     [0:N-1]   ),
    .result_vld  ( exp_result_vld           ),
    .mul_sat_m1  ( exp_mul_sat_m1 [0:N-1]   ),
    .mul_sat_m2  ( exp_mul_sat_m2 [0:N-1]   ),
    .add_sel     ( exp_add_sel              ),
    .add_a       ( exp_add_a      [0:N-1]   ),
    .add_b       ( exp_add_b      [0:N-1]   )
);

onedivonepx #(
    .DATA_WD  ( INT32_WD  ),
    .N        ( N        ))
 u_onedivonepx (
    .clk          ( clk                          ),
    .rstn         ( rstn                         ),
    .start_trig   ( one_start                    ),
    .mul_sat_sel  ( one_mul_sat_sel              ),
    .val          ( one_in_val [0:N-1]           ),
    .mul_sat_res  ( one_mul_sat_res [0:N-1]      ),
    .result       ( one_result      [0:N-1]      ),
    .result_vld   ( one_result_vld               ),
    .mul_sat_m1   ( one_mul_sat_m1  [0:N-1]      ),
    .mul_sat_m2   ( one_mul_sat_m2  [0:N-1]      )
);


endmodule