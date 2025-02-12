vcs_compile:
	@echo "start vcs compile"
	cd work && vcs  \
		-f ../filelist.f \
		-timescale=1ns/1ps \
		-full64  -kdb -lca -R  +vc  +v2k  -sverilog  -debug_access+all  \
		-assert enable_diag	\
		+fsdb+sva_success	\
		|tee vcs_compile.log  


verdi:
	@cd work && verdi -dbdir simv.daidir -ssf tb.fsdb -sv &
