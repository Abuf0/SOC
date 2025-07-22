module crgu(
    input           scan_mode           ,
    input           scan_enable         ,
    input           scan_clk            ,
    input           scan_rstn           ,
    input           ad_osc400m          ,
    input           ad_pll100m          ,
    input           wdt_32k             ,
    input           spi_ck              ,
    input           ad_por_n            ,
    input           cmd_idle            ,
    input           da_stb_en           ,   // 32k
    input           shut_rstn           ,   // 32k
    input           rg_fifo_reset       ,   // 5M
    input           rg_fifo_ckgt_en     ,   // 5M
    input           rg_afe_ckgt_en      ,   // 5M
    input           rg_isp_ckgt_en      ,   // 5M
    input           reg_ckgt_case       ,   // 5M
    input           afe_icg_en          ,   // 100M
    input           isp_icg_en          ,   // 400M
    output logic    clk_reg             ,
    output logic    clk_fifo            ,
    output logic    clk_tim             ,
    output logic    clk_afe             ,
    output logic    clk_isp             ,
    output logic    clk_32k             ,
    output logic    clk_spi             ,
    output logic    rstn_reg            ,
    output logic    rstn_fifo           ,
    output logic    rstn_tim            ,
    output logic    rstn_afe            ,
    output logic    rstn_isp            ,
    output logic    rstn_32k            ,
    output logic    rstn_spi
);

logic clk_400m_scan;
logic clk_100m_scan;
logic clk_20m;
logic clk_5m;
logic timer_enable;  
logic isp_enable;   
logic fifo_enable;  
logic afe_enable;
logic shut_enable;

logic rstn_400m;

logic async_reset_alon;
logic async_reset_shut;
logic async_reset_fifo;

// clock
ckmax osc400m_scanmux (.in0(ad_osc400m), .in1(scan_clk), .sel(scan_mode), .out(clk_400m_scan));
ckmax pll100m_scanmux (.in0(ad_pll100m), .in1(scan_clk), .sel(scan_mode), .out(clk_100m_scan));
ckmax wdt32k_scanmux (.in0(wdt_32k), .in1(scan_clk), .sel(scan_mode), .out(clk_32k));
ckmax spick_scanmux (.in0(spi_ck), .in1(scan_clk), .sel(scan_mode), .out(clk_spi));

div_clk clk_div_0 #(.DIV_WID(4))(.clk(clk_400m_scan), .rstn(rstn_400m), .div_dat_even(20), .clk_div_o(clk_20m));
div_clk clk_div_1 #(.DIV_WID(4))(.clk(clk_20m), .rstn(rstn_400m), .div_dat_even(4), .clk_div_o(clk_5m));

ckgate_cell ckgt_reg_isnt(.clkin(clk_5m), .enable(reg_ckgt_case), .scan_en(scan_enable), .clkout(clk_reg));
ckgate_cell ckgt_tim_isnt(.clkin(clk_20m), .enable(timer_enable), .scan_en(scan_enable), .clkout(clk_tim));

ckgate_cell ckgt_isp_isnt(.clkin(clk_400m_scan), .enable(isp_enable), .scan_en(scan_enable), .clkout(clk_isp));
ckgate_cell ckgt_fifo_isnt(.clkin(clk_400m_scan), .enable(fifo_enable), .scan_en(scan_enable), .clkout(clk_fifo));

ckgate_cell ckgt_afe_isnt(.clkin(clk_100m_scan), .enable(afe_enable), .scan_en(scan_enable), .clkout(clk_afe));

sync_level afe_enable_sync(.clk(clk_100m_scan), .rstn(rstn_afe), .level_in(~da_stb_en), .level_out(afe_enable));
sync_level shut_enable_sync(.clk(clk_400m_scan), .rstn(rstn_400m), .level_in(~da_stb_en), .level_out(shut_enable));

assign fifo_enable = ~rg_fifo_ckgt_en;
assign isp_enable = ~rg_isp_ckgt_en && shut_enable;
assign timer_enable = shut_enable;
// reset
assign async_reset_alon = ~ad_por_n | cmd_idle;
assign async_reset_shut = ~ad_por_n | cmd_idle | ~shut_rstn;
assign async_reset_fifo = ~ad_por_n | cmd_idle | rg_fifo_reset;

sync_reset rstn_400m_inst(.clk(clk_400m_scan), .async_reset(async_reset_alon), .sync_rstn(rstn_400m));
sync_reset rstn_fifo_inst(.clk(clk_fifo), .async_reset(async_reset_fifo), .sync_rstn(rstn_fifo));
sync_reset rstn_reg_inst(.clk(clk_reg), .async_reset(async_reset_alon), .sync_rstn(rstn_reg));
sync_reset rstn_tim_inst(.clk(clk_tim), .async_reset(async_reset_shut), .sync_rstn(rstn_tim));
sync_reset rstn_afe_inst(.clk(clk_afe), .async_reset(async_reset_shut), .sync_rstn(rstn_afe));
sync_reset rstn_32k_inst(.clk(clk_32k), .async_reset(async_reset_alon), .sync_rstn(rstn_32k));
sync_reset rstn_spi_inst(.clk(clk_spi), .async_reset(async_reset_alon), .sync_rstn(rstn_spi));

assign rstn_isp = rstn_400m;

endmodule