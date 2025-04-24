`timescale  1ns / 10ps

module tb_layernorm;

`define SIM

// layernorm Parameters
parameter PERIOD     = 10            ;
parameter ADDR_WD    = 32            ;
parameter DATA_WB    = 8             ;
parameter DATA_WD    = DATA_WB * 8   ;
parameter CADDR_WD   = 32            ;
parameter CDATA_WB   = 17            ;
parameter CDATA_WD   = CDATA_WB * 8  ;
parameter INT32_WD   = 32            ;
parameter INT64_WD   = 64            ;
parameter OFFSET     = $clog2(DATA_WB);
parameter PIPE_TIME  = 8             ;
parameter SHIFT_N    = 24            ;
parameter EPS        = 168           ;
parameter ACTMIN     = 0             ;
parameter ACTMAX     = 255           ;

// layernorm Inputs
logic   clk                                  = 0 ;
logic   rstn                                 = 0 ;
logic   [ADDR_WD-1:0]  rg_src_data_base          = 0 ;
logic   [ADDR_WD-1:0]  rg_dest_data_base          = 0 ;
logic   [CADDR_WD-1:0]  rg_coef_base         = 0 ;
logic   [7:0]  rg_batch                      = 0 ;
logic   [15:0]  rg_inh                       = 0 ;
logic   [15:0]  rg_inw                       = 0 ;
logic   [15:0]  rg_inc                       = 0 ;
logic   [15:0]  rg_outh                      = 0 ;
logic   [15:0]  rg_outw                      = 0 ;
logic   [15:0]  rg_outc                      = 0 ;
logic   [7:0]  rg_inzp                       = 0 ;
logic   [7:0]  rg_outzp                      = 0 ;
logic   [31:0]  rg_normsize                  = 0 ;
logic   rg_actvale                           = 0 ;
logic   [DATA_WD-1:0]  data_mem_rdata            ;
logic   [CDATA_WD-1:0]  coef_mem_rdata           ;
logic   layernorm_start                      = 0 ;

// layernorm Outputs
logic                data_mem_rd     ;
logic                data_mem_wr     ;
logic [DATA_WB-1:0]  data_mem_wmask  ;
logic [ADDR_WD-1:0]  data_mem_addr   ;
logic [DATA_WD-1:0]  data_mem_wdata  ;
logic                coef_mem_rd     ;
logic                coef_mem_wr     ;
logic [CDATA_WB-1:0] coef_mem_wmask  ;
logic [CADDR_WD-1:0] coef_mem_addr   ;
logic [CDATA_WD-1:0] coef_mem_wdata  ;
logic                layernorm_fail  ;
logic                layernorm_done  ;


initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #(PERIOD*3.3) rstn  =  1;
    repeat(5) begin @(negedge clk); end
    rg_batch     = 2  ;   
    rg_inw       = 2  ;   
    rg_inh       = 2  ;   
    rg_inc       = 30 ;    
    rg_normsize  = 15 ;
    rg_src_data_base = 8;
    rg_dest_data_base = 400;
    rg_coef_base = 0;
    rg_actvale   = 0;
    rg_inzp      = 0;
    rg_outzp     = 0;
    @(negedge clk);
    layernorm_start = 1;
    @(negedge clk);
    layernorm_start = 0;

    #(PERIOD*100000)
    $finish(2);
end

logic [CDATA_WD-1:0] COEF_MEM[0:(1 << 8)-1];
logic [DATA_WD-1:0] DEST_MEM [0:(1 << 8)-1];
logic [7:0] dest_wdata [0:DATA_WB-1];
genvar i;

generate
    for(i=0;i<8;i=i+1) begin
        assign dest_wdata[i] = data_mem_wmask[i]?   data_mem_wdata[i*8+7:i*8] : DEST_MEM[data_mem_addr][i*8+7:i*8];
    end
endgenerate

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        $readmemb("../model/layernorm/case_n15/layernorm_input_binary.txt",DEST_MEM);
    else if(data_mem_wr) begin
        DEST_MEM[data_mem_addr] <= {dest_wdata[7],dest_wdata[6],dest_wdata[5],dest_wdata[4],dest_wdata[3],dest_wdata[2],dest_wdata[1],dest_wdata[0]};
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
    $readmemb("../model/layernorm/case_n15/layernorm_coef_binary.txt",COEF_MEM);
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_mem_rdata <= 'd0;
    else if(data_mem_rd) begin
        data_mem_rdata <= DEST_MEM[data_mem_addr];
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        coef_mem_rdata <= 'd0;
    else if(coef_mem_rd) begin
        coef_mem_rdata <= COEF_MEM[coef_mem_addr];
    end
end


`ifdef SIM
    integer  output_file_bin;
    integer  output_file_dec;
    int j;
    logic [ADDR_WD-1:0] index;
    initial begin
        output_file_bin = $fopen("../rtl/layernorm_output_bin.txt","w+");
        output_file_dec = $fopen("../rtl/layernorm_output_dec.txt","w+");
        @(posedge layernorm_done);
        index <= (rg_dest_data_base >> 3);
        for(j=0;j<(rg_batch*rg_inc*rg_inw*rg_inh);j=j+1) begin
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
            //$fwrite(output_file_dec,"%d\t",DEST_MEM[index][63:56]);
            //$fwrite(output_file_dec,"%d\t",DEST_MEM[index][55:48]);
            //$fwrite(output_file_dec,"%d\t",DEST_MEM[index][47:40]);
            //$fwrite(output_file_dec,"%d\t",DEST_MEM[index][39:32]);
            //$fwrite(output_file_dec,"%d\t",DEST_MEM[index][31:24]);
            //$fwrite(output_file_dec,"%d\t",DEST_MEM[index][23:16]);
            //$fwrite(output_file_dec,"%d\t",DEST_MEM[index][15:8]);
            //$fwrite(output_file_dec,"%d\n",DEST_MEM[index][7:0]);

            index <= index+1;
        end
            $fclose(output_file_bin);
            $fclose(output_file_dec);
    end

`endif



layernorm #(
    .ADDR_WD   ( ADDR_WD   ),
    .DATA_WB   ( DATA_WB   ),
    .DATA_WD   ( DATA_WD   ),
    .CADDR_WD  ( CADDR_WD  ),
    .CDATA_WB  ( CDATA_WB  ),
    .CDATA_WD  ( CDATA_WD  ),
    .INT32_WD  ( INT32_WD  ),
    .INT64_WD  ( INT64_WD  ),
    .OFFSET    ( OFFSET    ),
    .PIPE_TIME ( PIPE_TIME ),
    .SHIFT_N   ( SHIFT_N   ),
    .EPS       ( EPS       ),
    .ACTMIN    ( ACTMIN    ),
    .ACTMAX    ( ACTMAX    ))
 u_layernorm (
    .clk             ( clk                            ),
    .rstn            ( rstn                           ),
    .rg_src_data_base    ( rg_src_data_base                   ),
    .rg_dest_data_base    ( rg_dest_data_base                   ),
    .rg_coef_base    ( rg_coef_base                   ),
    .rg_batch        ( rg_batch                       ),
    .rg_inh          ( rg_inh                         ),
    .rg_inw          ( rg_inw                         ),
    .rg_inc          ( rg_inc                         ),
    .rg_outh         ( rg_outh                        ),
    .rg_outw         ( rg_outw                        ),
    .rg_outc         ( rg_outc                        ),
    .rg_inzp         ( rg_inzp                        ),
    .rg_outzp        ( rg_outzp                       ),
    .rg_normsize     ( rg_normsize                    ),
    .rg_actvale      ( rg_actvale                     ),
    .data_mem_rdata  ( data_mem_rdata                 ),
    .coef_mem_rdata  ( coef_mem_rdata                 ),
    .layernorm_start ( layernorm_start                ),
    .data_mem_rd     ( data_mem_rd                    ),
    .data_mem_wr     ( data_mem_wr                    ),
    .data_mem_wmask  ( data_mem_wmask                 ),
    .data_mem_addr   ( data_mem_addr                  ),
    .data_mem_wdata  ( data_mem_wdata                 ),
    .coef_mem_rd     ( coef_mem_rd                    ),
    .coef_mem_wr     ( coef_mem_wr                    ),
    .coef_mem_wmask  ( coef_mem_wmask                 ),
    .coef_mem_addr   ( coef_mem_addr                  ),
    .coef_mem_wdata  ( coef_mem_wdata                 ),
    .layernorm_fail  ( layernorm_fail                 ),
    .layernorm_done  ( layernorm_done                 )
);

initial
begin
    $fsdbDumpfile("layernorm_tb.fsdb");
    $fsdbDumpvars();
    $fsdbDumpSVA();
    $fsdbDumpMDA();
end


endmodule