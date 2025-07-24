module lp_soc_top(
    inout          PAD_SCK                  ,
    inout          PAD_CSN                  ,
    inout          PAD_MISO                 ,
    inout          PAD_MOSI                 ,
    inout          PAD_INT                  ,
    inout          PAD_MPX                  ,
    inout          VDD                      ,
    inout          GND                      
);

da_top  u_da_top (
    .scan_mode               ( scan_mode               ),
    .da_pixel_bias_en        ( da_pixel_bias_en        ),
    .da_pixel_vref_en        ( da_pixel_vref_en        ),
    .da_pixadc_ck            ( da_pixadc_ck            ),
    .da_stb_en               ( da_stb_en               ),
    .da_pmu_fifocut          ( da_pmu_fifocut          ),
    .da_vcm_pow              ( da_vcm_pow              ),
    .da_vcm_qc_en            ( da_vcm_qc_en            ),
    .da_ib_pow               ( da_ib_pow               ),
    .da_ldovref_pow          ( da_ldovref_pow          ),
    .da_osc13m_pow           ( da_osc13m_pow           ),
    .da_vcm_pulsemode        ( da_vcm_pulsemode        ),

    .ad_osc400m              ( ad_osc400m              ),
    .ad_pll100m              ( ad_pll100m              ),
    .ad_wdt32k               ( ad_wdt32k               ),
    .ad_por_n                ( ad_por_n                ),
    .ad_pixadc_data          ( ad_pixadc_data          )
);

digital_top u_digital_top (
    .ad_osc400m        ( ad_osc400m              ),
    .ad_pll100m        ( ad_pll100m              ),
    .ad_wdt32k         ( ad_wdt32k               ),
    .ad_por_n          ( ad_por_n                ),
    .ad_pixadc_data    ( ad_pixadc_data          ),

    .da_pixel_bias_en  ( da_pixel_bias_en        ),
    .da_pixel_vref_en  ( da_pixel_vref_en        ),
    .da_pixadc_ck      ( da_pixadc_ck            ),
    .da_stb_en         ( da_stb_en               ),
    .da_pmu_fifocut    ( da_pmu_fifocut          ),
    .da_vcm_pow        ( da_vcm_pow              ),
    .da_vcm_qc_en      ( da_vcm_qc_en            ),
    .da_ib_pow         ( da_ib_pow               ),
    .da_ldovref_pow    ( da_ldovref_pow          ),
    .da_osc13m_pow     ( da_osc13m_pow           ),
    .da_vcm_pulsemode  ( da_vcm_pulsemode        ),

    .PAD_SCK           ( PAD_SCK                 ),
    .PAD_CSN           ( PAD_CSN                 ),
    .PAD_MISO          ( PAD_MISO                ),
    .PAD_MOSI          ( PAD_MOSI                ),
    .PAD_INT           ( PAD_INT                 ),
    .PAD_MPX           ( PAD_MPX                 ),
    .VDD               ( VDD                     ),
    .GND               ( GND                     )
);

endmodule