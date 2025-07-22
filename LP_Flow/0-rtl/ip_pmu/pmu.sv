module pmu(
    input           scan_mode,
    input           scan_rstn,
    input           clk,
    input           rstn,
    input           rg_ldo_manual_mode,
    input           rg_da_lnvref_pow,
    input           rg_faster_sr_nosleep,
    input           rg_pmu_fast_wakeup,
    input           rg_vcm_pulsemode,
    input [2:0]     rg_timing_ldo,
    input [1:0]     rg_timing_vcm,
    input           rg_pmu_fifocut,
    input           rg_cardiff_start,
    input           rg_nosleep,
    input [1:0]     rg_sync_mode,
    input           rg_frame_trigger_start,
    input [6:0]     rg_syncin_t1_set,
    input [5:0]     rg_pmu_wkup_time,
    input           rg_syncin_polar_sel,
    input           rg_int_pwrup,
    input           efuse_done_13m
    input           efuse_busy_13m,
    output logic    pmu_efuse_start_13m,
    output logic    efuse_load_state,
    output logic    efuse_load_done,
    input           timeslot_start,
    input           data2fifo_done,
    output logic    timer_pmu_start,
    input           tmr_wakeup, // 32k
    input           SYNC,
    input           cmd_wakeup,
    input           cmd_sleep,
    output logic    osc13m_ready,
    output logic    osc13m_ready_pulse,
    output logic    wakeup_ready_pulse,
    input           int_req,
    input           int_ack,
    output logic    int_pwrup_ready,
    output logic    tm_clk_en_32k,
    output logic    osc13m_clk_en_32k,
    output logic    da_stb_en,
    output logic    da_pmu_fifocut,
    output logic    da_vcm_pow,
    output logic    da_vcm_qc_en,
    output logic    da_ib_pow,
    output logic    da_ldovref_pow,
    output logic    da_osc13m_pow,
    output logic    da_vcm_pulsemode,
    output logic    pmu_fifo_rstn,
    output logic    shut_iso_en,
    output logic    shut_rstn
);

logic pwr_up_done;
logic efuse_done;
logic efuse_time_out;
logic work_start;
logic sync_in_sleep_mode;
logic syncin_wakeup;
logic t1_gt_pmu_wkup;
logic [6:0] syncin_timer;
logic sync_in_pos;
logic syncin_timer_done;
logic [6:0] wakeup_time_mux;
logic sync_polar_sel;
logic sync_in_s;
logic sync_in_d;
logic cmd_sleep_real;
logic cmd_sleep_real_latch;

assign efuse_done = 1'b1;
assign efuse_time_out = 1'b1;
sync_level u_work_start (.clk(clk), .rstn(rstn), .data_in(rg_cardiff_start), .data_out(work_start));
assign sync_in_sleep_mode = (rg_sync_mode[1] && ~rg_nosleep);
assign syncin_wakeup = (rg_sync_mode == 2'd3)?  (rg_frame_trigger_start && work_start) : (t1_gt_pmu_wkup?   (syncin_timer == (rg_syncin_t1_set - rg_pmu_wkup_time)) : sync_in_pos);
assign t1_gt_pmu_wkup = rg_syncin_t1_set > rg_pmu_wkup_time;
assign sync_in_pos = (rg_sync_mode == 2'd2)?    (sync_in_d && ~sync_in_s) : (rg_frame_trigger_start & work_start);

assign wakeup_time_mux = t1_gt_pmu_wkup?    rg_syncin_t1_set : rg_pmu_wkup_time;
assign syncin_timer_done = (syncin_timer == wakeup_time_mux);

assign sync_polar_sel = rg_syncin_polar_sel?    ~SYNC : SYNC;
sync_level u_sync_in_s (.clk(clk), .rstn(rstn), .data_in(sync_polar_sel), .data_out(sync_in_s));

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        sync_in_d <= 1'b0;
    else if(~work_start)
        sync_in_d <= 1'b0;
    else if(rg_sync_mode == 2'd2)
        sync_in_d <= sync_in_s;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        syncin_timer <= 'd0;
    else if(~work_start)
        syncin_timer <= 'd0;
    else if(sync_in_pos && (rg_sync_mode == 2'd2))
        syncin_timer <= 'd1;
    else if(syncin_timer_done)
        syncin_timer <= 'd0;
    else if(syncin_timer != 0)
        syncin_timer <= syncin_timer + 1'b1;
end

logic int_req_real;
logic wait_int_ready;
logic cmd_sleep_d;
logic cmd_wakeup_real;
logic cmd_fast_wakeup;
logic rg_pmu_fast_wakeup_sync;
logic no_sync_in_phase;
logic idle_nosleep_case;
logic wakeup_case;
logic frame_done_real;
logic sleep_phase;
logic master_access;
logic nosleep_case;
logic wakeup_case_latch;
logic pulse2always;
logic awon_wakeup_done;

assign int_req_real = int_req && rg_int_pwrup;
assign cmd_sleep_real = cmd_sleep_d && (~wait_int_ready || (wait_int_ready && int_ack && ~int_req_real)) && ~cmd_wakeup_real;
sync_level u_fast_wakeup (.clk(clk), .rstn(rstn), .data_in(rg_pmu_fast_wakeup), .data_out(rg_pmu_fast_wakeup_sync));
assign frame_done_real = ((cmd_sleep_real && sleep_phase) || (data2fifo_done && ~wait_int_ready && (~master_access || cmd_sleep_real)));

assign cmd_fast_wakeup = cmd_wakeup_real & rg_pmu_fast_wakeup_sync;
always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        wait_int_ready <= 1'b0;
    else if(int_req_real)
        wait_int_ready <= 1'b1;
    else if(int_ack)
        wait_int_ready <= 1'b0;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        cmd_sleep_d <= 1'b0;
    else
        cmd_sleep_d <= cmd_sleep;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        cmd_wakeup_real <= 1'b0;
    else
        cmd_wakeup_real <= cmd_wakeup & efuse_load_done;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        cmd_sleep_real_latch <= 1'b0;
    else if(pmu_cs == INIT_PWUP && (~work_start || no_sync_in_phase) && cmd_sleep_real)
        cmd_sleep_real_latch <= 1'b1;
    else if(pmu_cs == IDLE || cmd_wakeup_real)
        cmd_sleep_real_latch <= 1'b0;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        no_sync_in_phase <= 1'b0;
    else if(~work_start)
        no_sync_in_phase <= 1'b0;
    else if(sync_in_sleep_mode && syncin_wakeup)
        no_sync_in_phase <= 1'b0;
    else if(sync_in_sleep_mode && pmu_cs == IDLE)
        no_sync_in_phase <= 1'b1;
end

assign idle_nosleep_case = rg_nosleep || efuse_busy_32k_d || wakeup_case;
sync_level u_efuse_busy (.clk(clk), .rstn(rstn), .data_in(efuse_busy_13m), .data_out(efuse_busy_32k_d));
assign wakeup_case = cmd_wakeup_real || tmr_wakeup || syncin_wakeup || int_req_real;

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        sleep_phase <= 1'b0;
    else if(~work_start)
        sleep_phase <= 1'b0;
    else if(tmr_wakeup || syncin_wakeup)
        sleep_phase <= 1'b0;
    else if(pmu_cs == WORK && data2fifo_done)
        sleep_phase <= 1'b1;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        master_access <= 1'b1;
    else if(cmd_wakeup_real || int_req_real)
        master_access <= 1'b1;
    else if(cmd_sleep_real)
        master_access <= 1'b0;
end

assign nosleep_case = rg_nosleep || efuse_busy_32k_d || wakeup_case;

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        wakeup_case_latch <= 1'b0;
    else if(wakeup_case && pmu_cs == TO_SLEEP)
        wakeup_case_latch <= 1'b1;
    else if(pmu_cs == WORK)
        wakeup_case_latch <= 1'b0;
end

logic pulse2always_rise;
logic pulse2always_trig;
logic rg_vcm_pulsemode_sync;
logic enter_sleep;
logic da_stb_en_d;
sync_level u_vcm_pulsemode (.clk(clk), .rstn(rstn), .data_in(rg_vcm_pulsemode), .data_out(rg_vcm_pulsemode_sync));

assign pulse2always_trig = (da_vcm_pulse_mode & ~rg_vcm_pulsemode_sync);
assign pulse2always_rise = enter_sleep & pulse2always_trig;
assign enter_sleep = ~da_stb_en_d && da_stb_en && (pmu_cs == TO_SLEEP) && ~wakeup_case;
always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        pulse2always <= 1'b0;
    else if(pulse2always_rise)
        pulse2always <= 1'b1;
    else if((cmd_wakeup_real || int_req_real) && (pmu_cs == SLEEP) || awon_wakeup_done)
        pulse2always <= 1'b0;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        da_stb_en_d <= 1'b1;
    else 
        da_stb_en_d <= da_stb_en;
end
logic [5:0] ldo_timer;
logic pwr_up_done;
logic wakeup_done;
logic [3:0] stb_en_neg_thd;
logic [2:0] vcm_tmr_thd;
logic [3:0] ldo_tmr_thd;
logic cmd_fast_wakeup;

assign pwr_up_done = (ldo_timer == 6'd40) && (pmu_cs == INIT_PWUP);
assign wakeup_done = (ldo_timer == {2'h0, stb_en_neg_thd} + 6'd2) && (pmu_cs == WAKE_UP);
assign awon_wakeup_done = (ldo_timer == 6'd21) && (pmu_cs == AWON_WAKEUP);
assign stb_en_neg_thd = {1'b0, vcm_tmr_thd} + ldo_tmr_thd;
assign cmd_fast_wakeup = cmd_wakeup_real & rg_pmu_fast_wakeup_sync;

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        ldo_timer <= 'd0;
    else if(pwr_up_done || wakeup_done || awon_wakeup_done)
        ldo_timer <= 'd0;
    else if(pmu_cs == WORK && (ldo_timer != 'd0) && (ldo_timer < stb_en_neg_thd + 2'd3))
        ldo_timer <= ldo_timer + 1;
    else if(pmu_cs == SLEEP && pmu_ns == INIT_PWUP)
        ldo_timer <= 'd16;
    else if(pmu_cs == INIT_PWUP || pmu_cs == WAKE_UP || pmu_cs == AWON_WAKEUP)
        ldo_timer <= ldo_timer + 1;
    else
        ldo_timer <= 'd0;
end

assign awon_wakeup_done = (ldo_timer == 6'd21) && (pmu_cs == AWON_WAKEUP);

always@(*) begin
    case(rg_timing_ldo)
        3'h0:   ldo_tmr_thd = 4'h0;
        3'h1:   ldo_tmr_thd = 4'h1;
        3'h2:   ldo_tmr_thd = 4'h2;
        3'h3:   ldo_tmr_thd = 4'h4;
        3'h4:   ldo_tmr_thd = 4'h8;
        default:ldo_tmr_thd = 4'h4;
    endcase
end

always@(*) begin
    case(rg_timing_vcm)
        2'h0:   vcm_tmr_thd = 3'h0;
        2'h1:   vcm_tmr_thd = 3'h1;
        2'h2:   vcm_tmr_thd = 3'h3;
        2'h3:   vcm_tmr_thd = 3'h7;
        default:vcm_tmr_thd = 3'h0;
    endcase
end

assign timer_pmu_start = work_start && ((rg_sync_mode == 2'd3)?  rg_frame_trigger_start : syncin_timer_done);

typedef enum logic [3:0] {INIT_PWUP, EFUSE_LOAD, IDLE, WORK, SLEEP, WAKE_UP, AWON_WAKEUP, TO_SLEEP} state_t;
state_t pmu_cs, pmu_ns;
always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        pmu_cs <= INIT_PWUP;
    else
        pmu_cs <= pmu_ns;
end
always @(*) begin
    case(pmu_cs)
        INIT_PWUP:  pmu_ns = pwr_up_done?   EFUSE_LOAD : INIT_PWUP;
        EFUSE_LOAD: pmu_ns = (efuse_done || efuse_time_out)?    IDLE : EFUSE_LOAD;
        IDLE:       pmu_ns = (work_start && ~sync_in_sleep_mode)?   WORK :
                             syncin_wakeup? WORK :
                             ((cmd_sleep_real || cmd_sleep_real_latch) && ~idle_nosleep_case)?  SLEEP : IDLE;
        WORK:       pmu_ns = ~work_start?   IDLE :
                             (frame_done_real && ~nosleep_case)?    TO_SLEEP : WORK;
        TO_SLEEP:   pmu_ns = (wakeup_case && pulse2always)?     AWON_WAKEUP : 
                             wakeup_case?   WAKE_UP :
                             da_stb_en?     SLEEP : TO_SLEEP;
        SLEEP:      pmu_ns = ((wakeup_case || wakeup_case_latch) && pulse2always)?   AWON_WAKEUP : 
                             (wakeup_case || wakeup_case_latch)?    WAKE_UP : SLEEP;
        WAKE_UP:    pmu_ns = (wakeup_done && no_sync_in_phase && ~syncin_wakeup)?   IDLE :
                             wakeup_done?   WORK : WAKE_UP;
        AWON_WAKEUP:pmu_ns = (awon_wakeup_done && no_sync_in_phase)?   IDLE :
                              awon_wakeup_done? WORK : AWON_WAKEUP;
        default:    pmu_ns = INIT_PWUP;
    endcase
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        da_stb_en <= 1'b1;
    else if(cmd_fast_wakeup)
        da_stb_en <= 1'b0;
    else if(pmu_pd_en && (pmu_cs == TO_SLEEP))
        da_stb_en <= 1'b1;
    else if((pmu_cs == INIT_PWUP) && (ldo_timer == 6'd35))
        da_stb_en <= 1'b0;
    else if((pmu_cs == AWON_WAKEUP) && (ldo_timer == 6'd19))
        da_stb_en <= 1'b0;
    else if((pmu_cs == WAKE_UP) && (ldo_timer == stb_en_neg_thd))
        da_stb_en <= 1'b0;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        da_vcm_pow <= 1'b0;
    else if(cmd_fast_wakeup)
        da_vcm_pow <= 1'b1;
    else if((pmu_cs == INIT_PWUP) && (ldo_timer == 6'd15))
        da_vcm_pow <= 1'b1;
    else if((pmu_ns == AWON_WAKEUP) || (pmu_ns == INIT_PWUP) || (pmu_ns == WAKE_UP) || (pmu_ns == TO_SLEEP) || (pmu_ns == SLEEP))
        da_vcm_pow <= 1'b1;
    else if((pmu_cs == TO_SLEEP) && (da_vcm_pulsemode || rg_vcm_pulsemode_sync) && da_stb_en)
        da_vcm_pow <= 1'b0;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        da_vcm_qc_en <= 1'b0;
    else if((pmu_cs == INIT_PWUP) && (ldo_timer == 6'd17))
        da_vcm_qc_en <= ~rg_vcm_pulsemode_sync;
    else if((pmu_cs == AWON_WAKEUP) && (ldo_timer == 6'd1))
        da_vcm_qc_en <= 1'b1;
    else if(rg_vcm_pulsemode_sync && enter_sleep)
        da_vcm_qc_en <= 1'b0;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        da_ib_pow <= 1'b0;
    else if(cmd_fast_wakeup)
        da_ib_pow <= 1'b1;
    else if((pmu_cs == INIT_PWUP) && (ldo_timer == 6'd15))
        da_ib_pow <= 1'b1;
    else if((pmu_ns == AWON_WAKEUP) || (pmu_ns == INIT_PWUP) || (pmu_ns == WAKE_UP) || (pmu_ns == TO_SLEEP) || (pmu_ns == SLEEP))
        da_ib_pow <= 1'b1;
    else if((pmu_cs == TO_SLEEP) || (pmu_cs == SLEEP) && (pmu_ns == WAKE_UP))
        da_ib_pow <= 1'b1;
    else if((pmu_cs == TO_SLEEP) && da_stb_en)
        da_ib_pow <= 1'b0;
end

logic rg_ldo_manual_mode_sync;
logic rg_da_lnvref_pow_sync;
sync_level u_ldo_manual_mode_sync (.clk(clk), .rstn(rstn), .data_in(rg_ldo_manual_mode), .data_out(rg_ldo_manual_mode_sync));
sync_level u_da_lnvref_pow_syn (.clk(clk), .rstn(rstn), .data_in(rg_da_lnvref_pow), .data_out(rg_da_lnvref_pow_sync));

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        da_ldovref_pow <= 1'b0;
    else if(rg_ldo_manual_mode_sync)
        da_ldovref_pow <= rg_da_lnvref_pow_sync;
    else if((pmu_cs == INIT_PWUP) && (ldo_timer == 6'd31))
        da_ldovref_pow <= 1'b1;
    else if((pmu_ns == AWON_WAKEUP) && (ldo_timer == 6'd15)) 
        da_ldovref_pow <= 1'b1;
    else if((pmu_cs == TO_SLEEP) && da_stb_en)
        da_ldovref_pow <= 1'b0;
    else if((pmu_cs == WORK) && (ldo_timer == vcm_tmr_thd + 1'b1))
        da_ldovref_pow <= 1'b1;
    else if((pmu_cs == WAKE_UP) && (ldo_timer == vcm_tmr_thd))
        da_ldovref_pow <= 1'b1;
end
logic pmu_pd_en;
assign pmu_pd_en = shut_iso_en;
always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        da_osc13m_pow <= 1'b0;
    else if(cmd_fast_wakeup)
        da_osc13m_pow <= 1'b1;
    else if((pmu_cs == TO_SLEEP) && pmu_pd_en)
        da_osc13m_pow <= 1'b0;
    else if((pmu_cs == INIT_PWUP || pmu_cs == AWON_WAKEUP || pmu_cs == WAKE_UP) && ~da_stb_en)
        da_osc13m_pow <= 1'b1;
    else if(pmu_cs == WORK && (ldo_timer == stb_en_neg_thd + 2'd2))
        da_osc13m_pow <= 1'b1;
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        da_vcm_pulsemode <= 1'b0;
    else if(enter_sleep) begin
        if(rg_vcm_pulsemode_sync)
            da_vcm_pulsemode <= 1'b1;
        else 
            da_vcm_pulsemode <= 1'b0;
    end
end

logic shut_iso_en_pre;
logic shut_iso_en_scan;
always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        shut_iso_en_pre <= 1'b0;
    else if((pmu_cs == INIT_PWUP) && (ldo_timer == 6'd37))
        shut_iso_en_pre <= 1'b0;
    else if((pmu_cs == AWON_WAKEUP) && (ldo_timer == 6'd21))
        shut_iso_en_pre <= 1'b0;
    else if((pmu_cs == WAKE_UP) && (ldo_timer == {2'h0, stb_en_neg_thd} + 6'd2))
        shut_iso_en_pre <= 1'b0;
    else if((pmu_cs == WORK || pmu_cs == IDLE) && (pmu_ns == TO_SLEEP))
        shut_iso_en_pre <= 1'b1;
end
assign shut_iso_en_scan = scan_mode?    1'b0 : shut_iso_en_pre;
// BUFX4 dtc_shut_iso_en_buf (.A(shut_iso_en_scan), .Y(shut_iso_en));
assign shut_iso_en = shut_iso_en_scan;

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        shut_rstn <= 1'b0;
    else if((pmu_cs == TO_SLEEP) && pmu_pd_en)
        shut_rstn <= 1'b0;
    else begin
        if((pmu_cs == AWON_WAKEUP) && (ldo_timer == 6'd21))
            shut_rstn <= 1'b1;
        else if((pmu_cs == WAKE_UP) && (ldo_timer == {2'h0, stb_en_neg_thd} + 6'd2))
            shut_rstn <= 1'b1;
        else if(~shut_iso_en_pre)
            shut_rstn <= 1'b1;
    end
end

always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        tm_clk_en_32k <= 1'b0;
    else
        tm_clk_en_32k <= (pmu_ns == WORK && work_start);
end
logic da_osc13m_pow_d;
logic osc13m_clk_en_fast_wakeup;
always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        da_osc13m_pow_d <= 1'b0;
    else
        da_osc13m_pow_d <= da_osc13m_pow;
end
always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        osc13m_clk_en_fast_wakeup <= 1'b0;
    else
        osc13m_clk_en_fast_wakeup <= cmd_fast_wakeup;
end
always_ff @( posedge clk or negedge rstn ) begin
    if(~rstn)
        osc13m_clk_en_32k <= 1'b0;
    else if((~da_osc13m_pow_d && da_osc13m_pow) || (osc13m_clk_en_fast_wakeup && da_osc13m_pow))
        osc13m_clk_en_32k <= 1'b1;
    else if((pmu_cs == AWON_WAKEUP || pmu_cs == WAKE_UP) && da_osc13m_pow)
        osc13m_clk_en_32k <= 1'b1;
    else if((pmu_cs == WORK || pmu_cs == IDLE) && (pmu_ns == TO_SLEEP))
        osc13m_clk_en_32k <= 1'b0;
end

endmodule