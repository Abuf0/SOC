UVM_HOME = ../../uvm

all:compile simulation
	
compile:
	vlib work
	vlog -sgq 4g\
		-work work \
		+incdir+$(UVM_HOME)/src $(UVM_HOME)/src/uvm_pkg.sv \
		+incdir+$(UVM_HOME)/src test_pkg.sv \
		+incdir+$(UVM_HOME)/src ahb.sv  bus_if.sv mem.sv \
		top.sv



simulation:
	vsim -sgq 4g\
		-c \
		-l mti.log \
		 \
		-coverage \
		-pli /proj/caeeda/NOVAS/VERDI/201010/share/PLI/modelsim_fli_latest/LINUX/novas_fli.so \
		-lib work \
		-sv_lib $(UVM_HOME)/lib/uvm_dpi \
		-novopt \
		+UVM_TESTNAME=ahb_master_test \
		-do "run -a;quit -f"  \
		top

clean:
	rm -rf work
	rm -f vsim.wlf
	rm -f transcript
	rm *.vstf

		



		
