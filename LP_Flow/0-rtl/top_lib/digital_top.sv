module digital_top(
    inout          PAD_SCK                  ,
    inout          PAD_CSN                  ,
    inout          PAD_MISO                 ,
    inout          PAD_MOSI                 ,
    inout          PAD_INT                  ,
    inout          PAD_MPX                  ,
    inout          VDD1                     ,
    inout          VDD2                     ,
    inout          VDD3                     ,
    inout          VSS                      ,
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
    output logic   da_vcm_pulsemode         ,
    output logic   scan_mode

);

parameter INN = 6;
parameter AW = 9;
parameter DW = 16;
parameter PDW = 8;
parameter BW = 8;
parameter FIFO_DEEPTH = 256;
parameter H  = 16;
parameter V  = 16;
parameter HW = $clog2(H);
parameter VW = $clog2(V);
// pad_top Inputs
logic   mpx_out                              ;


// crgu Inputs
logic   spi_ck                              ;
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
logic    clk_spi_inv                 ;
logic    rstn_reg                    ;
logic    rstn_fifo                   ;
logic    rstn_tim                    ;
logic    rstn_afe                    ;
logic    rstn_isp                    ;
logic    rstn_32k                    ;
logic    rstn_spi                    ;

logic   timeslot_start               ;
logic   data2fifo_done               ;
logic   tmr_wakeup                   ;
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
logic    pmu_fifo_rstn               ;
logic    shut_iso_en                 ;

// spi_slave Inputs
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
logic   [AW-1:0]  fifo_used          ;
logic   isp_done                     ;

// time_ctrl Outputs
logic isp_sta_trig                   ;

// afe_ctrl Inputs
logic  adc_sta_trig                  ;

// afe_ctrl Outputs
logic [7:0] data_out                 ;
logic data_out_vld                   ;
logic   afe_adc_read_done            ;

// sync_fifo Inputs
logic   fifo_wr                         ;
logic   fifo_rd                         ;
logic   [AW-1:0]  fifo_addr             ;
logic   [DW-1:0]  fifo_wdata            ;

// sync_fifo Outputs
logic [DW-1:0] fifo_rdata               ;

logic          m_wr ;
logic          m_rd ;
logic [15:0]   m_addr;
logic [15:0]   m_wdata;
logic [15:0]   m_rdata;
logic    bus_error;

// isp_ctrl Inputs
logic   [15:0]  isp_enable            ;
logic   [PDW-1:0]  pixel_data_in       ;
logic   pixel_data_in_vld             ;

// isp_ctrl Outputs
logic [PDW-1:0] pixel_data_out        ;
logic pixel_data_out_vld             ;


logic   one_frame_done               ;
logic   fifo_spaceov_flag          ;
logic   fifo_upov_flag               ;
logic   fifo_downov_flag             ;

// int_ctrl Outputs
logic int_req                        ;
logic [INN-1:0] ro_int_status        ;
logic [INN-1:0] rg_int_enable        ;

logic [7:0]  chip_version                  ;
logic [7:0]  chip_id                       ;
logic [AW-1:0]  ro_fifo_used                 ;

// reg_top_apb_cfg Outputs
logic [7:0]  rg_pixel_height               ;
logic [7:0]  rg_pixel_width                ;
logic [15:0]  rg_fifo_enough_th            ;
logic [7:0]  rg_adc_sample_prd             ;
logic rg_fifo_chk_en                       ;
logic rg_frame_mode                        ;
logic [3:0]  rg_multi_frame_num            ;
logic [7:0]  rg_setup_time                 ;
logic [INN-1:0]  rg_int_clr                    ;
logic rg_frame_trigger_start               ;
logic rg_ldo_manual_mode                   ;
logic rg_da_lnvref_pow                     ;
logic rg_faster_sr_nosleep                 ;
logic rg_pmu_fast_wakeup                   ;
logic rg_vcm_pulsemode                     ;
logic [2:0]  rg_timing_ldo                 ;
logic [1:0]  rg_timing_vcm                 ;
logic rg_pmu_fifocut                       ;
logic rg_cardiff_start                     ;
logic rg_nosleep                           ;
logic [1:0]  rg_sync_mode                  ;
logic [5:0]  rg_syncin_t1_set              ;
logic [5:0]  rg_pmu_wkup_time              ;
logic rg_syncin_polar_sel                  ;
logic rg_int_pwrup                         ;
logic [1:0]  rg_bayer_pattern              ;
logic [7:0]  rg_dpc_thres                  ;
logic [7:0]  rg_dpc_clip                   ;

logic [15:0] tmp_16b;

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
assign int_ack = 0;
assign chip_version = 0;
assign chip_id      = 0;

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
    .VDD                     ( VDD1       ),
    .VSS                     ( VSS        )
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
    .clk_spi_inv    ( clk_spi_inv          ),
    .rstn_reg       ( rstn_reg             ),
    .rstn_fifo      ( rstn_fifo            ),
    .rstn_tim       ( rstn_tim             ),
    .rstn_afe       ( rstn_afe             ),
    .rstn_isp       ( rstn_isp             ),
    .rstn_32k       ( rstn_32k             ),
    .rstn_spi       ( rstn_spi             )
);

spi_slave u_spi_slave (
    .scan_mode  ( scan_mode         ),
    .clk_spi    ( clk_spi           ),
    .clk_spi_inv( clk_spi_inv       ),
    .rstn_spi   ( rstn_spi          ),
    .clk_sys    ( clk_reg           ),
    .rstn_sys   ( rstn_reg          ),
    .spi_csn    ( spi_csn           ),
    .spi_mosi   ( spi_mosi          ),
    .reg_rdata  ( m_rdata           ),

    .spi_miso   ( spi_miso          ),
    .cmd_idle   ( cmd_idle          ),
    .cmd_img    ( cmd_img           ),
    .cmd_sleep  ( cmd_sleep         ),
    .cmd_wakeup ( cmd_wakeup        ),
    .reg_wr     ( m_wr              ),  
    .reg_rd     ( m_rd              ),  
    .reg_addr   ( m_addr            ),  
    .reg_wdata  ( m_wdata           )     
);

spi_to_apb  u_spi_to_apb (
    .clk_spi    ( clk_spi           ),
    .rstn_spi   ( rstn_spi          ),
    .clk_sys    ( clk_reg           ),
    .rstn_sys   ( rstn_reg          ),
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

bus_mux u_bus_mux(
    .m_wr       ( m_wr                   ),
    .m_rd       ( m_rd                   ),
    .m_addr     ( m_addr                 ),
    .m_wdata    ( m_wdata                ),    
    .m_rdata    ( m_rdata                ),    
    .s0_wr      ( fifo_wr                ),
    .s0_rd      ( fifo_rd                ),
    .s0_addr    ( tmp_16b                ),    
    .s0_wdata   ( fifo_wdata             ),    
    .s0_rdata   ( fifo_rdata             ), 
    .s1_wr      ( reg_wr                 ),
    .s1_rd      ( reg_rd                 ),
    .s1_addr    ( reg_addr               ), 
    .s1_wdata   ( reg_wdata              ), 
    .s1_rdata   ( reg_rdata              ),    
    .bus_error  ( bus_error              )  
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
    .scan_enable             ( scan_enable          ),
    .clk_tim                 ( clk_tim              ),
    .rstn_tim                ( rstn_tim             ),
    .clk_afe                 ( clk_afe              ),
    .rstn_afe                ( rstn_afe             ),
    .clk_isp                 ( clk_isp              ),
    .rstn_isp                ( rstn_isp             ),
    .cmd_img                 ( cmd_img              ),
    .rg_fifo_chk_en          ( rg_fifo_chk_en       ),
    .rg_fifo_enough_th       ( rg_fifo_enough_th    ),
    .fifo_used               ( ro_fifo_used         ),
    .rg_setup_time           ( rg_setup_time        ),
    .rg_frame_mode           ( rg_frame_mode        ),
    .rg_multi_frame_num      ( rg_multi_frame_num   ),
    .isp_done                ( isp_done             ),
    .afe_adc_read_done       ( afe_adc_read_done    ),
    .fifo_spaceov_flag       ( fifo_spaceov_flag    ),

    .isp_sta_trig      ( isp_sta_trig               ),
    .adc_sta_trig      ( adc_sta_trig               ),
    .da_pixel_bias_en  ( da_pixel_bias_en           ),
    .da_pixel_vref_en  ( da_pixel_vref_en           )
);

afe_ctrl  u_afe_ctrl (
    .scan_enable                ( scan_enable         ),
    .clk_afe                    ( clk_afe             ),
    .rstn_afe                   ( rstn_afe            ),
    .clk_tim                    ( clk_tim             ),
    .rstn_tim                   ( rstn_tim            ),
    .clk_fifo                   ( clk_fifo            ),
    .rstn_fifo                  ( rstn_fifo           ),
    .rg_pad_en                  ( 0 /* TODO */        ),
    .rg_pixel_width             ( rg_pixel_width      ),
    .rg_pixel_height            ( rg_pixel_height     ),
    .rg_adc_sample_prd          ( rg_adc_sample_prd   ),
    .ad_data                    ( ad_pixadc_data      ),
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
    .i_wr     ( pixel_data_out_vld  ),
    .i_rd     ( fifo_rd       ),
    .i_wdata  ( {8'd0, pixel_data_out} ),

    .o_rdata  ( fifo_rdata    ),
    .o_used   ( ro_fifo_used  ),
    .fifo_upov_flag     (fifo_upov_flag   ),
    .fifo_downov_flag   (fifo_downov_flag )
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
    .pixel_data_in                  ( data_out                    ),
    .pixel_data_in_vld              ( data_out_vld                ),

    .pixel_data_out           ( pixel_data_out           ),
    .pixel_data_out_vld       ( pixel_data_out_vld                ),
    .isp_one_frame_done       ( isp_done                          )
);

int_ctrl #(
    .INN ( INN ))
 u_int_ctrl (
    .scan_enable                    ( scan_enable                  ),
    .clk_32k                        ( clk_32k                      ),
    .rstn_32k                       ( rstn_32k                     ),
    .clk_sys                        ( clk_fifo                     ),
    .rstn_sys                       ( rstn_fifo                    ),
    .rg_int_enable                  ( 6'h1F /* TODO */             ),
    .rg_int_clr                     ( rg_int_clr                   ),
    .one_frame_done                 ( isp_done                     ),
    .fifo_spaceov_flag              ( fifo_spaceov_flag            ),
    .fifo_upov_flag                 ( fifo_upov_flag               ),
    .fifo_downov_flag               ( fifo_downov_flag             ),
    .bus_error                      ( bus_error                    ),

    .int_req                  ( int_req                            ),
    .ro_int_status  ( ro_int_status            )
);

reg_top_apb_cfg  u_reg_top_apb_cfg (
    .clk                     ( clk_reg               ),
    .rst_n                   ( rstn_reg              ),
    .pwrite                  ( pwrite                ),
    .psel                    ( psel                  ),
    .penable                 ( penable               ),
    .paddr                   ( paddr                 ),
    .pwdata                  ( pwdata                ),
    .chip_version            ( chip_version          ),
    .chip_id                 ( chip_id               ),
    .ro_fifo_used            ( ro_fifo_used          ),
    .ro_int_status           ( ro_int_status         ),

    .prdata                  ( prdata                ),
    .rg_fifo_reset           ( rg_fifo_reset         ),
    .rg_isp_ckgt_en          ( rg_isp_ckgt_en        ),
    .rg_afe_ckgt_en          ( rg_afe_ckgt_en        ),
    .rg_fifo_ckgt_en         ( rg_fifo_ckgt_en       ),
    .rg_pixel_height         ( rg_pixel_height       ),
    .rg_pixel_width          ( rg_pixel_width        ),
    .rg_fifo_enough_th       ( rg_fifo_enough_th     ),
    .rg_adc_sample_prd       ( rg_adc_sample_prd     ),
    .rg_fifo_chk_en          ( rg_fifo_chk_en        ),
    .rg_frame_mode           ( rg_frame_mode         ),
    .rg_multi_frame_num      ( rg_multi_frame_num    ),
    .rg_setup_time           ( rg_setup_time         ),
    .rg_int_clr              ( rg_int_clr            ),
    .rg_frame_trigger_start  ( rg_frame_trigger_start),
    .rg_ldo_manual_mode      ( rg_ldo_manual_mode    ),
    .rg_da_lnvref_pow        ( rg_da_lnvref_pow      ),
    .rg_faster_sr_nosleep    ( rg_faster_sr_nosleep  ),
    .rg_pmu_fast_wakeup      ( rg_pmu_fast_wakeup    ),
    .rg_vcm_pulsemode        ( rg_vcm_pulsemode      ),
    .rg_timing_ldo           ( rg_timing_ldo         ),
    .rg_timing_vcm           ( rg_timing_vcm         ),
    .rg_pmu_fifocut          ( rg_pmu_fifocut        ),
    .rg_cardiff_start        ( rg_cardiff_start      ),
    .rg_nosleep              ( rg_nosleep            ),
    .rg_sync_mode            ( rg_sync_mode          ),
    .rg_syncin_t1_set        ( rg_syncin_t1_set      ),
    .rg_pmu_wkup_time        ( rg_pmu_wkup_time      ),
    .rg_syncin_polar_sel     ( rg_syncin_polar_sel   ),
    .rg_int_pwrup            ( rg_int_pwrup          ),
    .rg_bayer_pattern        ( rg_bayer_pattern      ),
    .rg_dpc_thres            ( rg_dpc_thres          ),
    .rg_dpc_clip             ( rg_dpc_clip           )
);


endmodule