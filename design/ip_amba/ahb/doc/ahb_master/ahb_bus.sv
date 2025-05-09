
interface m_if(input HCLK, input HRESETn);
	//input for AHB master
	logic 			HGRANT;
	logic 			HREADY;
	logic [1:0] 	HRESP;
	logic [31:0]	HRDATA;
	//output for AHB master
	logic 			HBUSREQ;
	logic 			HLOCK;
	logic [1:0]		HTRANS;
	logic [31:0] 	HADDR;
	logic 			HWRITE;
	logic [2:0] 	HSIZE;
	logic [2:0] 	HBURST;
	logic [3:0] 	HPROT;
	logic [31:0] 	HWDATA;

endinterface : m_if

interface s_if(input HCLK, input HRESETn);
	//input for AHB slave
	logic 			HSEL;
	logic [31:0] 	HADDR;
	logic [31:0] 	HWDATA;
	logic 			HWRITE;
	logic [1:0] 	HTRANS;
	logic [2:0] 	HSIZE;
	logic [2:0] 	HBURST;
	logic [3:0] 	HMASTER;
	logic [3:0] 	HPROT;
	logic 			HMASTERLOCK;
	//output for AHB slave
	logic 			HREADY;
	logic [1:0] 	HRESP;
	logic [31:0] 	HRDATA;
	logic [15:0] 	HSPLIT;
endinterface :s_if	




module ahb_bus(input HCLK, input HRESETn, m_if master_if[0:15], s_if slave_if[0:15]);
	
parameter IDLE = 2'b00, BUSY = 2'b01, NONSEQ = 2'b10, SEQ = 2'b11;
parameter SINGLE = 3'b000, INCR = 3'b001, WRAP4 = 3'b010, INCR4 = 3'b011, WRAP8 = 3'b100, 
			INCR8 = 3'b101, WRAP16 = 3'b110, INCR16 = 3'b111;
parameter OKAY = 2'b00, ERROR = 2'b01, RETRY = 2'b10, SPLIT = 2'b11;

virtual m_if master[0:15];
virtual s_if slave[0:15];

int grant_id;
reg lock_or;
reg lock_or_r;
wire lock_detect_n;
reg [3:0] HMASTER;
reg HMASTERLOCK;
reg [1:0] HTRANS;
reg [31:0] HADDR;
reg HWRITE;
reg [2:0] HSIZE;
reg [2:0] HBURST;
reg [3:0] HPROT;
reg [3:0] burst_count;
reg grant_enable;
wire [3:0] slave_sel;
reg [15:0] HSEL;
reg [3:0] data_mux;
reg [31:0] HWDATA;
reg [31:0] HRDATA;
reg [1:0] HRESP;
reg HREADY;
wire [15:0] HSPLIT;
reg mask[16];
reg [15:0] split_or;

initial 
begin
	master[0:15] = master_if[0:15];
	slave[0:15] = slave_if[0:15];
end	


always @(*)
begin
	for(int i=15; i>=0; i--) 
		if((master[i].HBUSREQ & mask[i]) == 1)
			grant_id = i;
end			

always @(*)
if(grant_enable) 
begin
	foreach(master[aa])
		master[aa].HGRANT = 0;

	master[grant_id].HGRANT = 1;
end
else 
begin
	foreach(master[aa])
		master[aa].HGRANT = master[aa].HGRANT;
end

always @(*)		
begin
	lock_or = 0;
	foreach(master[aa])
		lock_or = master[aa].HLOCK | lock_or;
end		

always @(posedge HCLK or negedge HRESETn)
if(!HRESETn)
	lock_or_r = 0;
else 
	lock_or_r <= lock_or;

assign lock_detect_n = lock_or & lock_or_r;


always @(posedge HCLK or negedge HRESETn)
if(!HRESETn)
	HMASTER <= 4'd16;
else if(grant_enable && (!lock_detect_n))
	HMASTER <= grant_id;
else
	HMASTER <= HMASTER;

always @(*)
begin
	if(lock_or && ((HTRANS == NONSEQ) || (HTRANS == BUSY) || (HTRANS == SEQ)))
		HMASTERLOCK = 1;
end		
			

always @(*)
begin
	HTRANS = master[HMASTER].HTRANS;
	HADDR = master[HMASTER].HADDR;
	HWRITE = master[HMASTER].HWRITE;
	HSIZE = master[HMASTER].HSIZE;
	HBURST = master[HMASTER].HBURST;
	HPROT = master[HMASTER].HPROT;
end

always @(posedge HCLK or negedge HRESETn)
if(!HRESETn)
	burst_count <= 4'd0;
else
begin
	if((HTRANS == NONSEQ) && (HREADY == 1))
		burst_count <= 4'd1;
	else if((HTRANS == SEQ) && (HREADY == 1))
		burst_count <= burst_count + 1;
	else
		burst_count <= burst_count;
		
end


always @(*)
begin
	if((HTRANS == IDLE) && (HREADY == 1))
		grant_enable = 1;
	else if((HTRANS == NONSEQ) && (HBURST == SINGLE) && (HREADY == 1))
		grant_enable = 1;
	else if((burst_count == 3) && ((HBURST == INCR4) || (HBURST == WRAP4)) && (HREADY == 1))
		grant_enable = 1;
	else if((burst_count == 7) && ((HBURST == INCR8) || (HBURST == WRAP8)) && (HREADY == 1))
		grant_enable = 1;
	else if((burst_count == 15) && ((HBURST == INCR16) || (HBURST == WRAP16)) && (HREADY == 1))
		grant_enable = 1;
	else 
		grant_enable = 0;
end		

assign slave_sel = HADDR[31:28];		

always @(*)
begin
	foreach(HSEL[aa])
		HSEL[aa] = 0;
	if(HREADY == 1)
		HSEL[slave_sel] = 1;
end		

always @(posedge HCLK or negedge HRESETn)
if(!HRESETn)
	data_mux <= 0;
else if(HREADY == 1)
	data_mux <= slave_sel;
else 
	data_mux <= data_mux;

always @(*)
begin
	HWDATA = master[data_mux].HWDATA;
	HRDATA = slave[data_mux].HRDATA;
	HREADY = slave[data_mux].HREADY;
	HRESP = slave[data_mux].HRESP;
end	

/*	
assign HWDATA = master[data_mux].HWDATA;
assign HRDATA = slave[data_mux].HRDATA;
assign HREADY = slave[data_mux].HREADY;
assign HRESP = slave[data_mux].HRESP;
*/

always @(*)
begin
	HSPLIT = {slave[15].HSPLIT, slave[14].HSPLIT, slave[13].HSPLIT, slave[12].HSPLIT, slave[11].HSPLIT, slave[10].HSPLIT, slave[9].HSPLIT, 
				slave[8].HSPLIT, slave[7].HSPLIT, slave[6].HSPLIT, slave[5].HSPLIT, slave[4].HSPLIT, slave[3].HSPLIT, slave[2].HSPLIT,
				slave[1].HSPLIT, slave[0].HSPLIT};
end
		
always @(posedge HCLK or negedge HRESETn)
if(!HRESETn)
	foreach(mask[aa])
		mask[aa] <= 1;
else if((HRESP == SPLIT) && (HREADY == 1))
	mask[data_mux] <= 0;
else if(HSPLIT)
	foreach(mask[aa])
		if(HSPLIT[aa] == 1)
			mask[aa] = 1;
else 
	foreach(mask[aa])
		mask[aa] <= mask[aa];


always @(*)
begin
	foreach(slave[aa]) 
		begin
			slave[aa].HSEL = HSEL[aa];	
			slave[aa].HADDR = HADDR;
			slave[aa].HWDATA = HWDATA;
			slave[aa].HWRITE = HWRITE;
			slave[aa].HTRANS = HTRANS;
			slave[aa].HBURST = HBURST;
			slave[aa].HSIZE = HSIZE;
			slave[aa].HPROT = HPROT;
			slave[aa].HADDR = HADDR;
			slave[aa].HMASTERLOCK = HMASTERLOCK;
		end	
end

always @(*)
begin
	foreach(master[aa])
		begin
			master[aa].HREADY = HREADY;
			master[aa].HRESP = HRESP;
			master[aa].HRDATA = HRDATA;
		end
end		


always @(*)
begin
	split_or = 15'd0;		

	foreach(slave[aa])
		split_or = split_or | slave[aa].HSPLIT;
end		

assign HSPLIT = split_or;


endmodule : ahb_bus


		
			
