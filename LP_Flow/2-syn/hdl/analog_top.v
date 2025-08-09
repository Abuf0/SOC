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
    output  reg ad_osc400m          ,
    output  reg ad_pll100m          ,
    output  reg ad_wdt32k           ,
    output  reg ad_por_n            ,
    output  reg [7:0] ad_pixadc_data 
);


endmodule