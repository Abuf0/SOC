vcs_compile:
	@echo "start vcs compile"
	vcs  \
		-f ./filelist.f \
		-timescale=1ns/10ps \
		-full64  -kdb -lca -R  +vc  +v2k  -sverilog  -debug_access+all  \
		-assert enable_diag	\
		+fsdb+sva_success	\
		|tee vcs_compile.log  


verdi:
	@verdi -dbdir simv.daidir -ssf radix4_tb.fsdb -sv &
