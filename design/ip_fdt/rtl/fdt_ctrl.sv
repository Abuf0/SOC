module fdt_ctrl(
    input                       clk_fdt                 ,
    input                       rstn_fdt                ,
    input                       clk_sys                 ,
    input                       rstn_sys                ,
    /* 数据data cache的控制 */
    output logic                cache_ena               ,
    output logic [3:0]          cache_wena              ,
    output logic [4:0]          cache_addr              ,
    output logic [63:0]         cache_wdata             ,
    input        [63:0]         cache_rdata             ,
    /* 参数coef cache的控制 */
    output logic                coef_ena                ,
    output logic [3:0]          coef_wena               ,
    output logic [5:0]          coef_addr               ,
    output logic [63:0]         coef_wdata              ,
    input        [63:0]         coef_rdata              ,
    /* FDT cache和coef的SPI读写使能和控制 */
    input                       rg_fdt_cache_spi_rw_en  ,
    input                       rg_fdt_coef_spi_rw_en   ,
    input                       fdtmem_rd               ,
    input                       fdtmem_wr               ,
    input [15:0]                fdtmem_addr             ,
    input [15:0]                fdtmem_wdata            ,
    output logic [15:0]         fdtmem_rdata            ,
    /* amp cache的读写控制 */
    input                       amp_cache_ena           ,
    input                       amp_cache_wena          ,
    input [4:0]                 amp_cache_addr          ,
    input [63:0]                amp_cache_wdata         ,
    output logic [63:0]         amp_cache_rdata         ,
    /* norm cache的读写控制 */
    input                       norm_cache_ena          ,
    input [3:0]                 norm_cache_wena         ,
    input [4:0]                 norm_cache_addr         ,
    input [63:0]                norm_cache_wdata        ,
    output logic [63:0]         norm_cache_rdata        ,
    /* nn cache的读写控制 */
    input                       nn_cache_ena            ,
    input                       nn_cache_wena           ,
    input [4:0]                 nn_cache_addr           ,
    input [63:0]                nn_cache_wdata          ,
    output logic [63:0]         nn_cache_rdata          ,
    /* nn coef参数读控制 */
    input                       nn_coef_ena             ,
    input [5:0]                 nn_coef_addr            ,
    output logic [63:0]         nn_coef_rdata           ,

    input                       rg_fdt_en               ,
    input                       rg_fdt_iq_calc_en       ,
    input                       adc_data_in_vld         ,
    input                       amp_done                ,
    input                       amp_trig_norm           ,
    input                       amp_mean_vld            ,
    input                       norm_done               ,
    input                       norm_trig_NN            ,
    input                       NN_unit_done            ,
    output logic                NN_unit_start           ,
    output logic                amp_enable              ,
    output logic                amp_iq_data_to_fifo_en  ,
    output logic                norm_enable             ,
    output logic                amp_working             ,
    output logic                norm_working            ,
    output logic                NN_working              ,
    input                       rg_fdt_soft_clr         ,
    output logic                soft_clr                ,
    input                       rg_fdt_wait_up          ,
    input                       rg_fdt_wait_down        ,
    input                       rg_fdt_auto_exit_en     ,
    input                       dec_result              ,
    input                       dec_result_vld          ,
    output logic                fdt_up_int_sys          ,
    output logic                fdt_down_int_sys        ,
    output logic                fdt_auto_exit_pulse     ,
    output logic                fdt_done_sys            ,
    input                       amp_iq_vld_to_fifo      ,
    input [11:0]                amp_iq_data_to_fifo     ,
    output logic                amp_iq_vld_to_fifo_sys  ,
    output logic [11:0]         amp_iq_data_to_fifo_sys

);

typedef enum logic [2:0] {IDLE, AMP, NORM, NN, DONE} state_t;
state_t state_s, state_n;

always@(posedge clk_fdt or negedge rstn_fdt) begin
    if(~rstn_fdt)
        state_s <= IDLE;
    else
        state_s = state_n;
end

always@(*) begin
    state_n = state_s;
    case(state_s)
        IDLE:   state_n = amp_start?    AMP : IDLE;
        AMP:    state_n = amp_trig_norm?  norm_enable?  NORM : DONE : AMP;
        NORM:   state_n = norm_done?    norm_trig_NN?   NN : DONE : NORM;
        NN:     state_n = NN_unit_done?  DONE : NN;
        DONE:   staet_n = IDLE;
        default: ;
    endcase
end

assign amp_start = (state_s == IDLE) && (amp_enable && adc_data_in_vld);
assign amp_enable = rg_fdt_en || rg_fdt_iq_calc_en;
assign norm_enable = rg_fdt_en;

always@(posedge clk_fdt or negedge rstn_fdt) begin
    if(~rstn_fdt)
        amp_working_p <= 1'b0;
    else if(amp_done)
        amp_working_p <= 1'b0;
    else if(amp_enable && adc_data_in_vld)
        amp_working_p <= 1'b1;
end

assign amp_working_p_nxt = !amp_working_p && (amp_enable && adc_data_in_vld);
assign amp_working = amp_working_p_nxt | amp_working_p;

always@(posedge clk_fdt or negedge rstn_fdt) begin
    if(~rstn_fdt)
        norm_working_p <= 1'b0;
    else if(norm_done)
        norm_working_p <= 1'b0;
    else if(norm_enable && amp_mean_vld)
        norm_working_p <= 1'b1;
end

assign norm_working_p_nxt = !norm_working_p && (norm_enable && amp_mean_vld);
assign norm_working = norm_working_p_nxt | norm_working_p;

always@(posedge clk_fdt or negedge rstn_fdt) begin
    if(~rstn_fdt)
        NN_unit_start_q <= 2'b0;
    else
        NN_unit_start_q <= {NN_unit_start_q[0], norm_trig_NN};
end

assign NN_unit_start = |NN_unit_start_q;

always@(posedge clk_fdt or negedge rstn_fdt) begin
    if(~rstn_fdt)
        NN_unit_done_d <= 1'b0;
    else if(NN_unit_done_d)
        NN_unit_done_d <= 1'b0;
    else if(NN_unit_done)
        NN_unit_done_d <= 1'b1;
end

always@(posedge clk_fdt or negedge rstn_fdt) begin
    if(~rstn_fdt)
        NN_working <= 1'b0;
    else if(NN_unit_done_d)
        NN_working <= 1'b0;
    else if(norm_trig_NN)
        NN_working <= 1'b1;
end

assign soft_clr = rg_fdt_soft_clr;

assign spi_rw_cache_sel = (fdtmem_addr>=`SPI_CACHE_BASE_STA_ADDR) && (fdtmem_addr<=`SPI_CACHE_BASE_END_ADDR);
assign spi_rw_coef_sel  = (fdtmem_addr>=`SPI_COEF_BASE_STA_ADDR) && (fdtmem_addr<=`SPI_COEF_BASE_END_ADDR);

always@(posedge clk_sys or negedge rstn_sys) begin
    if(~rstn_sys)
        fdtmem_addr_b1b2 <= 2'b0;
    else if(fdtmem_rd)
        fdtmem_addr_b1b2 <= fdtmem_addr[2:1];
end

always@(posedge clk_sys or negedge rstn_sys) begin
    if(~rstn_sys)
        fdtmem_rd_d <= 1'b0;
    else 
        fdtmem_rd_d <= fdtmem_rd;
end

assign spi_mem_wr = fdtmem_wr && (spi_rw_cache_sel || spi_rw_coef_sel);
assign spi_mem_rd = fdtmem_rd && (spi_rw_cache_sel || spi_rw_coef_sel);
assign spi_mem_ena = spi_mem_wr | spi_mem_rd;

always@(*) begin
    if(spi_mem_wr) begin
        case(fdtmem_addr[2:0])
            2'd0:   spi_mem_wena = 4'b0001;
            2'd1:   spi_mem_wena = 4'b0010;
            2'd2:   spi_mem_wena = 4'b0100;
            2'd3:   spi_mem_wena = 4'b1000;
        endcase
    end
    else 
        spi_mem_wena = 4'b0000;
end

always@(*) begin
    if(spi_mem_wr) begin
        case(fdtmem_addr[2:0])
            2'd0:   spi_mem_wdata = {48'd0, fdtmem_wdata};
            2'd1:   spi_mem_wdata = fdtmem_wdata<<16;
            2'd2:   spi_mem_wdata = fdtmem_wdata<<32;
            2'd3:   spi_mem_wdata = fdtmem_wdata<<48;
        endcase
    end
    else 
        spi_mem_wdata = 64'h0;
end

always@(*) begin
    if(spi_cache_spi_rw_en) begin
        case(fdtmem_addr_b1b2)
            2'd0:   fdtmem_rdata = cache_rdata[15: 0];
            2'd1:   fdtmem_rdata = cache_rdata[31:16];
            2'd2:   fdtmem_rdata = cache_rdata[47:32];
            2'd3:   fdtmem_rdata = cache_rdata[63:48];
        endcase
    end
    else if(spi_coef_spi_rw_en) begin
        case(fdtmem_addr_b1b2)
            2'd0:   fdtmem_rdata = coef_rdata[15: 0];
            2'd1:   fdtmem_rdata = coef_rdata[31:16];
            2'd2:   fdtmem_rdata = coef_rdata[47:32];
            2'd3:   fdtmem_rdata = coef_rdata[63:48];
        endcase
    end
    else
        fdtmem_rdata = 16'd0;
end

assign spi_mem_addr = fdtmem_addr[15:3];

assign rg_fdt_cache_spi_rw_en = rg_fdt_cache_spi_rw_en && spi_rw_cache_sel && (fdtmem_wr || fdtmem_rd || fdtmem_rd_d);
assign rg_fdt_coef_spi_rw_en = rg_fdt_coef_spi_rw_en && spi_rw_coef_sel && (fdtmem_wr || fdtmem_rd || fdtmem_rd_d);

assign cache_ena = fdt_cache_spi_rw_en?  spi_mem_addr[4:0] : (amp_cache_ena | norm_cache_ena | nn_cache_ena);
assign cache_wena = fdt_cache_spi_rw_en?    spi_mem_wena : 
                    amp_cache_ena?   {4{amp_cache_wena}} :
                    norm_cache_ena?  norm_cache_wena :
                    nn_cache_ena?   {4{nn_cache_wena}} : 4'b0;

assign cache_addr = fdt_cache_spi_rw_en?    spi_mem_addr[4:0] :
                    amp_cache_ena?   amp_cache_addr :
                    norm_cache_ena?  norm_cache_addr :
                    nn_cache_ena?   nn_cache_addr : 5'b0;

assign cache_wdata = fdt_cache_spi_rw_en?    spi_mem_wdata[4:0] :
                    amp_cache_ena?   amp_cache_wdata :
                    norm_cache_ena?  norm_cache_wdata :
                    nn_cache_ena?   nn_cache_wdata : 64'b0;

assign amp_cache_rdata = cache_rdata;
assign norm_cache_rdata = cache_rdata;
assign nn_cache_rdata = cache_rdata;

assign coef_ena   = fdt_coef_spi_rw_en?  spi_mem_ena   : nn_coef_ena;
assign coef_wena  = fdt_coef_spi_rw_en?  spi_mem_wena  : 4'b0;
assign coef_addr  = fdt_coef_spi_rw_en?  spi_mem_addr[5:0]  : nn_coef_addr;
assign coef_wdata = fdt_coef_spi_rw_en?  spi_mem_wdata : 64'b0;
assign coef_rdata = fdt_coef_spi_rw_en?  spi_mem_rdata : coef_rdata;

always@(posedge clk_fdt or negedge rstn_fdt) begin
    if(~rstn_fdt)
        dec_result_vld_w <= 1'b0;
    else if(dec_result_vld_sys)
        dec_result_vld_w <= 1'b0;
    else if(dec_result_vld)
        dec_result_vld_w <= 1'b1;
end

always@(posedge clk_sys or negedge rstn_sys) begin
    if(~rstn_sys)
        dec_result_vld_sys <= 1'b0;
    else if(dec_result_vld_w)
        dec_result_vld_sys <= 1'b1;
    else if(dec_result_vld_sys)
        dec_result_vld_sys <= 1'b0;
end

always@(posedge clk_sys or negedge rstn_sys) begin
    if(~rstn_sys)
        fdt_up_int_sys <= 1'b0;
    else if(rg_fdt_wait_up && dec_result_vld_sys && ~dec_result)
        fdt_up_int_sys <= 1'b1;
    else if(fdt_up_int_sys)
        fdt_up_int_sys <= 1'b0;
end

always@(posedge clk_sys or negedge rstn_sys) begin
    if(~rstn_sys)
        fdt_down_int_sys <= 1'b0;
    else if(rg_fdt_wait_down && dec_result_vld_sys && ~dec_result)
        fdt_down_int_sys <= 1'b1;
    else if(fdt_down_int_sys)
        fdt_down_int_sys <= 1'b0;
end

assign fdt_auto_exit_pulse = rg_fdt_auto_exit_en && (fdt_up_int_sys || fdt_down_int_sys);

assign fdt_done = (state_s == DONE);

always@(posedge clk_fdt or negedge rstn_fdt) begin
    if(~rstn_fdt)
        fdt_done_lvl <= 1'b0;
    else if(fdt_done_sys)
        fdt_done_lvl <= 1'b0;
    else if(fdt_done)
        fdt_done_lvl <= 1'b1;
end

always@(posedge clk_sys or negedge rstn_sys) begin
    if(~rstn_sys)
        fdt_done_sys <= 1'b0;
    else if(soft_clr)
        fdt_done_sys <= 1'b1
    else if(fdt_done_sys)
        fdt_done_sys <= 1'b0;
    else if(fdt_done_lvl)
        fdt_done_sys <= 1'b1;
end

always@(posedge clk_fdt or negedge rstn_fdt) begin
    if(~rstn_fdt)
        amp_iq_vld_to_fifo_fdt <= 1'b0;
    else if(amp_iq_vld_to_fifo_sys)
        amp_iq_vld_to_fifo_fdt <= 1'b0;
    else if(amp_iq_vld_to_fifo)
        amp_iq_vld_to_fifo_fdt <= 1'b1;
end

always@(posedge clk_fdt or negedge rstn_fdt) begin
    if(~rstn_fdt)
        amp_iq_data_to_fifo_fdt <= 12'd0;
    else if(amp_iq_vld_to_fifo)
        amp_iq_data_to_fifo_fdt <= amp_iq_data_to_fifo;
end

always@(posedge clk_sys or negedge rstn_sys) begin
    if(~rstn_sys)
        amp_iq_vld_to_fifo_sys <= 1'b0;
    else if(amp_iq_vld_to_fifo_sys)
        amp_iq_vld_to_fifo_sys <= 1'b0;
    else if(amp_iq_vld_to_fifo_fdt)
        amp_iq_vld_to_fifo_sys <= 1'b1;
end

assign amp_iq_vld_to_fifo_sys = amp_iq_vld_to_fifo_fdt;

endmodule