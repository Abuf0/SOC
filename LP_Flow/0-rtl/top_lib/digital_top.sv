module digital_top(
    inout          PAD_SCK                  ,
    inout          PAD_CSN                  ,
    inout          PAD_MISO                 ,
    inout          PAD_MOSI                 ,
    inout          PAD_INT                  ,
    inout          PAD_MPX                  ,
    inout          VDD                      ,
    inout          GND                      ,
    input          ad_osc400m               ,
    input          ad_pll100m               ,
    input          ad_wdt32k                ,
    input          ad_por_n                 ,
    input  [7:0]   ad_pixadc_data           ,
    output logic   da_pixel_bias_en         ,
    output logic   da_pixel_vref_en         ,
    output logic   da_pixadc_ck             ,
    output logic   da_stb_en                ,
    output logic   da_pmu_fifocut           ,
    output logic   da_vcm_pow               ,
    output logic   da_vcm_qc_en             ,
    output logic   da_ib_pow                ,
    output logic   da_ldovref_pow           ,
    output logic   da_osc13m_pow            ,
    output logic   da_vcm_pulsemode         

);

parameter INN = 5;
parameter AW = 16;
parameter DW = 16;
parameter PDW = 8;
parameter BW = 8;
parameter FIFO_DEEPTH = 256;
parameter H  = 16;
parameter V  = 16;
parameter HW = 4;
parameter VW = 4;
// pad_top Inputs
logic   mpx_out                              ;
logic   ad_por_n                             ;


// crgu Inputs
logic   spi_ck                              ;
logic   cmd_idle                            ;
logic   shut_rstn                           ;
logic   rg_fifo_reset                       ;
logic   rg_fifo_ckgt_en                     ;
logic   rg_afe_ckgt_en                      ;
logic   rg_isp_ckgt_en                      ;
logic   reg_ckgt_case                       ;
logic   afe_icg_en                          ;
logic   isp_icg_en                          ;

// crgu Outputs
logic    clk_reg                     ;
logic    clk_fifo                    ;
logic    clk_tim                     ;
logic    clk_afe                     ;
logic    clk_isp                     ;
logic    clk_32k                     ;
logic    clk_spi                     ;
logic    rstn_reg                    ;
logic    rstn_fifo                   ;
logic    rstn_tim                    ;
logic    rstn_afe                    ;
logic    rstn_isp                    ;
logic    rstn_32k                    ;
logic    rstn_spi                    ;

logic   rg_ldo_manual_mode           ;
logic   rg_da_lnvref_pow             ;
logic   rg_faster_sr_nosleep         ;
logic   rg_pmu_fast_wakeup           ;
logic   rg_vcm_pulsemode             ;
logic   [2:0]  rg_timing_ldo         ;
logic   [1:0]  rg_timing_vcm         ;
logic   rg_pmu_fifocut               ;
logic   rg_cardiff_start             ;
logic   rg_nosleep                   ;
logic   [1:0]  rg_sync_mode          ;
logic   rg_frame_trigger_start       ;
logic   [6:0]  rg_syncin_t1_set      ;
logic   [5:0]  rg_pmu_wkup_time      ;
logic   rg_syncin_polar_sel          ;
logic   rg_int_pwrup                 ;
logic   timeslot_start               ;
logic   data2fifo_done               ;
logic   tmr_wakeup                   ;
logic   cmd_wakeup                   ;
logic   cmd_sleep                    ;
logic   int_ack                      ;

// pmu Outputs
logic    pmu_efuse_start_13m         ;
logic    efuse_load_state            ;
logic    efuse_load_done             ;
logic    timer_pmu_start             ;
logic    osc13m_ready                ;
logic    osc13m_ready_pulse          ;
logic    wakeup_ready_pulse          ;
logic    int_pwrup_ready             ;
logic    tm_clk_en_32k               ;
logic    osc13m_clk_en_32k           ;
logic    da_stb_en                   ;
logic    da_pmu_fifocut              ;
logic    da_vcm_pow                  ;
logic    da_vcm_qc_en                ;
logic    da_ib_pow                   ;
logic    da_ldovref_pow              ;
logic    da_osc13m_pow               ;
logic    da_vcm_pulsemode            ;
logic    pmu_fifo_rstn               ;
logic    shut_iso_en                 ;

// spi_slave Inputs
logic   clk_spi                      ;
logic   rstn_spi                     ;
logic   clk_sys                      ;
logic   rstn_sys                     ;
logic   spi_csn                      ;
logic   spi_mosi                     ;
logic   [15:0]  reg_rdata            ;

// spi_slave Outputs
logic        spi_miso                ;
logic        cmd_idle                ;
logic        cmd_img                 ;
logic        cmd_sleep               ;
logic        cmd_wakeup              ;
logic        reg_wr                  ;
logic        reg_rd                  ;
logic [15:0] reg_addr                ;
logic [15:0] reg_wdata               ;

// time_ctrl Inputs
logic   clk_tim                      ;
logic   rstn_tim                     ;
logic   clk_afe                      ;
logic   rstn_afe                     ;
logic   cmd_img                      ;
logic   rg_fifo_chk_en               ;
logic   [15:0]  rg_fifo_enough_th    ;
logic   [AW-1:0]  fifo_used          ;
logic   [7:0]  rg_setup_time         ;
logic   rg_frame_mode                ;
logic   [3:0]  rg_multi_frame_num    ;
logic   isp_done                     ;
logic   afe_adc_read_done            ;

// time_ctrl Outputs
logic isp_sta_trig                   ;
logic adc_sta_trig                   ;
logic da_pixel_bias_en               ;
logic da_pixel_vref_en               ;

// afe_ctrl Inputs
logic  clk_afe                       ;
logic  rstn_afe                      ;
logic  clk_tim                       ;
logic  rstn_tim                      ;
logic  clk_fifo                      ;
logic  rstn_fifo                     ;
logic  [7:0]  rg_pixel_width         ;
logic  [7:0]  rg_pixel_height        ;
logic  [2:0]  rg_adc_sample_prd      ;
logic  [7:0]  ad_data                ;
logic  adc_sta_trig                  ;

// afe_ctrl Outputs
logic [7:0] data_out                 ;
logic data_out_vld                   ;
logic da_pixadc_ck                   ;
logic   afe_adc_read_done            ;

// sync_fifo Inputs
logic   clk_fifo                     ;
logic   rstn_fifo                    ;
logic   i_wr                         ;
logic   i_rd                         ;
logic   [AW-1:0]  i_addr             ;
logic   [DW-1:0]  i_wdata            ;

// sync_fifo Outputs
logic [DW-1:0] o_rdata               ;
logic [AW-1:0] o_used                ;

// isp_ctrl Inputs
logic   clk                           ;
logic   rstn                          ;
logic   [15:0]  isp_enable            ;
logic   [1:0]  bayer_pattern          ;
logic   [BW-1:0]  dpc_thres           ;
logic   [BW-1:0]  dpc_clip            ;
logic   [PDW-1:0]  pixel_data_in       ;
logic   pixel_data_in_vld             ;

// isp_ctrl Outputs
logic [PDW-1:0] pixel_data_out        ;
logic pixel_data_out_vld             ;
logic one_frame_done                 ;


logic   [INN-1:0]  rg_int_clr        ;
logic   reset_irq                    ;
logic   one_frame_done               ;
logic   fifo_waterline_flag          ;
logic   fifo_upov_flag               ;
logic   fifo_downov_flag             ;

// int_ctrl Outputs
logic int_req                        ;
logic [INN-1:0] ro_int_status        ;

logic scan_mode;
logic scan_enable;
logic scan_clk;
logic scan_rstn;

logic          pwrite;
logic          psel;
logic          penable;
logic [15:0]   paddr;
logic [15:0]   pwdata;
logic [15:0]   prdata;

// TODO
assign scan_mode = 0;
assign scan_enable = 0;
assign scan_clk = 0;
assign scan_rstn = 1;
assign reg_ckgt_case = 1;
assign afe_icg_en = rg_afe_ckgt_en;
assign isp_icg_en = rg_isp_ckgt_en;
assign isp_enable[0] = ~rg_isp_ckgt_en;
assign mpx_out = 0;

pad_top  u_pad_top (
    .miso_out                ( spi_miso   ),
    .int_out                 ( int_req    ),
    .mpx_out                 ( mpx_out    ),
    .ad_por_n                ( ad_por_n   ),

    .sck_in                  ( spi_ck     ),
    .csn_in                  ( spi_csn    ),
    .mosi_in                 ( spi_mosi   ),

    .PAD_SCK                 ( PAD_SCK    ),
    .PAD_CSN                 ( PAD_CSN    ),
    .PAD_MISO                ( PAD_MISO   ),
    .PAD_MOSI                ( PAD_MOSI   ),
    .PAD_INT                 ( PAD_INT    ),
    .PAD_MPX                 ( PAD_MPX    ),
    .VDD                     ( VDD        ),
    .GND                     ( GND        )
);

crgu  u_crgu (
    .scan_mode      ( scan_mode            ),
    .scan_enable    ( scan_enable          ),
    .scan_clk       ( scan_clk             ),
    .scan_rstn      ( scan_rstn            ),
    .ad_osc400m     ( ad_osc400m           ),
    .ad_pll100m     ( ad_pll100m           ),
    .wdt_32k        ( ad_wdt32k            ),
    .spi_ck         ( spi_ck               ),
    .ad_por_n       ( ad_por_n             ),
    .cmd_idle       ( cmd_idle             ),
    .da_stb_en      ( da_stb_en            ),
    .shut_rstn      ( shut_rstn            ),
    .rg_fifo_reset  ( rg_fifo_reset        ),
    .rg_fifo_ckgt_en( rg_fifo_ckgt_en      ),
    .rg_afe_ckgt_en ( rg_afe_ckgt_en       ),
    .rg_isp_ckgt_en ( rg_isp_ckgt_en       ),
    .reg_ckgt_case  ( reg_ckgt_case        ),
    .afe_icg_en     ( afe_icg_en           ),
    .isp_icg_en     ( isp_icg_en           ),

    .clk_reg        ( clk_reg              ),
    .clk_fifo       ( clk_fifo             ),
    .clk_tim        ( clk_tim              ),
    .clk_afe        ( clk_afe              ),
    .clk_isp        ( clk_isp              ),
    .clk_32k        ( clk_32k              ),
    .clk_spi        ( clk_spi              ),
    .rstn_reg       ( rstn_reg             ),
    .rstn_fifo      ( rstn_fifo            ),
    .rstn_tim       ( rstn_tim             ),
    .rstn_afe       ( rstn_afe             ),
    .rstn_isp       ( rstn_isp             ),
    .rstn_32k       ( rstn_32k             ),
    .rstn_spi       ( rstn_spi             )
);

spi_slave u_spi_slave (
    .clk_spi    ( clk_spi           ),
    .rstn_spi   ( rstn_spi          ),
    .clk_sys    ( clk_sys           ),
    .rstn_sys   ( rstn_sys          ),
    .spi_csn    ( spi_csn           ),
    .spi_mosi   ( spi_mosi          ),
    .reg_rdata  ( reg_rdata         ),

    .spi_miso   ( spi_miso          ),
    .cmd_idle   ( cmd_idle          ),
    .cmd_img    ( cmd_img           ),
    .cmd_sleep  ( cmd_sleep         ),
    .cmd_wakeup ( cmd_wakeup        ),
    .reg_wr     ( reg_wr            ),  
    .reg_rd     ( reg_rd            ),  
    .reg_addr   ( reg_addr          ),  
    .reg_wdata  ( reg_wdata         )     
);

spi_to_apb  u_spi_to_apb (
    .clk_spi    ( clk_spi           ),
    .rstn_spi   ( rstn_spi          ),
    .clk_sys    ( clk_sys           ),
    .rstn_sys   ( rstn_sys          ),
    .reg_wr     ( reg_wr            ),
    .reg_rd     ( reg_rd            ),
    .reg_addr   ( reg_addr          ),
    .reg_wdata  ( reg_wdata         ),
    .prdata     ( prdata            ),

    .reg_rdata  ( reg_rdata         ),
    .pwrite     ( pwrite            ),
    .psel       ( psel              ),
    .penable    ( penable           ),
    .paddr      ( paddr             ),
    .pwdata     ( pwdata            )
);

pmu  u_pmu (
    .scan_mode                     ( scan_mode                   ),
    .scan_rstn                     ( scan_rstn                   ),
    .clk                           ( clk_32k                     ),
    .rstn                          ( rstn_32k                    ),
    .rg_ldo_manual_mode            ( rg_ldo_manual_mode          ),
    .rg_da_lnvref_pow              ( rg_da_lnvref_pow            ),
    .rg_faster_sr_nosleep          ( rg_faster_sr_nosleep        ),
    .rg_pmu_fast_wakeup            ( rg_pmu_fast_wakeup          ),
    .rg_vcm_pulsemode              ( rg_vcm_pulsemode            ),
    .rg_timing_ldo                 ( rg_timing_ldo               ),
    .rg_timing_vcm                 ( rg_timing_vcm               ),
    .rg_pmu_fifocut                ( rg_pmu_fifocut              ),
    .rg_cardiff_start              ( rg_cardiff_start            ),
    .rg_nosleep                    ( rg_nosleep                  ),
    .rg_sync_mode                  ( rg_sync_mode                ),
    .rg_frame_trigger_start        ( rg_frame_trigger_start      ),
    .rg_syncin_t1_set              ( rg_syncin_t1_set            ),
    .rg_pmu_wkup_time              ( rg_pmu_wkup_time            ),
    .rg_syncin_polar_sel           ( rg_syncin_polar_sel         ),
    .rg_int_pwrup                  ( rg_int_pwrup                ),
    .efuse_done_13m                ( 1'b1              ),
    .efuse_busy_13m                ( 1'b0              ),
    .timeslot_start                ( timer_pmu_start   ),
    .data2fifo_done                ( 1'b1              ),
    .tmr_wakeup                    ( 1'b0                  ),
    .SYNC                          ( 1'b0                        ),
    .cmd_wakeup                    ( cmd_wakeup                  ),
    .cmd_sleep                     ( cmd_sleep                   ),
    .int_req                       ( int_req                     ),
    .int_ack                       ( int_ack                     ), 

    .pmu_efuse_start_13m  ( pmu_efuse_start_13m        ),
    .efuse_load_state     ( efuse_load_state           ),
    .efuse_load_done      ( efuse_load_done            ),
    .timer_pmu_start      ( timer_pmu_start            ),
    .osc13m_ready         ( osc13m_ready               ),
    .osc13m_ready_pulse   ( osc13m_ready_pulse         ),
    .wakeup_ready_pulse   ( wakeup_ready_pulse         ),
    .int_pwrup_ready      ( int_pwrup_ready            ),
    .tm_clk_en_32k        ( tm_clk_en_32k              ),
    .osc13m_clk_en_32k    ( osc13m_clk_en_32k          ),
    .da_stb_en            ( da_stb_en                  ),
    .da_pmu_fifocut       ( da_pmu_fifocut             ),
    .da_vcm_pow           ( da_vcm_pow                 ),
    .da_vcm_qc_en         ( da_vcm_qc_en               ),
    .da_ib_pow            ( da_ib_pow                  ),
    .da_ldovref_pow       ( da_ldovref_pow             ),
    .da_osc13m_pow        ( da_osc13m_pow              ),
    .da_vcm_pulsemode     ( da_vcm_pulsemode           ),
    .pmu_fifo_rstn        ( pmu_fifo_rstn              ),
    .shut_iso_en          ( shut_iso_en                ),
    .shut_rstn            ( shut_rstn                  )
);

time_ctrl #(
    .AW          ( AW          ),
    .FIFO_DEEPTH ( FIFO_DEEPTH ))
 u_time_ctrl (
    .clk_tim                 ( clk_tim              ),
    .rstn_tim                ( rstn_tim             ),
    .clk_afe                 ( clk_afe              ),
    .rstn_afe                ( rstn_afe             ),
    .cmd_img                 ( cmd_img              ),
    .rg_fifo_chk_en          ( rg_fifo_chk_en       ),
    .rg_fifo_enough_th       ( rg_fifo_enough_th    ),
    .fifo_used               ( ro_fifo_used         ),
    .rg_setup_time           ( rg_setup_time        ),
    .rg_frame_mode           ( rg_frame_mode        ),
    .rg_multi_frame_num      ( rg_multi_frame_num   ),
    .isp_done                ( isp_done             ),
    .afe_adc_read_done       ( afe_adc_read_done    ),

    .isp_sta_trig      ( isp_sta_trig               ),
    .adc_sta_trig      ( adc_sta_trig               ),
    .da_pixel_bias_en  ( da_pixel_bias_en           ),
    .da_pixel_vref_en  ( da_pixel_vref_en           )
);

afe_ctrl  u_afe_ctrl (
    .clk_afe                    ( clk_afe             ),
    .rstn_afe                   ( rstn_afe            ),
    .clk_tim                    ( clk_tim             ),
    .rstn_tim                   ( rstn_tim            ),
    .clk_fifo                   ( clk_fifo            ),
    .rstn_fifo                  ( rstn_fifo           ),
    .rg_pixel_width             ( rg_pixel_width      ),
    .rg_pixel_height            ( rg_pixel_height     ),
    .rg_adc_sample_prd          ( rg_adc_sample_prd   ),
    .ad_data                    ( ad_data             ),
    .adc_sta_trig               ( adc_sta_trig        ),

    .data_out             ( data_out             ),
    .data_out_vld         ( data_out_vld         ),
    .da_pixadc_ck         ( da_pixadc_ck         ),
    .afe_adc_read_done    ( afe_adc_read_done    )
);

sync_fifo #(
    .DW ( DW ),
    .AW ( AW ))
 u_sync_fifo (
    .clk_fifo ( clk_fifo      ),
    .rstn_fifo( rstn_fifo     ),
    .i_wr     ( i_wr          ),
    .i_rd     ( i_rd          ),
    .i_addr   ( i_addr        ),
    .i_wdata  ( i_wdata       ),

    .o_rdata  ( o_rdata       ),
    .o_used   ( o_used        )
);

isp_ctrl #(
    .DW  ( PDW  ),
    .BW  ( BW  ),
    .H   ( H   ),
    .V   ( V   ),
    .HW  ( HW  ),
    .VW  ( VW  ))
 u_isp_ctrl (
    .clk                            ( clk_isp                     ),
    .rstn                           ( rstn_isp                    ),
    .isp_enable                     ( isp_enable                  ),
    .bayer_pattern                  ( rg_bayer_pattern            ),
    .dpc_thres                      ( rg_dpc_thres                ),
    .dpc_clip                       ( rg_dpc_clip                 ),
    .pixel_data_in                  ( pixel_data_in               ),
    .pixel_data_in_vld              ( pixel_data_in_vld           ),

    .pixel_data_out           ( pixel_data_out           ),
    .pixel_data_out_vld       ( pixel_data_out_vld                ),
    .one_frame_done           ( one_frame_done                    )
);

int_ctrl #(
    .INN ( INN ))
 u_int_ctrl (
    .clk                            ( clk                          ),
    .rstn                           ( rstn                         ),
    .rg_int_clr                     ( rg_int_clr                   ),
    .reset_irq                      ( reset_irq                    ),
    .one_frame_done                 ( one_frame_done               ),
    .fifo_waterline_flag            ( fifo_waterline_flag          ),
    .fifo_upov_flag                 ( fifo_upov_flag               ),
    .fifo_downov_flag               ( fifo_downov_flag             ),

    .int_req                  ( int_req                            ),
    .ro_int_status  ( ro_int_status            )
);

reg_top_apb_cfg  u_reg_top_apb_cfg (
    .clk                     ( clk_reg                 ),
    .rst_n                   ( rstn_reg                ),
    .pwrite                  ( pwrite                  ),
    .psel                    ( psel                    ),   // todo
    .penable                 ( penable                 ),   // todo
    .paddr                   ( paddr                   ),   // todo
    .pwdata                  ( pwdata                  ),   // todo
    .chip_version            ( chip_version            ),
    .chip_id                 ( chip_id                 ),
    .ro_fifo_used            ( ro_fifo_used            ),
    .rg_fifo_chk_en          ( rg_fifo_chk_en          ),
    .rg_frame_mode           ( rg_frame_mode           ),
    .rg_multi_frame_num      ( rg_multi_frame_num      ),
    .rg_setup_time           ( rg_setup_time           ),
    .ro_int_status           ( ro_int_status           ),

    .prdata                  ( prdata                  ),   // todo
    .rg_fifo_reset           ( rg_fifo_reset           ),
    .rg_isp_ckgt_en          ( rg_isp_ckgt_en          ),
    .rg_afe_ckgt_en          ( rg_afe_ckgt_en          ),
    .rg_fifo_ckgt_en         ( rg_fifo_ckgt_en         ),
    .rg_pixel_height         ( rg_pixel_height         ),
    .rg_pixel_width          ( rg_pixel_width          ),
    .rg_fifo_enough_th       ( rg_fifo_enough_th       ),
    .rg_adc_sample_prd       ( rg_adc_sample_prd       ),
    .rg_int_clr              ( rg_int_clr              ),
    .rg_frame_trigger_start  ( rg_frame_trigger_start  ),
    .rg_ldo_manual_mode      ( rg_ldo_manual_mode      ),
    .rg_da_lnvref_pow        ( rg_da_lnvref_pow        ),
    .rg_faster_sr_nosleep    ( rg_faster_sr_nosleep    ),
    .rg_pmu_fast_wakeup      ( rg_pmu_fast_wakeup      ),
    .rg_vcm_pulsemode        ( rg_vcm_pulsemode        ),
    .rg_timing_ldo           ( rg_timing_ldo           ),
    .rg_timing_vcm           ( rg_timing_vcm           ),
    .rg_pmu_fifocut          ( rg_pmu_fifocut          ),
    .rg_cardiff_start        ( rg_cardiff_start        ),
    .rg_nosleep              ( rg_nosleep              ),
    .rg_sync_mode            ( rg_sync_mode            ),
    .rg_syncin_t1_set        ( rg_syncin_t1_set        ),
    .rg_pmu_wkup_time        ( rg_pmu_wkup_time        ),
    .rg_syncin_polar_sel     ( rg_syncin_polar_sel     ),
    .rg_int_pwrup            ( rg_int_pwrup            ),
    .rg_bayer_pattern        ( rg_bayer_pattern        ),
    .rg_dpc_thres            ( rg_dpc_thres            ),
    .rg_dpc_clip             ( rg_dpc_clip             )
);


endmodule