module da_top(
    input   scan_mode           ,
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

logic ad_osc400m_p        ;  
logic ad_pll100m_p        ;  
logic ad_wdt32k_p         ;  
logic ad_por_n_p          ;  
logic [7:0] ad_pixadc_data_p     ; 
logic da_pixel_bias_en_scan ;
logic da_pixel_vref_en_scan ;
logic da_pixadc_ck_scan     ;
logic da_stb_en_scan        ;
logic da_pmu_fifocut_scan   ;
logic da_vcm_pow_scan       ;
logic da_vcm_qc_en_scan     ;
logic da_ib_pow_scan        ;
logic da_ldovref_pow_scan   ;
logic da_osc13m_pow_scan    ;
logic da_vcm_pulsemode_scan ;

analog_top analog_top_inst(
    .da_pixel_bias_en   (da_pixel_bias_en_scan ),
    .da_pixel_vref_en   (da_pixel_vref_en_scan ),
    .da_pixadc_ck       (da_pixadc_ck_scan     ),
    .da_stb_en          (da_stb_en_scan        ),
    .da_pmu_fifocut     (da_pmu_fifocut_scan   ),
    .da_vcm_pow         (da_vcm_pow_scan       ),
    .da_vcm_qc_en       (da_vcm_qc_en_scan     ),
    .da_ib_pow          (da_ib_pow_scan        ),
    .da_ldovref_pow     (da_ldovref_pow_scan   ),
    .da_osc13m_pow      (da_osc13m_pow_scan    ),
    .da_vcm_pulsemode   (da_vcm_pulsemode_scan ),
    .ad_osc400m         (ad_osc400m_p          ),
    .ad_pll100m         (ad_pll100m_p          ),
    .ad_wdt32k          (ad_wdt32k_p           ),
    .ad_por_n           (ad_por_n_p            ),
    .ad_pixadc_data     (ad_pixadc_data_p      )
);

analog_mux analog_mux_inst(
    .scan_mode             (scan_mode             ),   
    .da_pixel_bias_en      (da_pixel_bias_en      ),   
    .da_pixel_vref_en      (da_pixel_vref_en      ),   
    .da_pixadc_ck          (da_pixadc_ck          ),   
    .da_stb_en             (da_stb_en             ),   
    .da_pmu_fifocut        (da_pmu_fifocut        ),   
    .da_vcm_pow            (da_vcm_pow            ),   
    .da_vcm_qc_en          (da_vcm_qc_en          ),   
    .da_ib_pow             (da_ib_pow             ),   
    .da_ldovref_pow        (da_ldovref_pow        ),   
    .da_osc13m_pow         (da_osc13m_pow         ),   
    .da_vcm_pulsemode      (da_vcm_pulsemode      ),   
    .ad_osc400m            (ad_osc400m_p          ),   
    .ad_pll100m            (ad_pll100m_p          ),   
    .ad_wdt32k             (ad_wdt32k_p           ),   
    .ad_por_n              (ad_por_n_p            ),   
    .ad_pixadc_data        (ad_pixadc_data_p      ),     
    .da_pixel_bias_en_scan (da_pixel_bias_en_scan ),   
    .da_pixel_vref_en_scan (da_pixel_vref_en_scan ),   
    .da_pixadc_ck_scan     (da_pixadc_ck_scan     ),   
    .da_stb_en_scan        (da_stb_en_scan        ),   
    .da_pmu_fifocut_scan   (da_pmu_fifocut_scan   ),   
    .da_vcm_pow_scan       (da_vcm_pow_scan       ),   
    .da_vcm_qc_en_scan     (da_vcm_qc_en_scan     ),   
    .da_ib_pow_scan        (da_ib_pow_scan        ),   
    .da_ldovref_pow_scan   (da_ldovref_pow_scan   ),   
    .da_osc13m_pow_scan    (da_osc13m_pow_scan    ),   
    .da_vcm_pulsemode_scan (da_vcm_pulsemode_scan ),   
    .ad_osc400m_scan       (ad_osc400m            ),   
    .ad_pll100m_scan       (ad_pll100m            ),   
    .ad_wdt32k_scan        (ad_wdt32k             ),   
    .ad_por_n_scan         (ad_por_n              ),      
    .ad_pixadc_data_scan   (ad_pixadc_data        )
);

endmodule