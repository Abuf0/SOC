module lp_soc_top(
    inout          PAD_SCK                  ,
    inout          PAD_CSN                  ,
    inout          PAD_MISO                 ,
    inout          PAD_MOSI                 ,
    inout          PAD_INT                  ,
    inout          PAD_MPX                  ,
    inout          VDD1                     ,
    inout          VDD2                     ,
    inout          VDD3                     ,
    inout          VSS                      
);

    logic scan_mode             ;
    logic da_pixel_bias_en      ;
    logic da_pixel_vref_en      ;
    logic da_pixadc_ck          ;
    logic da_stb_en             ;
    logic da_pmu_fifocut        ;
    logic da_vcm_pow            ;
    logic da_vcm_qc_en          ;
    logic da_ib_pow             ;
    logic da_ldovref_pow        ;
    logic da_osc13m_pow         ;
    logic da_vcm_pulsemode      ;
    logic ad_osc400m            ;
    logic ad_pll100m            ;
    logic ad_wdt32k             ;
    logic ad_por_n              ;
    logic [7:0] ad_pixadc_data  ;

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
    .scan_mode         ( scan_mode               ),

    .PAD_SCK           ( PAD_SCK                 ),
    .PAD_CSN           ( PAD_CSN                 ),
    .PAD_MISO          ( PAD_MISO                ),
    .PAD_MOSI          ( PAD_MOSI                ),
    .PAD_INT           ( PAD_INT                 ),
    .PAD_MPX           ( PAD_MPX                 ),
    .VDD1              ( VDD1                    ),
    .VDD2              ( VDD2                    ),
    .VDD3              ( VDD3                    ),
    .VSS               ( VSS                     )
);

endmodule