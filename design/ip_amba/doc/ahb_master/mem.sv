module mem(input HCLK, input HRESETn, s_if slave);

parameter IDLE = 2'b00, BUSY = 2'b01, NONSEQ = 2'b10, SEQ = 2'b11; 
parameter OKAY = 2'b00, ERROR = 2'b01, RETRY = 2'b10, SPLIT = 2'b11; 

int addr;

bit [31:0] m_mem[bit[9:0]] = '{default:0};

initial 
	begin
			begin
				slave.HREADY <= 1;
				slave.HRESP <= OKAY;
				slave.HSPLIT <= 0;
				slave.HRDATA <= 0;
			end	
		@(posedge HRESETn); 
			begin
				forever 
					begin
						while(!(slave.HSEL && slave.HREADY && (slave.HTRANS == NONSEQ)))
							@(posedge HCLK);
						addr = slave.HADDR[11:2];
						if(slave.HWRITE == 0)
							slave.HRDATA <= m_mem[addr];
						else 
							begin	
								@(negedge HCLK);
								m_mem[addr] = slave.HWDATA;
							end	

						while(!(slave.HTRANS == IDLE))
							begin
								if(!(slave.HSEL && slave.HREADY && (slave.HTRANS == SEQ)))
									@(posedge HCLK);
								addr = slave.HADDR[11:2];	
								if(slave.HWRITE == 0)
									slave.HRDATA <= m_mem[addr];
								else 
									begin	
										@(negedge HCLK);
										m_mem[addr] = slave.HWDATA;
									end	
								@(posedge HCLK);
							end	
					end
			end
	end

endmodule	

									
								


			

