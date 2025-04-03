`timescale  1ns / 10ps

module tb_pixelshuffle;
`define SIM
// pixelshuffle Parameters
parameter PERIOD   = 10            ;
parameter DATA_WB  = 8             ;
parameter DATA_WD  = DATA_WB * 8   ;
parameter ADDR_WD  = 16            ;
parameter OFFSET   = $clog2(DATA_WB);

// pixelshuffle Inputs
logic   clk                                  = 0 ;
logic   rstn                                 = 0 ;
logic   [ADDR_WD-1:0]  rg_src_base           = 2 ;
logic   [ADDR_WD-1:0]  rg_dest_base          = 5 ;
logic   [2:0]  rg_rfactor                    = 0 ;
logic   [7:0]  rg_batch                      = 0 ;
logic   [15:0]  rg_inh                       = 0 ;
logic   [15:0]  rg_inw                       = 0 ;
logic   [15:0]  rg_inc                       = 0 ;
logic   [15:0]  rg_outh    ; //                 = 0 ;
logic   [15:0]  rg_outw    ; //                 = 0 ;
logic   [15:0]  rg_outc    ; //                 = 0 ;
logic   [DATA_WD-1:0]  mem_src_rdata         ;
logic   [DATA_WD-1:0]  mem_dest_rdata        ;
logic   pixshff_start                        = 0 ;

// pixelshuffle Outputs
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
logic                pixshff_done    ;


initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

assign rg_outh = rg_inh * rg_rfactor;
assign rg_outw = rg_inw * rg_rfactor;
assign rg_outc = rg_inc / rg_rfactor / rg_rfactor;

initial begin
    #(PERIOD*3.3) rstn  =  1;
    repeat(5) begin @(negedge clk); end
    rg_batch   = 2 ;
    rg_inw     = 2 ;
    rg_inh     = 2 ;
    rg_inc     = 90 ;   // 90 // 144 // 44
    rg_rfactor = 3  ;   // 3  // 4   // 2
    @(negedge clk);
    pixshff_start = 1;
    @(negedge clk);
    pixshff_start = 0;
    
    #(PERIOD*10000)
    $finish(2);

end
logic [ADDR_WD-1:0] mem_src_addr_real;
logic [7:0] redunt;
logic [7:0] mode0;
logic [7:0] mode1;
logic [7:0] mode2;
logic [7:0] mode3;
logic [7:0] mode4;
logic [7:0] mode5;
logic [7:0] mode6;
logic [7:0] mode7;
logic [7:0] aligned_inc_div8;
assign mem_src_addr_real = (mem_src_addr-rg_src_base);
assign aligned_inc_div8 = (rg_inc % 8 == 0)?    rg_inc/8 : (rg_inc/8 + 1);
assign redunt = (mem_src_addr_real % aligned_inc_div8) % (rg_rfactor * rg_rfactor);    // todo
assign mode0 = (redunt==0)?  'd0 : (rg_rfactor * rg_rfactor) - redunt;
assign mode1 = (mode0+1) % (rg_rfactor * rg_rfactor);
assign mode2 = (mode0+2) % (rg_rfactor * rg_rfactor);
assign mode3 = (mode0+3) % (rg_rfactor * rg_rfactor);
assign mode4 = (mode0+4) % (rg_rfactor * rg_rfactor);
assign mode5 = (mode0+5) % (rg_rfactor * rg_rfactor);
assign mode6 = (mode0+6) % (rg_rfactor * rg_rfactor);
assign mode7 = (mode0+7) % (rg_rfactor * rg_rfactor);

logic [63:0] seq4x4_0;
logic [63:0] seq4x4_1;
logic [63:0] seq4x4;

assign seq4x4_0 = {8'd7,8'd6,8'd5,8'd4,8'd3,8'd2,8'd1,8'd0};
assign seq4x4_1 = {8'd15,8'd14,8'd13,8'd12,8'd11,8'd10,8'd9,8'd8};
assign seq4x4 = mem_src_addr_real[0]?    seq4x4_1 : seq4x4_0;

logic [63:0] seq2x2;
assign seq2x2 = {8'hf3,8'hf2,8'hf1,8'hf0,8'h3,8'h2,8'h1,8'h0};

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        mem_src_rdata <= 'd0;
    else if(mem_src_rd) begin
        if(rg_rfactor == 3)
            mem_src_rdata <= {mode7,mode6,mode5,mode4,mode3,mode2,mode1,mode0};
        else if(rg_rfactor == 4)
            mem_src_rdata <= seq4x4;
        else if(rg_rfactor == 2)
            mem_src_rdata <= seq2x2;
    end
end


logic [DATA_WD-1:0] DATA_MEM [0:(1 << 13)-1];

always_ff@(posedge clk or negedge rstn) begin
    if(mem_dest_wr) begin
        case(mem_dest_wmask)
            8'b00000001:    DATA_MEM[mem_dest_addr] <= {DATA_MEM[mem_dest_addr][63:8], mem_dest_wdata[7:0]};
            8'b00000011:    DATA_MEM[mem_dest_addr] <= {DATA_MEM[mem_dest_addr][63:16], mem_dest_wdata[15:0]};
            8'b00000111:    DATA_MEM[mem_dest_addr] <= {DATA_MEM[mem_dest_addr][63:24], mem_dest_wdata[23:0]};
            8'b00001111:    DATA_MEM[mem_dest_addr] <= {DATA_MEM[mem_dest_addr][63:32], mem_dest_wdata[31:0]};
            8'b00011111:    DATA_MEM[mem_dest_addr] <= {DATA_MEM[mem_dest_addr][63:40], mem_dest_wdata[39:0]};
            8'b00111111:    DATA_MEM[mem_dest_addr] <= {DATA_MEM[mem_dest_addr][63:48], mem_dest_wdata[47:0]};
            8'b01111111:    DATA_MEM[mem_dest_addr] <= {DATA_MEM[mem_dest_addr][63:56], mem_dest_wdata[55:0]};
            8'b11111111:    DATA_MEM[mem_dest_addr] <= {mem_dest_wdata[63:0]};
        endcase
    end
end

`ifdef SIM
    integer  output_file_bin;
    integer  output_file_dec;
    int j;
    logic [ADDR_WD-1:0] index;
    initial begin
        output_file_bin = $fopen("../rtl/pixshff_output_data_bin.txt","w+");
        output_file_dec = $fopen("../rtl/pixshff_output_data_dec.txt","w+");
        index <= 0;
        @(posedge pixshff_done);
        for(j=0;j<1000;j=j+1) begin
            @(negedge clk);
            $fwrite(output_file_bin,"%b\n",DATA_MEM[index]);
            $fwrite(output_file_dec,"%d\t",DATA_MEM[index][7:0]);
            $fwrite(output_file_dec,"%d\t",DATA_MEM[index][15:8]);
            $fwrite(output_file_dec,"%d\t",DATA_MEM[index][23:16]);
            $fwrite(output_file_dec,"%d\t",DATA_MEM[index][31:24]);
            $fwrite(output_file_dec,"%d\t",DATA_MEM[index][39:32]);
            $fwrite(output_file_dec,"%d\t",DATA_MEM[index][47:40]);
            $fwrite(output_file_dec,"%d\t",DATA_MEM[index][55:48]);
            $fwrite(output_file_dec,"%d\n",DATA_MEM[index][63:56]);
            index <= index+1;
        end
            $fclose(output_file_bin);
            $fclose(output_file_dec);
    end

`endif

pixshff #(
    .DATA_WB ( DATA_WB ),
    .DATA_WD ( DATA_WD ),
    .ADDR_WD ( ADDR_WD ),
    .OFFSET  ( OFFSET  ))
 u_pixelshuffle (
    .clk             ( clk                             ),
    .rstn            ( rstn                            ),
    .rg_src_base     ( rg_src_base                     ),
    .rg_dest_base    ( rg_dest_base                    ),
    .rg_rfactor      ( rg_rfactor                      ),
    .rg_batch        ( rg_batch                        ),
    .rg_inh          ( rg_inh                          ),
    .rg_inw          ( rg_inw                          ),
    .rg_inc          ( rg_inc                          ),
    .rg_outh         ( rg_outh                         ),
    .rg_outw         ( rg_outw                         ),
    .rg_outc         ( rg_outc                         ),
    .mem_src_rdata   ( mem_src_rdata                   ),
    .mem_dest_rdata  ( mem_dest_rdata                  ),
    .pixshff_start   ( pixshff_start                   ),
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
    .pixshff_done    ( pixshff_done                  )
);

initial begin
    $fsdbDumpfile("pixelshuffle_tb.fsdb");
    $fsdbDumpvars();
    $fsdbDumpSVA();
    $fsdbDumpMDA();
end

endmodule