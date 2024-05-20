package test_pkg;

import uvm_pkg::*;		


`include "uvm_macros.svh"
`include "define.sv"



class ahb_master_item extends uvm_sequence_item;

rand bit lock;
rand bit write;
rand bit [31:0] addr;
rand bit [2:0] burst;
rand bit [2:0] dsize;
rand bit [3:0] prot;
rand bit [31:0] wdata[];
rand bit [7:0] length;
rand int delay;
rand bit busreq;
bit [1:0] resp;
bit [31:0] rdata[];

constraint lock_c {}
constraint write_c {write dist {0 := 50, 1 := 50};}
constraint addr_c {addr[1:0] == 2'b00;
					addr[31:30] == 2'b00;
					addr[29:28] == 2'b00;
					addr[27:12] == 16'd0;}
constraint burst_c {}
constraint dsize_c {dsize == 3'b010;}
constraint prot_c {prot == 4'b0001;}
constraint length_c {(burst == `SINGLE) -> (length == 1);
						(burst == `INCR) -> ((length <= 20) && (length >= 18));
						((burst == `INCR4) || (burst == `WRAP4)) -> (length == 4);
						((burst == `INCR8) || (burst == `WRAP8)) -> (length == 8);
						((burst == `INCR16) || (burst == `WRAP16)) -> (length == 16); }
												
constraint wdata_c {wdata.size == length;}

constraint order_c {solve burst before length;
					solve length before wdata;}

constraint delay_c { delay inside {[0:0]};}					

`uvm_object_utils_begin(ahb_master_item)
	`uvm_field_int(lock, UVM_ALL_ON)
	`uvm_field_int(write, UVM_ALL_ON)
	`uvm_field_int(addr, UVM_ALL_ON)
	`uvm_field_int(burst, UVM_ALL_ON)
	`uvm_field_int(dsize, UVM_ALL_ON)
	`uvm_field_int(prot, UVM_ALL_ON)
	`uvm_field_array_int(wdata, UVM_ALL_ON)
	`uvm_field_int(length, UVM_ALL_ON)
	`uvm_field_int(delay, UVM_ALL_ON)
	`uvm_field_int(busreq, UVM_ALL_ON)
	`uvm_field_int(resp, UVM_ALL_ON)
	`uvm_field_array_int(rdata, UVM_ALL_ON)
`uvm_object_utils_end

function new(string name = "ahb_master_item");
	super.new(name);
	
endfunction : new	
	
endclass : ahb_master_item


class ahb_master_sequence_base extends uvm_sequence #(ahb_master_item);
`uvm_object_utils(ahb_master_sequence_base)

function new(string name = "ahb_master_sequence_base");
	super.new(name);
endfunction : new

virtual task pre_body();
	if(starting_phase != null)
		starting_phase.raise_objection(this);		
endtask : pre_body	

virtual task body();
endtask : body

virtual task post_body();
	if(starting_phase != null)
		starting_phase.drop_objection(this);
endtask : post_body

endclass : ahb_master_sequence_base


class test_for_base_transfer extends ahb_master_sequence_base;
`uvm_object_utils(test_for_base_transfer)

ahb_master_item req;
function new(string name = "test_for_base_transfer");
	super.new(name);
endfunction : new

virtual task body();
fork
begin
repeat(100)
		begin//fork
				
				req = ahb_master_item::type_id::create("req");
	//			start_item(req);
				assert(req.randomize() with {
					lock == 0;
					busreq == 1;
					});
	//			req.print;	
				start_item(req);

				finish_item(req);
				req.print;
		end//join_none
end


		#5us;
join_any;

	
		
endtask : body

endclass : test_for_base_transfer



class ahb_master_sequencer extends uvm_sequencer #(ahb_master_item);
`uvm_component_utils(ahb_master_sequencer)

function new(string name, uvm_component parent);
	super.new(name, parent);
endfunction : new

function void build_phase(uvm_phase phase);
	super.build_phase(phase);
endfunction : build_phase	

endclass : ahb_master_sequencer

class ahb_master_driver extends uvm_driver #(ahb_master_item);
`uvm_component_utils(ahb_master_driver)

virtual m_if ahb_if; 
ahb_master_item req, req2;
semaphore phase_lock = new(1);
semaphore phase_lock2 = new(1);
semaphore transaction_lock = new(1);
int num, num2;
int offset, offset2;
	
function new(string name, uvm_component parent);
	super.new(name, parent);
endfunction : new


task beat_pipeline();
forever 
	begin
		phase_lock.get();
		if(offset == req.length)
			begin
				phase_lock.put();
				break;
			end	
	
		while(!ahb_if.HREADY)
			@(posedge ahb_if.HCLK);
		ahb_if.HADDR <= req.addr + offset*req.dsize;
		if(offset == 0)
			ahb_if.HTRANS <= `NONSEQ;
		else 
			ahb_if.HTRANS <= `SEQ;
		@(posedge ahb_if.HCLK);
		offset ++;
		if(offset == req.length)
			transaction_lock.put();
		phase_lock.put();
		while(!ahb_if.HREADY)
			@(posedge ahb_if.HCLK);
		if(req.write)
			ahb_if.HWDATA <= req.wdata[num];
		@(negedge ahb_if.HCLK);
		req.rdata[num] = ahb_if.HRDATA;
		num ++;
		if(num == req.length)
			begin
				seq_item_port.put(req);
				break;
			end	
	end	
endtask : beat_pipeline



task transfer_pipeline();
	
forever 
	begin
		transaction_lock.get();
		seq_item_port.try_next_item(req);
		if(req != null)
			begin
				seq_item_port.item_done();

				num = 0;
				offset = 0;
				repeat(req.delay) 
					begin
						ahb_if.HTRANS = `IDLE;	
						@(posedge ahb_if.HCLK);
					end	
				ahb_if.HLOCK <= req.lock;
				if(!ahb_if.HGRANT)
					ahb_if.HBUSREQ <= 1;
				while(!(ahb_if.HGRANT && ahb_if.HREADY))
					begin
						ahb_if.HTRANS = `IDLE;	
						@(posedge ahb_if.HCLK);
					end	
				ahb_if.HBUSREQ <= req.busreq;
				ahb_if.HWRITE <= req.write;
				ahb_if.HSIZE <= req.dsize;
				ahb_if.HBURST <= req.burst;
				ahb_if.HPROT <= req.prot;	
				fork
					beat_pipeline();
					beat_pipeline();
				join	
			end
		else 
			begin
				ahb_if.HTRANS = `IDLE;
				@(posedge ahb_if.HCLK);
			end	
	end		

endtask : transfer_pipeline


task beat_pipeline2();
forever 
	begin
		phase_lock2.get();
		if(offset2 == req2.length)
		begin
			phase_lock2.put();
			break;
		end	
		while(!ahb_if.HREADY)
			@(posedge ahb_if.HCLK);
		ahb_if.HADDR <= req2.addr + offset2*req2.dsize;
		if(offset2 == 0)
			ahb_if.HTRANS <= `NONSEQ;
		else 
			ahb_if.HTRANS <= `SEQ;
		@(posedge ahb_if.HCLK);
		offset2 ++;
		if(offset2 == req2.length)
			transaction_lock.put();
		phase_lock2.put();
		while(!ahb_if.HREADY)
			@(posedge ahb_if.HCLK);
		if(req2.write)
			ahb_if.HWDATA <= req2.wdata[num2];
		@(negedge ahb_if.HCLK);
		req2.rdata[num2] = ahb_if.HRDATA;
		num2 ++;
		if(num2 == req2.length)
			begin
				seq_item_port.put(req2);
			break;
	end	
end	

endtask : beat_pipeline2



task transfer_pipeline2();
	
forever 
	begin
		transaction_lock.get();
		seq_item_port.try_next_item(req2);
		if(req2 != null)
			begin
				seq_item_port.item_done();

				num2 = 0;
				offset2 = 0;
				repeat(req2.delay) 
					begin
						ahb_if.HTRANS = `IDLE;	
						@(posedge ahb_if.HCLK);
					end	
				ahb_if.HLOCK <= req2.lock;
				if(!ahb_if.HGRANT)
					ahb_if.HBUSREQ <= 1;
				while(!(ahb_if.HGRANT && ahb_if.HREADY))
					begin
						ahb_if.HTRANS = `IDLE;	
						@(posedge ahb_if.HCLK);
					end	
				ahb_if.HBUSREQ <= req2.busreq;
				ahb_if.HWRITE <= req2.write;
				ahb_if.HSIZE <= req2.dsize;
				ahb_if.HBURST <= req2.burst;
				ahb_if.HPROT <= req2.prot;	
				fork
					beat_pipeline2();
					beat_pipeline2();
				join	
			end
		else 
			begin
				ahb_if.HTRANS = `IDLE;
				@(posedge ahb_if.HCLK);
			end	
	end		

endtask : transfer_pipeline2



virtual task run_phase(uvm_phase phase);

ahb_if.HBUSREQ <= 0;
ahb_if.HLOCK <= 0;
ahb_if.HTRANS <= `IDLE;
ahb_if.HADDR <= 0;
ahb_if.HWRITE <= 0;
ahb_if.HSIZE <= 3'b010;	
ahb_if.HBURST <= `SINGLE;
ahb_if.HPROT <= 4'b0001;
ahb_if.HWDATA <= 0;

@(posedge ahb_if.HRESETn);	
@(posedge ahb_if.HCLK);

fork
	transfer_pipeline();
	transfer_pipeline2();
join
			
endtask : run_phase

endclass : ahb_master_driver


class ahb_master_monitor extends uvm_monitor;
`uvm_component_utils(ahb_master_monitor)
	
function new(string name, uvm_component parent);
	super.new(name, parent);
endfunction : new


endclass : ahb_master_monitor


class ahb_master_agent extends uvm_agent;
`uvm_component_utils(ahb_master_agent)

ahb_master_sequencer m_seqr;
ahb_master_driver m_drvr;
ahb_master_monitor m_mont;
virtual m_if ahb_if;

function new(string name, uvm_component parent);
	super.new(name, parent);
endfunction : new

function void build_phase(uvm_phase phase);
	m_seqr = ahb_master_sequencer::type_id::create("m_seqr", this);
	m_drvr = ahb_master_driver::type_id::create("m_drvr", this);
	m_mont = ahb_master_monitor::type_id::create("m_mont", this);
endfunction : build_phase

function void connect_phase(uvm_phase phase);
	if(! uvm_config_db #(virtual m_if)::get(this, "", "ahb_if", ahb_if))
		uvm_report_info("AHB_ERROR", "ahb agent cannot get the ahb_if", UVM_LOW);
	m_drvr.ahb_if = ahb_if;
	m_drvr.seq_item_port.connect(m_seqr.seq_item_export);
endfunction : connect_phase

endclass : ahb_master_agent




class ahb_master_env extends uvm_env;
`uvm_component_utils(ahb_master_env)

ahb_master_agent m_agent[];
virtual m_if ahb_if[];
int m_num;

function new(string name, uvm_component parent);
	super.new(name, parent);
endfunction : new

function void build_phase(uvm_phase phase);
	if(!uvm_config_db #(int)::get(this, "", "master_num", m_num))
		uvm_report_info("AHB_ERROR", "ahb agent num cannot get", UVM_LOW);
		
	m_agent = new[m_num];
	ahb_if = new[m_num];
	foreach(m_agent[aa])
		begin
			//string name = $psprintf("m_agent[%d]", aa);
			//string vif_name = $psprintf("m_if[%d]", aa); 
			if(!uvm_config_db #(virtual m_if)::get(this, "", "m_if[0]", ahb_if[aa]))
				uvm_report_info("AHB_ERROR", "ahb m_if cannot get", UVM_LOW);	
			uvm_config_db #(virtual m_if)::set(this, "m_agent[0]", "ahb_if", ahb_if[aa]);		
			m_agent[aa] = ahb_master_agent::type_id::create("m_agent[0]", this);
		end
endfunction : build_phase

function void connect_phase(uvm_phase phase);

endfunction : connect_phase

endclass : ahb_master_env




class ahb_master_test extends uvm_test;
`uvm_component_utils(ahb_master_test)

ahb_master_env m_env;
uvm_table_printer printer;

function new(string name = "ahb_master_test", uvm_component parent = null);
	super.new(name, parent);
endfunction	

function void build_phase(uvm_phase phase);
	uvm_config_db #(int)::set(this, "m_env", "master_num", 1);
	uvm_config_db #(uvm_object_wrapper)::set(this, "m_env.m_agent[0].m_seqr.run_phase", "default_sequence",
											test_for_base_transfer::type_id::get());										
	m_env = ahb_master_env::type_id::create("m_env", this);
endfunction : build_phase

 function void end_of_elaboration_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      $psprintf("Printing the test topology :\n%s", this.sprint(printer)), UVM_LOW)
  endfunction : end_of_elaboration_phase


endclass : ahb_master_test


endpackage : test_pkg
		
	




