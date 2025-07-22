module analog_top(
    input   da_pixel_bias_en    ,
    input   da_pixel_vref_en    ,
    input   da_pixadc_ck        ,
    input   da_stb_en           ,
    input   da_pmu_fifocut      ,
    input   da_vcm_pow          ,
    input   da_vcm_qc_en        ,
    input   da_ib_pow           ,
    input   da_ldovref_pow      ,
    input   da_osc13m_pow       ,
    input   da_vcm_pulsemode    ,
    output  ad_osc400m          ,
    output  ad_pll100m          ,
    output  ad_wdt32k           ,
    output  ad_por_n            ,
    output [7:0] ad_pixadc_data 
);
parameter OSC400M_PRD = 2.5;
parameter PLL100M_PRD = 10;
parameter WDT32K_PRD = 31250;
always #(OSC400M_PRD/2)  ad_osc400m = ~ad_osc400m;
always #(PLL100M_PRD/2)  ad_pll100m = ~ad_pll100m;
always #(WDT32K_PRD/2)  ad_wdt32k = ~ad_wdt32k;

initial begin
    ad_osc400m = 0;
    ad_pll100m = 0;
    ad_wdt32k = 0;
    ad_por_n = 0;
    #92345
    ad_por_n = 1;
end

always@(posedge da_pixadc_ck) begin
    ad_pixadc_data <= $random();
end

endmodule