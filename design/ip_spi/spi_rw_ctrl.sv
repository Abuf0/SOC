module spi_rw_ctrl(
    input sck,
    input sck_inv,
    input csn,
    input rstn,
    input csn_rstn,
    input mosi,
    input [15:0] rdata,
    output logic [15:0] addr,
    output logic [15:0] wdata,
    output logic addr_load,
    output logic data_load, // for write ctrl load to xx
    output logic read_load, // for read_data load to shit_o
    output logic miso
);
parameter CMD_READ = 8'hf1;
parameter CMD_WRITE = 8'hf0;
parameter CMD_RESET = 8'hf2;

logic cmd_flag;

logic [3:0] cmd_bit;
logic [15:0] shift_i;
logic [15:0] shift_o;
logic [15:0] shift_i_next;
logic [7:0] shift_cmd_next;

logic wr_flag;
logic rd_flag;

always_ff@(posedge sck or negedge csn_rstn) begin
    if(~csn_rstn)
        cmd_bit <= 4'd0;
    else if(csn)
        cmd_bit <= 4'd0;
    else  
        cmd_bit <= (cmd_bit[3])?     4'd8:(cmd_bit+1'b1);
end

always_ff@(posedge sck or negedge csn_rstn) begin
    if(~csn_rstn)
        shift_i <= 16'd0;
    else
        shift_i <= shift_i_next;
end
assign shift_i_next = {shift_i[14:0],mosi};
assign shift_cmd_next = (cmd_bit==3'd7)?  shift_i_next[7:0]:8'd0;

always_ff@(posedge sck or negedge csn_rstn) begin
    if(~csn_rstn)
        wr_flag <= 1'b0;
    else if(shift_cmd_next==CMD_WRITE)
        wr_flag <= 1'b1;
end

always_ff@(posedge sck or negedge csn_rstn) begin
    if(~csn_rstn)
        rd_flag <= 1'b0;
    else if(shift_cmd_next==CMD_READ)
        rd_flag <= 1'b1;
end

logic [3:0] bit_cnt;
always_ff@(posedge sck or negedge csn_rstn) begin
    if(~csn_rstn)
        bit_cnt <= 4'd0;
    else if(rd_flag || wr_flag)
        bit_cnt <= bit_cnt+1'b1;
end
logic [1:0] addr_data_flag; //1:addr, 2:len, 3:data
always_ff@(posedge sck or negedge csn_rstn) begin
    if(~csn_rstn)
        addr_data_flag <= 1'b0;
    //else if((shift_cmd_next==CMD_READ || shift_cmd_next==CMD_WRITE) && (addr_data_flag==2'd0))
    //    addr_data_flag <= 2'd1;
    else if(wr_flag && (bit_cnt==4'd15))
        addr_data_flag <= addr_data_flag[1]?  2'd2:(addr_data_flag+1'b1);
end
//logic [15:0] addr;
//logic [15:0] data;
always_ff@(posedge sck or negedge rstn) begin
    if(~rstn)
        addr <= 16'd0;
    else if((addr_data_flag==2'd0) && (bit_cnt==4'd15))
        addr <= shift_i_next;
end
assign addr_load = (wr_flag && (addr_data_flag==2'd0) && (bit_cnt==4'd15));    // for addr latch in w&r

assign wdata = shift_i;
assign data_load = (wr_flag && (addr_data_flag==2'd2) && (bit_cnt==4'd15));    // for load write data

assign read_load = (rd_flag && addr_data_flag==2'd0 && bit_cnt==4'd0);

always_ff@(posedge sck_inv or negedge csn_rstn) begin
    if(~csn_rstn)
        shift_o <= 16'd0;
    else if(read_load) // latch rdata done 
        shift_o <= rdata;
    else
        shift_o <= {shift_o[14:0],1'b0};
end
assign miso = shift_o[15];

endmodule