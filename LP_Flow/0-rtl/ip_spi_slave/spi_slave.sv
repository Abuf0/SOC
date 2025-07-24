module spi_slave(
    input               clk_spi     ,
    input               rstn_spi    ,
    input               clk_sys     ,
    input               rstn_sys    ,
    input               spi_csn     ,
    input               spi_mosi    ,
    output logic        spi_miso    ,
    output logic        cmd_idle    ,  
    output logic        cmd_img     ,  
    output logic        cmd_sleep   ,  
    output logic        cmd_wakeup  ,  
    output logic        reg_wr      ,
    output logic        reg_rd      ,
    output logic [15:0] reg_addr    ,
    output logic [15:0] reg_wdata   ,
    input        [15:0] reg_rdata   
);
parameter WRITE = 8'hf0;
parameter READ = 8'hf1;
parameter IDLE = 8'hf2;
parameter IMG = 8'hf3;
parameter SLP = 8'hf4;
parameter WAKE = 8'hf5;
logic rstn_spi_csn;
logic cmd_done;
logic addr_done;
logic [3:0] bit_cnt;
logic [7:0] cmd_sin;
logic [15:0] addr_sin;
logic [15:0] data_sin;
logic rd_flag;
logic wr_flag;
logic reg_wr_pre;
logic reg_rd_pre;
logic [15:0] reg_addr_pre;
logic [15:0] reg_wdata_pre;
logic cmd_idle_pre;  
logic cmd_img_pre;    
logic cmd_sleep_pre;  
logic cmd_wakeup_pre; 

sync_reset rstn_spi_csn_inst(.clk(clk_spi), .async_reset(spi_csn), .sync_rstn(rstn_spi_csn));

typedef enum logic [1:0] {IDLE, CMD, ADDR, DATA} state_t;
state_t state_c, state_n;
always_ff@(posedge clk_spi or negedge rstn_spi_csn) begin
    if(~rstn_spi_csn)
        state_c <= IDLE;
    else
        state_c <= state_n;
end
always @(*) begin
    state_n = stae_c;
    case(state_c)
        IDLE:  state_n = CMD;
        CMD:   state_n = cmd_done?  (rd_flag?   DATA : (wr_flag?  ADDR : CMD)) : CMD;
        ADDR:  state_n = addr_done? DATA : ADDR;
        DATA:  state_n = DATA;
        default: state_n = IDLE;
    endcase
end

assign cmd_done = (state_c == CMD && bit_cnt == 4'd7);
assign addr_done = (state_c == ADDR && bit_cnt == 4'd15);

always_ff@(posedge clk_spi or negedge rstn_spi_csn) begin
    if(~rstn_spi_csn)
        bit_cnt <= 4'd0;
    else if(state_n != state_c)
        bit_cnt <= 4'd0;
    else 
        bit_cnt <= bit_cnt + 4'd1;
end

always_ff@(posedge clk_spi or negedge rstn_spi_csn) begin
    if(~rstn_spi_csn)
        cmd_sin <= 8'd0;
    else if(state_n == CMD)
        cmd_sin <= {cmd_sin[6:0], spi_mosi};
end

always_ff@(posedge clk_spi or negedge rstn_spi) begin
    if(~rstn_spi)
        wr_flag <= 1'b0;
    else if(cmd_done && cmd_sin == WRITE)
        wr_flag <= 1'b1;
    else if(state_c == ADDR && state_n == IDLE)
        wr_flag <= 1'b0;
end

always_ff@(posedge clk_spi or negedge rstn_spi) begin
    if(~rstn_spi)
        rd_flag <= 1'b0;
    else if(state_c == ADDR && state_n == IDLE)
        rd_flag <= 1'b1;
    else if(cmd_done && cmd_sin == WRITE)
        rd_flag <= 1'b0;
end

always_ff@(posedge clk_spi or negedge rstn_spi) begin
    if(~rstn_spi)
        reg_wr_pre <= 1'b0;
    else if(wr_flag && (state_c == DATA) && (bit_cnt == 4'd15))
        reg_wr_pre <= 1'b1;
    else
        reg_wr_pre <= 1'b0;
end

always_ff@(posedge clk_spi or negedge rstn_spi) begin
    if(~rstn_spi)
        reg_rd_pre <= 1'b0;
    else if(state_c == ADDR && state_n == IDLE)
        reg_rd_pre <= 1'b1;
    else if(cmd_done && cmd_sin == READ)
        reg_rd_pre <= 1'b1;
    else if(rd_flag && (state_c == DATA) && (bit_cnt == 4'd15))
        reg_rd_pre <= 1'b1;
    else
        reg_rd_pre <= 1'b0;
end

always_ff@(posedge clk_spi or negedge rstn_spi) begin
    if(~rstn_spi)
        reg_addr_pre <= 16'd0;
    else if(state_n == ADDR)
        reg_addr_pre <= {reg_addr_pre[14:0], spi_mosi};
    else if((state_c == DATA) && (bit_cnt == 4'd15))
        reg_addr_pre <= reg_addr_pre + 1;
end

always_ff@(posedge clk_spi or negedge rstn_spi) begin
    if(~rstn_spi)
        reg_wdata_pre <= 16'd0;
    else if(state_n == DATA && wr_flag)
        reg_wdata_pre <= {reg_wdata_pre[14:0], spi_mosi};
end
logic reg_wr_togg;
logic reg_wr_sync;
logic reg_wr_sync_d1;
logic reg_rd_togg;
logic reg_rd_sync;
logic reg_rd_sync_d1;

always_ff@(posedge clk_spi or negedge rstn_spi) begin
    if(~rstn_spi)
        reg_wr_togg <= 1'b0;
    else
        reg_wr_togg <= reg_wr_pre?  ~reg_wr_togg : reg_wr_togg;
end
sync_level reg_wr_sync_inst(.clk(clk_sys), .rstn(rstn_sys), .level_in(reg_wr_togg), .level_out(reg_wr_sync));
always_ff@(posedge clk_sys or negedge rstn_sys) begin
    if(~rstn_sys)
        reg_wr_sync_d1 <= 1'b0;
    else
        reg_wr_sync_d1 <= reg_wr_sync;
end

always_ff@(posedge clk_sys or negedge rstn_sys) begin
    if(~rstn_sys)
        reg_wr <= 1'b0;
    else
        reg_wr <= reg_wr_sync_d1 ^ reg_wr_sync;
end

always_ff@(posedge clk_spi or negedge rstn_spi) begin
    if(~rstn_spi)
        reg_rd_togg <= 1'b0;
    else
        reg_rd_togg <= reg_rd_pre?  ~reg_rd_togg : reg_rd_togg;
end
sync_level reg_rd_sync_inst(.clk(clk_sys), .rstn(rstn_sys), .level_in(reg_rd_togg), .level_out(reg_rd_sync));
always_ff@(posedge clk_sys or negedge rstn_sys) begin
    if(~rstn_sys)
        reg_rd_sync_d1 <= 1'b0;
    else
        reg_rd_sync_d1 <= reg_rd_sync;
end

always_ff@(posedge clk_sys or negedge rstn_sys) begin
    if(~rstn_sys)
        reg_rd <= 1'b0;
    else
        reg_rd <= reg_rd_sync_d1 ^ reg_rd_sync;
end

always_ff@(posedge clk_sys or negedge rstn_sys) begin
    if(~rstn_sys)
        reg_addr <= 16'b0;
    else if((reg_wr_sync_d1 ^ reg_wr_sync) || (reg_rd_sync_d1 ^ reg_rd_sync))
        reg_addr <= reg_addr_pre;
end

always_ff@(posedge clk_sys or negedge rstn_sys) begin
    if(~rstn_sys)
        reg_wdata <= 16'b0;
    else if(reg_wr_sync_d1 ^ reg_wr_sync)
        reg_wdata <= reg_wdata_pre;
end

logic reg_rd_ack;
logic [15:0] reg_rdata_ack;
logic [15:0] miso_shift;
sync_level reg_rd_ack_inst(.clk(clk_spi), .rstn(rstn_spi), .level_in(reg_rd), .level_out(reg_rd_ack));
always_ff@(posedge clk_spi or negedge rstn_spi) begin
    if(~rstn_spi)
        reg_rdata_ack <= 16'd0;
    else if(reg_rd_ack)
        reg_rdata_ack <= reg_rdata;
end

always_ff@(posedge clk_spi or negedge rstn_spi_csn) begin
    if(~rstn_spi_csn)
        {spi_miso, miso_shift} <= 17'b0;
    else if(reg_rd_pre)
        {spi_miso, miso_shift} <= {1'b0, reg_rdata_ack};
    else if(rd_flag && (state_c == DATA))
        {spi_miso, miso_shift} <= {miso_shift, 1'b0};
end

always_ff@(posedge clk_spi or negedge rstn_spi) begin
    if(~rstn_spi)
        cmd_idle_pre <= 1'b0;
    else if(cmd_done) 
        cmd_idle_pre <= (cmd_sin == IDLE)?  1'b1 : 1'b0;
end

always_ff@(posedge clk_spi or negedge rstn_spi) begin
    if(~rstn_spi)
        cmd_img_pre <= 1'b0;
    else if(cmd_done) 
        cmd_img_pre <= (cmd_sin == IMG)?  1'b1 : 1'b0;
end

always_ff@(posedge clk_spi or negedge rstn_spi) begin
    if(~rstn_spi)
        cmd_sleep_pre <= 1'b0;
    else if(cmd_done) 
        cmd_sleep_pre <= (cmd_sin == SLEEP)?  1'b1 : 1'b0;
end

always_ff@(posedge clk_spi or negedge rstn_spi) begin
    if(~rstn_spi)
        cmd_wakeup_pre <= 1'b0;
    else if(cmd_done) 
        cmd_wakeup_pre <= (cmd_sin == WAKE)?  1'b1 : 1'b0;
end

sync_level cmd_idle_sync(.clk(clk_sys), .rstn(rstn_sys), .level_in(cmd_idle_pre), .level_out(cmd_idle));
sync_level cmd_img_sync(.clk(clk_sys), .rstn(rstn_sys), .level_in(cmd_img_pre), .level_out(cmd_img));
sync_level cmd_sleep_sync(.clk(clk_sys), .rstn(rstn_sys), .level_in(cmd_sleep_pre), .level_out(cmd_sleep));
sync_level cmd_wakeup_sync(.clk(clk_sys), .rstn(rstn_sys), .level_in(cmd_wakeup_pre), .level_out(cmd_wakeup));

endmodule