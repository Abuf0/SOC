`timescale 1ns/1ns

module top();

import uvm_pkg::*;
import test_pkg::*;

`include "uvm_macros.svh"
`include "bus_if.sv"
	

bit clk;
bit rstn;
m_if master_if(clk, rstn);
s_if slave_if(clk, rstn);


ahb bus0 (
				.clk(clk),
				.rst_n(rstn),

				.mgrant0(master_if.HGRANT),
				.mready0(master_if.HREADY),
				.mresp0(master_if.HRESP),
				.mrdata0(master_if.HRDATA),
				.mbusreq0(master_if.HBUSREQ),
				.mlock0(master_if.HLOCK),
				.mtrans0(master_if.HTRANS),
				.maddr0(master_if.HADDR),
				.mwrite0(master_if.HWRITE),
				.msize0(master_if.HSIZE),
				.mburst0(master_if.HBURST),
				.mprot0(master_if.HPROT),
				.mwdata0(master_if.HWDATA),

				.mbusreq1(1'b0),
				.mlock1(1'b0),
				.mbusreq2(1'b0),
				.mlock2(1'b0),
				.mbusreq3(1'b1),
				.mtrans3(2'b00),
				.mlock3(1'b0),


				.ssel0(slave_if.HSEL),
				.saddr0(slave_if.HADDR),
				.swdata0(slave_if.HWDATA),
				.swrite0(slave_if.HWRITE),
				.strans0(slave_if.HTRANS),
				.ssize0(slave_if.HSIZE),
				.sburst0(slave_if.HBURST),
				.smaster0(slave_if.HMASTER),
				.sprot0(slave_if.HPROT),
				.smasterlock0(slave_if.HMASTERLOCK),
				.sready0(slave_if.HREADY),
				.sresp0(slave_if.HRESP),
				.srdata0(slave_if.HRDATA),
				.ssplit0(slave_if.HSPLIT),
				.ssplit1(16'd0),
				.ssplit2(16'd0),
				.ssplit3(16'd0)

			);


mem mem0 (
			.HCLK(clk),
			.HRESETn(rstn),
			.slave(slave_if)
		);





/*initial 
	begin		
		uvm_config_db #(virtual m_if)::set(null, "*.m_env", "m_if[0]", master_if);
//		uvm_config_db #(virtual m_if)::set(null, "*.m_env", "m_if[1]", my_m_if[1]);
//		uvm_config_db #(virtual m_if)::set(null, "*.m_env", "m_if[2]", my_m_if[2]);
//		uvm_config_db #(virtual m_if)::set(null, "*.m_env", "m_if[3]", my_m_if[3]);
	end	
*/
		

initial 
	begin
		clk = 0;
		forever 
			#5 clk = ~clk;   //100M
	end

initial 
	begin
		rstn = 0;
		#200 rstn = 1;
	end	

initial 
	begin
		$fsdbDumpfile("dump.fsdb");
		$fsdbDumpvars(0, top);
	end	

initial 
	begin
		uvm_config_db #(virtual m_if)::set(null, "*.m_env", "m_if[0]", master_if);
		run_test();
	end	


endmodule



				
