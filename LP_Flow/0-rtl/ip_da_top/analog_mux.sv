module analog_mux(
    input   scan_mode                ,
    input   da_pixel_bias_en         ,
    input   da_pixel_vref_en         ,
    input   da_pixadc_ck             ,
    input   da_stb_en                ,
    input   da_pmu_fifocut           ,
    input   da_vcm_pow               ,
    input   da_vcm_qc_en             ,
    input   da_ib_pow                ,
    input   da_ldovref_pow           ,
    input   da_osc13m_pow            ,
    input   da_vcm_pulsemode         ,
    input   ad_osc400m               ,
    input   ad_pll100m               ,
    input   ad_wdt32k                ,
    input   ad_por_n                 ,
    input  [7:0] ad_pixadc_data      ,
    output  da_pixel_bias_en_scan    ,
    output  da_pixel_vref_en_scan    ,
    output  da_pixadc_ck_scan        ,
    output  da_stb_en_scan           ,
    output  da_pmu_fifocut_scan      ,
    output  da_vcm_pow_scan          ,
    output  da_vcm_qc_en_scan        ,
    output  da_ib_pow_scan           ,
    output  da_ldovref_pow_scan      ,
    output  da_osc13m_pow_scan       ,
    output  da_vcm_pulsemode_scan    ,
    output  ad_osc400m_scan          ,
    output  ad_pll100m_scan          ,
    output  ad_wdt32k_scan           ,
    output  ad_por_n_scan            ,
    output  [7:0] ad_pixadc_data_scan 
);
assign da_pixel_bias_en_scan    = scan_mode?    1'b0 : da_pixel_bias_en ;   
assign da_pixel_vref_en_scan    = scan_mode?    1'b0 : da_pixel_vref_en ;
assign da_pixadc_ck_scan        = scan_mode?    1'b0 : da_pixadc_ck     ;
assign da_stb_en_scan           = scan_mode?    1'b1 : da_stb_en        ;
assign da_pmu_fifocut_scan      = da_pmu_fifocut   ;
assign da_vcm_pow_scan          = scan_mode?    1'b0 : da_vcm_pow       ;
assign da_vcm_qc_en_scan        = da_vcm_qc_en     ;
assign da_ib_pow_scan           = scan_mode?    1'b0 : da_ib_pow        ;
assign da_ldovref_pow_scan      = scan_mode?    1'b0 : da_ldovref_pow   ;
assign da_osc13m_pow_scan       = scan_mode?    1'b0 : da_osc13m_pow    ;
assign da_vcm_pulsemode_scan    = da_vcm_pulsemode ;
assign ad_osc400m_scan          = ad_osc400m ;
assign ad_pll100m_scan          = ad_pll100m ;
assign ad_wdt32k_scan           = ad_wdt32k  ;
assign ad_por_n_scan            = ad_por_n   ;
assign ad_pixadc_data_scan      = ad_pixadc_data;
endmodule