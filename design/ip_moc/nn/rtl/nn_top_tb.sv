`timescale  1ns / 10ps

module nn_top_tb;

`define SIM

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

logic  [DADDR_WD-1:0]  rg_src_data_base     = 0 ;
logic  [DADDR_WD-1:0]  rg_dest_data_base    = 0 ;
logic  [DADDR_WD-1:0]  rg_coef_base         = 0 ;
logic  [DADDR_WD-1:0]  rg_param_base        = 0 ;
logic  [DDATA_WD-1:0]  src_mem_rdata        = 0 ;
logic  [DDATA_WD-1:0]  dest_mem_rdata       = 0 ;
logic  [DDATA_WD-1:0]  wgt_mem_rdata        = 0 ;
logic  [DDATA_WD-1:0]  param_mem_rdata      = 0 ;

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
logic   conv_init                            = 0 ;
logic   conv_start                           = 0 ;

logic                src_mem_rd      ;
logic                src_mem_wr      ;
logic [DADDR_WD-1:0] src_mem_addr    ;
logic [DDATA_WD-1:0] src_mem_wdata   ;
logic [DDATA_WD/8-1:0] src_mem_wmask ;
logic                dest_mem_rd     ;
logic                dest_mem_wr     ;
logic [DADDR_WD-1:0] dest_mem_addr   ;
logic [DDATA_WD-1:0] dest_mem_wdata  ;
logic [DDATA_WD/8-1:0] dest_mem_wmask ;
logic                wgt_mem_rd      ;
logic                wgt_mem_wr      ;
logic [DADDR_WD-1:0] wgt_mem_addr    ;
logic [DDATA_WD-1:0] wgt_mem_wdata   ;
logic [DDATA_WD/8-1:0] wgt_mem_wmask ;
logic                param_mem_rd    ;
logic [DADDR_WD-1:0] param_mem_addr  ;
logic                conv_done       ;


initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial begin
    #(PERIOD*3.3) rst_n  =  1;
    repeat(5) begin @(negedge clk); end
    rg_batch_num                  = 0 ;
    rg_in_w                       = 10 ;
    rg_in_h                       = 10 ;
    rg_in_c                       = 20 ;
    rg_kernel_w                   = 3 ;
    rg_kernel_h                   = 3 ;
    rg_kernel_c                   = 20 ;
    rg_out_w                      = 8 ;   // todo
    rg_out_h                      = 8 ;   // todo
    rg_out_c                      = 44 ;
    rg_pad_x                      = 0 ;
    rg_pad_y                      = 0 ;
    rg_stride_w                   = 1 ;
    rg_stride_h                   = 1 ;
    rg_data_type                  = 0 ;
    rg_wgt_type                   = 0 ;
    rg_strip_len                  = 32 ;
    @(negedge clk);
    conv_init = 1;
    @(negedge clk);
    conv_init = 0;
    @(negedge clk);
    @(negedge clk);
    conv_start = 1;
    @(negedge clk);
    conv_start = 0;
    
    #(PERIOD*2000)
    $finish(2);

end

logic [DATA_WD-1:0] COEF_MEM [0:(1 << 8)-1];
logic [CDATA_WD-1:0] PARAM_MEM[0:(1 << 8)-1];
logic [DATA_WD-1:0] SRC_MEM [0:(1 << 8)-1];
logic [DATA_WD-1:0] DEST_MEM [0:(1 << 8)-1];
logic [7:0] dest_wdata [0:DATA_WB-1];
genvar i;

generate
    for(i=0;i<8;i=i+1) begin
        assign dest_wdata[i] = dest_mem_wmask[i]?   dest_mem_wdata[i*8+7:i*8] : DEST_MEM[dest_mem_addr][i*8+7:i*8];
    end
endgenerate

always_ff@(posedge clk) begin
    if(dest_mem_wr) begin
        DEST_MEM[dest_mem_addr] <= {dest_wdata[7],dest_wdata[6],dest_wdata[5],dest_wdata[4],dest_wdata[3],dest_wdata[2],dest_wdata[1],dest_wdata[0]};
        //case(data_mem_wmask)
        //    8'b00000001:    DEST_MEM[data_mem_addr] <= {DEST_MEM[data_mem_addr][63:8] , data_mem_wdata[7:0]};
        //    8'b00000011:    DEST_MEM[data_mem_addr] <= {DEST_MEM[data_mem_addr][63:16], data_mem_wdata[15:0]};
        //    8'b00000111:    DEST_MEM[data_mem_addr] <= {DEST_MEM[data_mem_addr][63:24], data_mem_wdata[23:0]};
        //    8'b00001111:    DEST_MEM[data_mem_addr] <= {DEST_MEM[data_mem_addr][63:32], data_mem_wdata[31:0]};
        //    8'b00011111:    DEST_MEM[data_mem_addr] <= {DEST_MEM[data_mem_addr][63:40], data_mem_wdata[39:0]};
        //    8'b00111111:    DEST_MEM[data_mem_addr] <= {DEST_MEM[data_mem_addr][63:48], data_mem_wdata[47:0]};
        //    8'b01111111:    DEST_MEM[data_mem_addr] <= {DEST_MEM[data_mem_addr][63:56], data_mem_wdata[55:0]};
        //    8'b11111111:    DEST_MEM[data_mem_addr] <= {data_mem_wdata[63:0]};
        //endcase
    end
end

initial begin
    $readmemb("../model/conv/conv_input_binary.txt",SRC_MEM);
end

initial begin
    $readmemb("../model/conv/conv_param_binary.txt",PARAM_MEM);
end

initial begin
    $readmemb("../model/conv/conv_coef_binary.txt",COEF_MEM);
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        src_mem_rdata <= 'd0;
    else if(src_mem_rd) begin
        src_mem_rdata <= SRC_MEM[src_mem_addr];
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        coef_mem_rdata <= 'd0;
    else if(coef_mem_rd) begin
        coef_mem_rdata <= COEF_MEM[coef_mem_addr];
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        param_mem_rdata <= 'd0;
    else if(param_mem_rd) begin
        param_mem_rdata <= PARAM_MEM[param_mem_addr];
    end
end

`ifdef SIM
    integer  output_file_bin;
    integer  output_file_dec;
    int j;
    logic [ADDR_WD-1:0] index;
    initial begin
        output_file_bin = $fopen("../rtl/conv_output_bin.txt","w+");
        output_file_dec = $fopen("../rtl/conv_output_dec.txt","w+");
        @(posedge conv_done);
        index <= (rg_dest_data_base >> 3);
        for(j=0;j<(rg_batch*rg_outc*rg_outw*rg_outh);j=j+1) begin
            @(negedge clk);
            $fwrite(output_file_bin,"%b\n",DEST_MEM[index]);
            $fwrite(output_file_dec,"%d\n",DEST_MEM[index][7:0]);
            $fwrite(output_file_dec,"%d\n",DEST_MEM[index][15:8]);
            $fwrite(output_file_dec,"%d\n",DEST_MEM[index][23:16]);
            $fwrite(output_file_dec,"%d\n",DEST_MEM[index][31:24]);
            $fwrite(output_file_dec,"%d\n",DEST_MEM[index][39:32]);
            $fwrite(output_file_dec,"%d\n",DEST_MEM[index][47:40]);
            $fwrite(output_file_dec,"%d\n",DEST_MEM[index][55:48]);
            $fwrite(output_file_dec,"%d\n",DEST_MEM[index][63:56]);

            index <= index+1;
        end
            $fclose(output_file_bin);
            $fclose(output_file_dec);
    end

`endif


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
    .rg_src_data_base                 ( rg_src_data_base            ) ,
    .rg_dest_data_base                ( rg_dest_data_base           ) ,
    .rg_coef_base                     ( rg_coef_base                ) ,
    .rg_param_base                    ( rg_param_base               ) ,
    .src_mem_rd                       ( src_mem_rd                  ) ,
    .src_mem_wr                       ( src_mem_wr                  ) ,
    .src_mem_addr                     ( src_mem_addr                ) ,
    .src_mem_rdata                    ( src_mem_rdata               ) ,
    .src_mem_wdata                    ( src_mem_wdata               ) ,
    .src_mem_wmask                    ( src_mem_wmask               ) ,  
    .dest_mem_rd                      ( dest_mem_rd                 ) ,
    .dest_mem_wr                      ( dest_mem_wr                 ) ,
    .dest_mem_addr                    ( dest_mem_addr               ) ,
    .dest_mem_rdata                   ( dest_mem_rdata              ) ,
    .dest_mem_wdata                   ( dest_mem_wdata              ) ,
    .dest_mem_wmask                   ( dest_mem_wmask              ) ,
    .wgt_mem_rd                       ( wgt_mem_rd                  ) ,
    .wgt_mem_wr                       ( wgt_mem_wr                  ) ,
    .wgt_mem_addr                     ( wgt_mem_addr                ) ,
    .wgt_mem_rdata                    ( wgt_mem_rdata               ) ,
    .wgt_mem_wdata                    ( wgt_mem_wdata               ) ,
    .wgt_mem_wmask                    ( wgt_mem_wmask               ) ,
    .param_mem_rd                     ( param_mem_rd                ) ,
    .param_mem_addr                   ( param_mem_addr              ) ,
    .param_mem_rdata                  ( param_mem_rdata             ) ,
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
    .mac_init                         ( conv_init                   ),
    .mac_start                        ( conv_start                  ),
    .mac_done                         ( conv_done                  )
);

initial begin
    $fsdbDumpfile("nn_top_tb.fsdb");
    $fsdbDumpvars();
    $fsdbDumpSVA();
    $fsdbDumpMDA();
end

endmodule