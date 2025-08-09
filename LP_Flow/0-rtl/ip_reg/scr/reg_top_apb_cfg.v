module reg_top_apb_cfg (
                 clk
                ,rst_n
                ,pwrite
                ,psel
                ,penable
                ,paddr
                ,pwdata
                ,prdata
                ,chip_version
                ,chip_id
                ,rg_fifo_reset
                ,rg_isp_ckgt_en
                ,rg_afe_ckgt_en
                ,rg_fifo_ckgt_en
                ,rg_pixel_height
                ,rg_pixel_width
                ,rg_fifo_enough_th
                ,ro_fifo_used
                ,rg_adc_sample_prd
                ,rg_fifo_chk_en
                ,rg_frame_mode
                ,rg_multi_frame_num
                ,rg_setup_time
                ,rg_int_clr
                ,ro_int_status
                ,rg_frame_trigger_start
                ,rg_ldo_manual_mode
                ,rg_da_lnvref_pow
                ,rg_faster_sr_nosleep
                ,rg_pmu_fast_wakeup
                ,rg_vcm_pulsemode
                ,rg_timing_ldo
                ,rg_timing_vcm
                ,rg_pmu_fifocut
                ,rg_cardiff_start
                ,rg_nosleep
                ,rg_sync_mode
                ,rg_syncin_t1_set
                ,rg_pmu_wkup_time
                ,rg_syncin_polar_sel
                ,rg_int_pwrup
                ,rg_bayer_pattern
                ,rg_dpc_thres
                ,rg_dpc_clip
                );
input           clk;
input           rst_n;
input           pwrite;
input           psel;
input           penable;
input  [31:0]   paddr;
input  [31:0]   pwdata;
output [31:0]   prdata;
input  [7:0]    chip_version;
input  [7:0]    chip_id;
output          rg_fifo_reset;
output          rg_isp_ckgt_en;
output          rg_afe_ckgt_en;
output          rg_fifo_ckgt_en;
output [7:0]    rg_pixel_height;
output [7:0]    rg_pixel_width;
output [15:0]   rg_fifo_enough_th;
input  [15:0]   ro_fifo_used;
output [7:0]    rg_adc_sample_prd;
output          rg_fifo_chk_en;
output          rg_frame_mode;
output [3:0]    rg_multi_frame_num;
output [7:0]    rg_setup_time;
output [4:0]    rg_int_clr;
input  [4:0]    ro_int_status;
output          rg_frame_trigger_start;
output          rg_ldo_manual_mode;
output          rg_da_lnvref_pow;
output          rg_faster_sr_nosleep;
output          rg_pmu_fast_wakeup;
output          rg_vcm_pulsemode;
output [2:0]    rg_timing_ldo;
output [1:0]    rg_timing_vcm;
output          rg_pmu_fifocut;
output          rg_cardiff_start;
output          rg_nosleep;
output [1:0]    rg_sync_mode;
output [5:0]    rg_syncin_t1_set;
output [5:0]    rg_pmu_wkup_time;
output          rg_syncin_polar_sel;
output          rg_int_pwrup;
output [1:0]    rg_bayer_pattern;
output [7:0]    rg_dpc_thres;
output [7:0]    rg_dpc_clip;
wire            clk;
wire            rst_n;
wire            pwrite;
wire            psel;
wire            penable;
wire [31:0]     paddr;
wire [31:0]     pwdata;
reg  [31:0]     prdata;
wire [7:0]      chip_version;
wire [7:0]      chip_id;
reg             rg_fifo_reset;
reg             rg_isp_ckgt_en;
reg             rg_afe_ckgt_en;
reg             rg_fifo_ckgt_en;
reg  [7:0]      rg_pixel_height;
reg  [7:0]      rg_pixel_width;
reg  [15:0]     rg_fifo_enough_th;
wire [15:0]     ro_fifo_used;
reg  [7:0]      rg_adc_sample_prd;
reg             rg_fifo_chk_en;
reg             rg_frame_mode;
reg  [3:0]      rg_multi_frame_num;
reg  [7:0]      rg_setup_time;
reg  [4:0]      rg_int_clr;
wire [4:0]      ro_int_status;
reg             rg_frame_trigger_start;
reg             rg_ldo_manual_mode;
reg             rg_da_lnvref_pow;
reg             rg_faster_sr_nosleep;
reg             rg_pmu_fast_wakeup;
reg             rg_vcm_pulsemode;
reg  [2:0]      rg_timing_ldo;
reg  [1:0]      rg_timing_vcm;
reg             rg_pmu_fifocut;
reg             rg_cardiff_start;
reg             rg_nosleep;
reg  [1:0]      rg_sync_mode;
reg  [5:0]      rg_syncin_t1_set;
reg  [5:0]      rg_pmu_wkup_time;
reg             rg_syncin_polar_sel;
reg             rg_int_pwrup;
reg  [1:0]      rg_bayer_pattern;
reg  [7:0]      rg_dpc_thres;
reg  [7:0]      rg_dpc_clip;
wire [31:0]     CHIP_INFO;
wire [31:0]     CRGU_CTRL;
wire [31:0]     PIXEL_SIZE;
wire [31:0]     FIFO_THRESHOLD;
wire [31:0]     FIFO_USED;
wire [31:0]     ADC_CFG;
wire [31:0]     CTRL_REG;
wire [31:0]     INT_CLEAR;
wire [31:0]     INT_STATUS;
wire [31:0]     PMU_CFG0;
wire [31:0]     PMU_CFG1;
wire [31:0]     PAD_CTRL;
wire [31:0]     ISP_PATTERN_CFG;
wire [31:0]     ISP_DPC_CFG;
wire            chip_info_wr;
wire            chip_info_rd;
wire            crgu_ctrl_wr;
wire            crgu_ctrl_rd;
wire            pixel_size_wr;
wire            pixel_size_rd;
wire            fifo_threshold_wr;
wire            fifo_threshold_rd;
wire            fifo_used_wr;
wire            fifo_used_rd;
wire            adc_cfg_wr;
wire            adc_cfg_rd;
wire            ctrl_reg_wr;
wire            ctrl_reg_rd;
wire            int_clear_wr;
wire            int_clear_rd;
wire            int_status_wr;
wire            int_status_rd;
wire            pmu_cfg0_wr;
wire            pmu_cfg0_rd;
wire            pmu_cfg1_wr;
wire            pmu_cfg1_rd;
wire            pad_ctrl_wr;
wire            pad_ctrl_rd;
wire            isp_pattern_cfg_wr;
wire            isp_pattern_cfg_rd;
wire            isp_dpc_cfg_wr;
wire            isp_dpc_cfg_rd;
wire            reg_wr;
wire            reg_rd;
assign reg_wr = psel & pwrite & penable;
assign reg_rd = psel & (~pwrite) & (~penable);
assign chip_info_wr = (paddr == 32'h0000 + 8'h00) & reg_wr;
assign chip_info_rd = (paddr == 32'h0000 + 8'h00) & reg_rd;
assign crgu_ctrl_wr = (paddr == 32'h0000 + 8'h02) & reg_wr;
assign crgu_ctrl_rd = (paddr == 32'h0000 + 8'h02) & reg_rd;
assign pixel_size_wr = (paddr == 32'h0000 + 8'h04) & reg_wr;
assign pixel_size_rd = (paddr == 32'h0000 + 8'h04) & reg_rd;
assign fifo_threshold_wr = (paddr == 32'h0000 + 8'h06) & reg_wr;
assign fifo_threshold_rd = (paddr == 32'h0000 + 8'h06) & reg_rd;
assign fifo_used_wr = (paddr == 32'h0000 + 8'h08) & reg_wr;
assign fifo_used_rd = (paddr == 32'h0000 + 8'h08) & reg_rd;
assign adc_cfg_wr = (paddr == 32'h0000 + 8'h0a) & reg_wr;
assign adc_cfg_rd = (paddr == 32'h0000 + 8'h0a) & reg_rd;
assign ctrl_reg_wr = (paddr == 32'h0000 + 8'h0c) & reg_wr;
assign ctrl_reg_rd = (paddr == 32'h0000 + 8'h0c) & reg_rd;
assign int_clear_wr = (paddr == 32'h0000 + 8'h0e) & reg_wr;
assign int_clear_rd = (paddr == 32'h0000 + 8'h0e) & reg_rd;
assign int_status_wr = (paddr == 32'h0000 + 8'h10) & reg_wr;
assign int_status_rd = (paddr == 32'h0000 + 8'h10) & reg_rd;
assign pmu_cfg0_wr = (paddr == 32'h0000 + 8'h12) & reg_wr;
assign pmu_cfg0_rd = (paddr == 32'h0000 + 8'h12) & reg_rd;
assign pmu_cfg1_wr = (paddr == 32'h0000 + 8'h14) & reg_wr;
assign pmu_cfg1_rd = (paddr == 32'h0000 + 8'h14) & reg_rd;
assign pad_ctrl_wr = (paddr == 32'h0000 + 8'h16) & reg_wr;
assign pad_ctrl_rd = (paddr == 32'h0000 + 8'h16) & reg_rd;
assign isp_pattern_cfg_wr = (paddr == 32'h0000 + 8'h18) & reg_wr;
assign isp_pattern_cfg_rd = (paddr == 32'h0000 + 8'h18) & reg_rd;
assign isp_dpc_cfg_wr = (paddr == 32'h0000 + 8'h20) & reg_wr;
assign isp_dpc_cfg_rd = (paddr == 32'h0000 + 8'h20) & reg_rd;
assign CHIP_INFO[31:16] = 16'b0;
assign CHIP_INFO[15:8] = chip_version;
assign CHIP_INFO[7:0] = chip_id;
assign CRGU_CTRL[15:4] = 12'b0;
assign CRGU_CTRL[3] = rg_fifo_reset;
assign CRGU_CTRL[2] = rg_isp_ckgt_en;
assign CRGU_CTRL[1] = rg_afe_ckgt_en;
assign CRGU_CTRL[0] = rg_fifo_ckgt_en;
assign PIXEL_SIZE[15:8] = rg_pixel_height;
assign PIXEL_SIZE[7:0] = rg_pixel_width;
assign FIFO_THRESHOLD[15:0] = rg_fifo_enough_th;
assign FIFO_USED[15:0] = ro_fifo_used;
assign ADC_CFG[15:8] = 8'b0;
assign ADC_CFG[7:0] = rg_adc_sample_prd;
assign CTRL_REG[15:14] = 2'h0;
assign CTRL_REG[13] = rg_fifo_chk_en;
assign CTRL_REG[12] = rg_frame_mode;
assign CTRL_REG[11:8] = rg_multi_frame_num;
assign CTRL_REG[7:0] = rg_setup_time;
assign INT_CLEAR[15:5] = 11'h0;
assign INT_CLEAR[4:0] = 5'h0;
assign INT_STATUS[15:5] = 11'h0;
assign INT_STATUS[4:0] = ro_int_status;
assign PMU_CFG0[15] = 1'h0;
assign PMU_CFG0[14] = rg_ldo_manual_mode;
assign PMU_CFG0[13] = rg_da_lnvref_pow;
assign PMU_CFG0[12] = rg_faster_sr_nosleep;
assign PMU_CFG0[11] = rg_pmu_fast_wakeup;
assign PMU_CFG0[10] = rg_vcm_pulsemode;
assign PMU_CFG0[9:7] = rg_timing_ldo;
assign PMU_CFG0[6:5] = rg_timing_vcm;
assign PMU_CFG0[4] = rg_pmu_fifocut;
assign PMU_CFG0[3] = 1'h0;
assign PMU_CFG0[2] = rg_nosleep;
assign PMU_CFG0[1:0] = rg_sync_mode;
assign PMU_CFG1[15:14] = 2'h0;
assign PMU_CFG1[13:8] = rg_syncin_t1_set;
assign PMU_CFG1[7:2] = rg_pmu_wkup_time;
assign PMU_CFG1[1] = rg_syncin_polar_sel;
assign PMU_CFG1[0] = rg_int_pwrup;
assign PAD_CTRL[15:0] = 16'h0;
assign ISP_PATTERN_CFG[15:2] = 14'h0;
assign ISP_PATTERN_CFG[1:0] = rg_bayer_pattern;
assign ISP_DPC_CFG[15:8] = rg_dpc_thres;
assign ISP_DPC_CFG[7:0] = rg_dpc_clip;
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_fifo_reset <= 1'b0;
    end
    else if(crgu_ctrl_wr) begin
        rg_fifo_reset <= pwdata[3];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_isp_ckgt_en <= 1'b0;
    end
    else if(crgu_ctrl_wr) begin
        rg_isp_ckgt_en <= pwdata[2];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_afe_ckgt_en <= 1'b0;
    end
    else if(crgu_ctrl_wr) begin
        rg_afe_ckgt_en <= pwdata[1];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_fifo_ckgt_en <= 1'b0;
    end
    else if(crgu_ctrl_wr) begin
        rg_fifo_ckgt_en <= pwdata[0];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_pixel_height <= 8'h10;
    end
    else if(pixel_size_wr) begin
        rg_pixel_height <= pwdata[15:8];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_pixel_width <= 8'h10;
    end
    else if(pixel_size_wr) begin
        rg_pixel_width <= pwdata[7:0];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_fifo_enough_th <= 16'h100;
    end
    else if(fifo_threshold_wr) begin
        rg_fifo_enough_th <= pwdata[15:0];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_adc_sample_prd <= 8'hf;
    end
    else if(adc_cfg_wr) begin
        rg_adc_sample_prd <= pwdata[7:0];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_fifo_chk_en <= 1'b0;
    end
    else if(ctrl_reg_wr) begin
        rg_fifo_chk_en <= pwdata[13];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_frame_mode <= 1'h1;
    end
    else if(ctrl_reg_wr) begin
        rg_frame_mode <= pwdata[12];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_multi_frame_num <= 4'h4;
    end
    else if(ctrl_reg_wr) begin
        rg_multi_frame_num <= pwdata[11:8];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_setup_time <= 8'h10;
    end
    else if(ctrl_reg_wr) begin
        rg_setup_time <= pwdata[7:0];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_int_clr <= 5'h0;
    end
    else if(int_clear_wr) begin
        rg_int_clr <= pwdata[4:0];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_frame_trigger_start <= 1'h0;
    end
    else if(pmu_cfg0_wr) begin
        rg_frame_trigger_start <= pwdata[15];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_ldo_manual_mode <= 1'h0;
    end
    else if(pmu_cfg0_wr) begin
        rg_ldo_manual_mode <= pwdata[14];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_da_lnvref_pow <= 1'h0;
    end
    else if(pmu_cfg0_wr) begin
        rg_da_lnvref_pow <= pwdata[13];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_faster_sr_nosleep <= 1'h0;
    end
    else if(pmu_cfg0_wr) begin
        rg_faster_sr_nosleep <= pwdata[12];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_pmu_fast_wakeup <= 1'h0;
    end
    else if(pmu_cfg0_wr) begin
        rg_pmu_fast_wakeup <= pwdata[11];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_vcm_pulsemode <= 1'h0;
    end
    else if(pmu_cfg0_wr) begin
        rg_vcm_pulsemode <= pwdata[10];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_timing_ldo <= 3'h0;
    end
    else if(pmu_cfg0_wr) begin
        rg_timing_ldo <= pwdata[9:7];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_timing_vcm <= 2'h0;
    end
    else if(pmu_cfg0_wr) begin
        rg_timing_vcm <= pwdata[6:5];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_pmu_fifocut <= 1'h0;
    end
    else if(pmu_cfg0_wr) begin
        rg_pmu_fifocut <= pwdata[4];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_cardiff_start <= 1'h0;
    end
    else if(pmu_cfg0_wr) begin
        rg_cardiff_start <= pwdata[3];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_nosleep <= 1'h0;
    end
    else if(pmu_cfg0_wr) begin
        rg_nosleep <= pwdata[2];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_sync_mode <= 2'h0;
    end
    else if(pmu_cfg0_wr) begin
        rg_sync_mode <= pwdata[1:0];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_syncin_t1_set <= 6'h08;
    end
    else if(pmu_cfg1_wr) begin
        rg_syncin_t1_set <= pwdata[13:8];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_pmu_wkup_time <= 6'h08;
    end
    else if(pmu_cfg1_wr) begin
        rg_pmu_wkup_time <= pwdata[7:2];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_syncin_polar_sel <= 1'h0;
    end
    else if(pmu_cfg1_wr) begin
        rg_syncin_polar_sel <= pwdata[1];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_int_pwrup <= 1'h0;
    end
    else if(pmu_cfg1_wr) begin
        rg_int_pwrup <= pwdata[0];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_bayer_pattern <= 2'h0;
    end
    else if(isp_pattern_cfg_wr) begin
        rg_bayer_pattern <= pwdata[1:0];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_dpc_thres <= 8'h0;
    end
    else if(isp_dpc_cfg_wr) begin
        rg_dpc_thres <= pwdata[15:8];
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rg_dpc_clip <= 8'h0;
    end
    else if(isp_dpc_cfg_wr) begin
        rg_dpc_clip <= pwdata[7:0];
    end
end
always@(*) begin
    case(paddr)
        32'h0000 + 8'h00 : prdata = CHIP_INFO ;
        32'h0000 + 8'h02 : prdata = CRGU_CTRL ;
        32'h0000 + 8'h04 : prdata = PIXEL_SIZE;
        32'h0000 + 8'h06 : prdata = FIFO_THRESHOLD;
        32'h0000 + 8'h08 : prdata = FIFO_USED ;
        32'h0000 + 8'h0a : prdata = ADC_CFG   ;
        32'h0000 + 8'h0c : prdata = CTRL_REG  ;
        32'h0000 + 8'h0e : prdata = INT_CLEAR ;
        32'h0000 + 8'h10 : prdata = INT_STATUS;
        32'h0000 + 8'h12 : prdata = PMU_CFG0  ;
        32'h0000 + 8'h14 : prdata = PMU_CFG1  ;
        32'h0000 + 8'h16 : prdata = PAD_CTRL  ;
        32'h0000 + 8'h18 : prdata = ISP_PATTERN_CFG;
        32'h0000 + 8'h20 : prdata = ISP_DPC_CFG;
        default:prdata = 32'b0;
    endcase
end
endmodule