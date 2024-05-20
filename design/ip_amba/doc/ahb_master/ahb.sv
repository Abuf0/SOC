
module ahb( 	clk , rst_n,
				mgrant0, mready0, mresp0, mrdata0, mbusreq0, mlock0, mtrans0, maddr0, mwrite0, msize0, mburst0, mprot0, mwdata0,
				mgrant1, mready1, mresp1, mrdata1, mbusreq1, mlock1, mtrans1, maddr1, mwrite1, msize1, mburst1, mprot1, mwdata1,
				mgrant2, mready2, mresp2, mrdata2, mbusreq2, mlock2, mtrans2, maddr2, mwrite2, msize2, mburst2, mprot2, mwdata2,
				mgrant3, mready3, mresp3, mrdata3, mbusreq3, mlock3, mtrans3, maddr3, mwrite3, msize3, mburst3, mprot3, mwdata3,
				ssel0, saddr0, swdata0, swrite0, strans0, ssize0, sburst0, smaster0, sprot0, smasterlock0, sready0, sresp0, srdata0, ssplit0,
				ssel1, saddr1, swdata1, swrite1, strans1, ssize1, sburst1, smaster1, sprot1, smasterlock1, sready1, sresp1, srdata1, ssplit1,
				ssel2, saddr2, swdata2, swrite2, strans2, ssize2, sburst2, smaster2, sprot2, smasterlock2, sready2, sresp2, srdata2, ssplit2,
				ssel3, saddr3, swdata3, swrite3, strans3, ssize3, sburst3, smaster3, sprot3, smasterlock3, sready3, sresp3, srdata3, ssplit3
				);
	
parameter IDLE = 2'b00, BUSY = 2'b01, NONSEQ = 2'b10, SEQ = 2'b11;
parameter SINGLE = 3'b000, INCR = 3'b001, WRAP4 = 3'b010, INCR4 = 3'b011, WRAP8 = 3'b100, 
			INCR8 = 3'b101, WRAP16 = 3'b110, INCR16 = 3'b111;
parameter OKAY = 2'b00, ERROR = 2'b01, RETRY = 2'b10, SPLIT = 2'b11;

input clk, rst_n;
//master list
output mgrant0, mgrant1, mgrant2, mgrant3;
output mready0, mready1, mready2, mready3;
output [1:0] mresp0, mresp1, mresp2, mresp3;
output [31:0] mrdata0, mrdata1, mrdata2, mrdata3;
input mbusreq0, mbusreq1, mbusreq2, mbusreq3;
input mlock0, mlock1, mlock2, mlock3;
input [1:0] mtrans0, mtrans1, mtrans2, mtrans3;
input [31:0] maddr0, maddr1, maddr2, maddr3;
input mwrite0, mwrite1, mwrite2, mwrite3;
input [2:0] msize0, msize1, msize2, msize3;
input [2:0] mburst0, mburst1, mburst2, mburst3;
input [3:0] mprot0, mprot1,mprot2, mprot3;
input [31:0] mwdata0, mwdata1, mwdata2, mwdata3;

//slave list
output ssel0, ssel1, ssel2, ssel3;
output [31:0] saddr0, saddr1, saddr2, saddr3;
output [31:0] swdata0, swdata1, swdata2, swdata3;
output swrite0, swrite1, swrite2, swrite3;
output [1:0] strans0, strans1, strans2, strans3;
output [2:0] ssize0, ssize1, ssize2, ssize3;
output [2:0] sburst0, sburst1, sburst2, sburst3;
output [3:0] smaster0, smaster1, smaster2, smaster3;
output [3:0] sprot0, sprot1, sprot2, sprot3;
output smasterlock0, smasterlock1, smasterlock2, smasterlock3;
input sready0, sready1, sready2, sready3;
input [1:0] sresp0, sresp1, sresp2, sresp3;
input [31:0] srdata0, srdata1, srdata2, srdata3;
input [15:0] ssplit0, ssplit1, ssplit2, ssplit3;

reg mgrant0, mgrant1, mgrant2, mgrant3;


reg [3:0] grant_id;
wire lock_or;
reg lock_or_r;
wire lock_detect_n;
reg [3:0] hmaster;
reg [3:0] hmaster_r;
wire hmasterlock;
wire [1:0] htrans;
wire [31:0] haddr;
wire hwrite;
wire [2:0] hsize;
wire [2:0] hburst;
wire [3:0] hprot;
reg [3:0] burst_count;
reg grant_enable;
wire [3:0] slave_sel;
wire [3:0] hsel;
reg [3:0] data_mux;
wire [31:0] hwdata;
reg [31:0] hrdata;
reg [1:0] hresp;
reg hready;
wire [15:0] hsplit;
reg [15:0] mask;
reg [15:0] split_or;
reg [3:0] grant_id_r;


always @(*)
if(grant_enable)
begin
	if(mbusreq0 && mask[0])
		grant_id = 4'd0;
	else if(mbusreq1 && mask[1])
		grant_id = 4'd1;
	else if(mbusreq2 && mask[2])
		grant_id = 4'd2;
	else if(mbusreq3 && mask[3])
		grant_id = 4'd3;
	else 
		grant_id = 4'd3;		
end		
else 
	grant_id = grant_id_r;

always @(posedge clk or negedge rst_n)
if(!rst_n)
	grant_id_r <= 4'd3;
else if(grant_enable)
	grant_id_r <= grant_id;
else 
	grant_id_r <= grant_id_r;
	

always @(*)
begin
	if(grant_id == 4'd0)
		{mgrant0, mgrant1, mgrant2, mgrant3} = 4'b1000;
	else if(grant_id == 4'd1)
		{mgrant0, mgrant1, mgrant2, mgrant3} = 4'b0100;
	else if(grant_id == 4'd2)
		{mgrant0, mgrant1, mgrant2, mgrant3} = 4'b0010;
	else 
		{mgrant0, mgrant1, mgrant2, mgrant3} = 4'b0001;
end
	

assign lock_or = mlock0 | mlock1 | mlock2 | mlock3;


always @(posedge clk or negedge rst_n)
if(!rst_n)
	lock_or_r = 0;
else 
	lock_or_r <= lock_or;

assign lock_detect_n = lock_or & lock_or_r;


always @(posedge clk or negedge rst_n)
if(!rst_n)
	hmaster <= 4'd3;
else if(grant_enable && (!lock_detect_n))
	hmaster <= grant_id;
else
	hmaster <= hmaster;

always @(posedge clk or negedge rst_n)
if(!rst_n)
	hmaster_r = 4'd0;
else if(hready)
	hmaster_r <= hmaster;
else 
	hmaster_r <= hmaster_r;


assign hmasterlock = lock_or && ((htrans == NONSEQ) || (htrans == BUSY) || (htrans == SEQ));	

assign htrans = (hmaster==4'd0) ? mtrans0:( (hmaster==4'd1) ? mtrans1:( (hmaster==4'd2) ? mtrans2:( (hmaster==4'd3) ? mtrans3 : mtrans3 )));
assign haddr = (hmaster==4'd0) ? maddr0:( (hmaster==4'd1) ? maddr1:( (hmaster==4'd2) ? maddr2:( (hmaster==4'd3) ? maddr3 : maddr3 )));
assign hwrite = (hmaster==4'd0) ? mwrite0:( (hmaster==4'd1) ? mwrite1:( (hmaster==4'd2) ? mwrite2:( (hmaster==4'd3) ? mwrite3 : mwrite3 )));
assign hsize = (hmaster==4'd0) ? msize0:( (hmaster==4'd1) ? msize1:( (hmaster==4'd2) ? msize2:( (hmaster==4'd3) ? msize3 : msize3 )));
assign hburst = (hmaster==4'd0) ? mburst0:( (hmaster==4'd1) ? mburst1:( (hmaster==4'd2) ? mburst2:( (hmaster==4'd3) ? mburst3 : mburst3 )));
assign hprot = (hmaster==4'd0) ? mprot0:( (hmaster==4'd1) ? mprot1:( (hmaster==4'd2) ? mprot2:( (hmaster==4'd3) ? mprot3 : mprot3 )));
assign hwdata = (hmaster_r==4'd0) ? mwdata0:( (hmaster_r==4'd1) ? mwdata1:( (hmaster_r==4'd2) ? mwdata2:( (hmaster_r==4'd3) ? mwdata3 : mwdata3 )));



always @(posedge clk or negedge rst_n)
if(!rst_n)
	burst_count <= 4'd0;
else
begin
	if((htrans == NONSEQ) && (hready == 1))
		burst_count <= 4'd1;
	else if((htrans == SEQ) && (hready == 1))
		burst_count <= burst_count + 1;
	else
		burst_count <= burst_count;
		
end


always @(*)
begin
	if((htrans == IDLE) && (hready == 1))
		grant_enable = 1;
	else if((htrans == NONSEQ) && (hburst == SINGLE) && (hready == 1))
		grant_enable = 1;
	else if((burst_count == 3) && ((hburst == INCR4) || (hburst == WRAP4)) && (hready == 1))
		grant_enable = 1;
	else if((burst_count == 7) && ((hburst == INCR8) || (hburst == WRAP8)) && (hready == 1))
		grant_enable = 1;
	else if((burst_count == 15) && ((hburst == INCR16) || (hburst == WRAP16)) && (hready == 1))
		grant_enable = 1;
	else 
		grant_enable = 0;
end		

assign slave_sel = haddr[31:28];		

assign hsel = (htrans == IDLE) ? 4'b0000 : ((slave_sel == 4'd0)? 4'b0001: ((slave_sel == 4'd1)? 4'b0010: 
				((slave_sel == 4'd2)? 4'b0100: ((slave_sel == 4'd3)? 4'b1000:4'b0000))));

always @(posedge clk or negedge rst_n)
if(!rst_n)
	data_mux <= 0;
else if((hready == 1) && (htrans != IDLE))
	data_mux <= slave_sel;
else 
	data_mux <= data_mux;

always @(*)
begin
	if(data_mux == 4'd0)
		{hrdata, hready, hresp} = {srdata0, sready0, sresp0};
	else if(data_mux == 4'd1)
		{hrdata, hready, hresp} = {srdata1, sready1, sresp1};
	else if(data_mux == 4'd2)
		{hrdata, hready, hresp} = {srdata2, sready2, sresp2};
	else 
		{hrdata, hready, hresp} = {srdata3, sready3, sresp3};
end	

assign hsplit = ssplit0 | ssplit1 | ssplit2 | ssplit3;
		

always @(posedge clk or negedge rst_n)
if(!rst_n)
	mask <= 4'b1111;
else if((hresp == SPLIT) &&	(hready == 1))
	mask[data_mux] = 1'b1;
else if(hsplit)
	mask <= mask & (~hsplit);
else 
	mask <= mask;

assign {ssel3, ssel2, ssel1, ssel0} = hsel;
assign {saddr0, saddr1, saddr2, saddr3} = {4{haddr}};
assign {swdata0, swdata1, swdata2, swdata3} = {4{hwdata}};
assign {swrite0, swrite1, swrite2, swrite3} = {4{hwrite}};
assign {strans0, strans1, strans2, strans3} = {4{htrans}};
assign {sburst0, sburst1, sburst2, sburst3} = {4{hburst}};
assign {ssize0, ssize1, ssize2, ssize3} = {4{hsize}};
assign {sprot0, sprot1, sprot2, sprot3} = {4{hprot}};
assign {saddr0, saddr1, saddr2, saddr3} = {4{haddr}};
assign {smaster0, smaster1, smaster2, smaster3} = {4{hmaster}};
assign {smasterlock0, smasterlock1, smasterlock2, smasterlock3} = {4{hmasterlock}}; 

assign {mready0, mready1, mready2, mready3} = {4{hready}};
assign {mresp0, mresp1, mresp2, mresp3} = {4{hresp}};
assign {mrdata0, mrdata1, mrdta2, mrdata3} = {4{hrdata}};


endmodule


		
			
