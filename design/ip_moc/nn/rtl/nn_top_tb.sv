`timescale  1ns / 10ps

module nn_top_tb;

// nn_top Parameters
parameter PERIOD      = 10    ;

parameter ROW_NUM     = 32    ;
parameter COL_NUM     = 32    ;
parameter MAX_SP_LEN  = 40    ;
parameter IN_WD       = 32*8  ;
parameter WGT_WD      = 32*8  ;
parameter MAX_WD      = 32    ;
parameter OUT_WD      = 12    ;
parameter DADDR_WD    = 32    ;
parameter WADDR_WD    = 32    ;
parameter DDATA_WD    = IN_WD ;
parameter WDATA_WD    = WGT_WD;

// nn_top Inputs
logic   clk                                  = 0 ;
logic   rstn                                 = 0 ;
logic   [DDATA_WD-1:0]  data_rdata           = 0 ;
logic   data_wvalid                          = 0 ;
logic   data_rvalid                          = 0 ;
logic   [DADDR_WD-1:0]  rg_src_data_base     = 0 ;
logic   [DADDR_WD-1:0]  rg_dest_data_base    = 0 ;
logic   [DDATA_WD-1:0]  wgt_rdata            = 0 ;
logic   wgt_wvalid                           = 0 ;
logic   wgt_rvalid                           = 0 ;
logic   [9:0]  rg_batch_num                  = 0 ;
logic   [9:0]  rg_in_w                       = 0 ;
logic   [9:0]  rg_in_h                       = 0 ;
logic   [9:0]  rg_in_c                       = 0 ;
logic   [9:0]  rg_kernel_w                   = 0 ;
logic   [9:0]  rg_kernel_h                   = 0 ;
logic   [9:0]  rg_kernel_c                   = 0 ;
logic   [9:0]  rg_out_w                      = 0 ;
logic   [9:0]  rg_out_h                      = 0 ;
logic   [9:0]  rg_out_c                      = 0 ;
logic   [3:0]  rg_pad_x                      = 0 ;
logic   [3:0]  rg_pad_y                      = 0 ;
logic   [1:0]  rg_pad_mode                   = 0 ;
logic   [DDATA_WD-1:0]  rg_pad_x_value       = 0 ;
logic   [DDATA_WD-1:0]  rg_pad_y_value       = 0 ;
logic   [9:0]  rg_stride_w                   = 0 ;
logic   [9:0]  rg_stride_h                   = 0 ;
logic   [9:0]  rg_dilat_w                    = 0 ;
logic   [9:0]  rg_dilat_h                    = 0 ;
logic   [DDATA_WD-1:0]  rg_inzp              = 0 ;
logic   [DDATA_WD-1:0]  rg_outzp             = 0 ;
logic   [3:0]  rg_data_type                  = 0 ;
logic   [3:0]  rg_wgt_type                   = 0 ;
logic   [9:0]  rg_strip_len                  = 0 ;
logic   mac_init                             = 0 ;
logic   mac_start                            = 0 ;

// nn_top Outputs
logic                data_rd         ;
logic                data_wr         ;
logic [DADDR_WD-1:0] data_raddr      ;
logic [DADDR_WD-1:0] data_waddr      ;
logic [DDATA_WD-1:0] data_wdata      ;
logic                wgt_rd          ;
logic                wgt_wr          ;
logic [DADDR_WD-1:0] wgt_raddr       ;
logic [DADDR_WD-1:0] wgt_waddr       ;
logic [DDATA_WD-1:0] wgt_wdata       ;
logic                mac_done        ;


initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial begin
    #(PERIOD*3.3) rst_n  =  1;
    repeat(5) begin @(negedge clk); end
    rg_batch_num                  = 0 ;
    rg_in_w                       = 128 ;
    rg_in_h                       = 128 ;
    rg_in_c                       = 64 ;
    rg_kernel_w                   = 3 ;
    rg_kernel_h                   = 3 ;
    rg_kernel_c                   = 64 ;
    rg_out_w                      = 128 ;   // todo
    rg_out_h                      = 128 ;   // todo
    rg_out_c                      = 256 ;
    rg_pad_x                      = 0 ;
    rg_pad_y                      = 0 ;
    rg_stride_w                   = 1 ;
    rg_stride_h                   = 1 ;
    rg_data_type                  = 0 ;
    rg_wgt_type                   = 0 ;
    rg_strip_len                  = 32 ;
    @(negedge clk);
    mac_init = 1;
    @(negedge clk);
    mac_init = 0;
    @(negedge clk);
    @(negedge clk);
    mac_start = 1;
    @(negedge clk);
    mac_start = 0;
    
    #(PERIOD*2000)
    $finish(2);

end

nn_top #(
    .ROW_NUM    ( ROW_NUM    ),
    .COL_NUM    ( COL_NUM    ),
    .MAX_SP_LEN ( MAX_SP_LEN ),
    .IN_WD      ( IN_WD      ),
    .WGT_WD     ( WGT_WD     ),
    .MAX_WD     ( MAX_WD     ),
    .OUT_WD     ( OUT_WD     ),
    .DADDR_WD   ( DADDR_WD   ),
    .WADDR_WD   ( WADDR_WD   ),
    .DDATA_WD   ( DDATA_WD   ),
    .WDATA_WD   ( WDATA_WD   ))
 nn_top_inst (
    .clk                              ( clk                         ),
    .rstn                             ( rstn                        ),
    .data_rdata                       ( data_rdata                  ),
    .data_wvalid                      ( data_wvalid                 ),
    .data_rvalid                      ( data_rvalid                 ),
    .rg_src_data_base                 ( rg_src_data_base            ),
    .rg_dest_data_base                ( rg_dest_data_base           ),
    .wgt_rdata                        ( wgt_rdata                   ),
    .wgt_wvalid                       ( wgt_wvalid                  ),
    .wgt_rvalid                       ( wgt_rvalid                  ),
    .rg_batch_num                     ( rg_batch_num                ),
    .rg_in_w                          ( rg_in_w                     ),
    .rg_in_h                          ( rg_in_h                     ),
    .rg_in_c                          ( rg_in_c                     ),
    .rg_kernel_w                      ( rg_kernel_w                 ),
    .rg_kernel_h                      ( rg_kernel_h                 ),
    .rg_kernel_c                      ( rg_kernel_c                 ),
    .rg_out_w                         ( rg_out_w                    ),
    .rg_out_h                         ( rg_out_h                    ),
    .rg_out_c                         ( rg_out_c                    ),
    .rg_pad_x                         ( rg_pad_x                    ),
    .rg_pad_y                         ( rg_pad_y                    ),
    .rg_pad_mode                      ( rg_pad_mode                 ),
    .rg_pad_x_value                   ( rg_pad_x_value              ),
    .rg_pad_y_value                   ( rg_pad_y_value              ),
    .rg_stride_w                      ( rg_stride_w                 ),
    .rg_stride_h                      ( rg_stride_h                 ),
    .rg_dilat_w                       ( rg_dilat_w                  ),
    .rg_dilat_h                       ( rg_dilat_h                  ),
    .rg_inzp                          ( rg_inzp                     ),
    .rg_outzp                         ( rg_outzp                    ),
    .rg_data_type                     ( rg_data_type                ),
    .rg_wgt_type                      ( rg_wgt_type                 ),
    .rg_strip_len                     ( rg_strip_len                ),
    .mac_init                         ( mac_init                    ),
    .mac_start                        ( mac_start                   ),
    .data_rd                          ( data_rd                    ),
    .data_wr                          ( data_wr                    ),
    .data_raddr                       ( data_raddr                 ),
    .data_waddr                       ( data_waddr                 ),
    .data_wdata                       ( data_wdata                 ),
    .wgt_rd                           ( wgt_rd                     ),
    .wgt_wr                           ( wgt_wr                     ),
    .wgt_raddr                        ( wgt_raddr                  ),
    .wgt_waddr                        ( wgt_waddr                  ),
    .wgt_wdata                        ( wgt_wdata                  ),
    .mac_done                         ( mac_done                   )
);

initial begin
    $fsdbDumpfile("nn_top_tb.fsdb");
    $fsdbDumpvars();
    $fsdbDumpSVA();
    $fsdbDumpMDA();
end

endmodule