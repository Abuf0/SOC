## spyglass tcl
## spyglass base define
set top lp_soc_top   
set prj_loc /home/jjt/projects/LP_Flow/0-rtl/spyglass/rundir/work
new_project ${top} -projectwdir $prj_loc -force 
set_option top ${top} 

##read rtl and lib
read_file -type sourcelist ${top}.f
#read_file -type verilog {lib_xxx} 
read_file -type sgdc ${top}.sgdc 
read_file -type awl ${top}_waive.awl 

set_option default_waiver_file ${top}_waive.awl 

##spyglass setup
set_option sdc2sgdc yes
set_option enable_precompile_vlog yes
set_option sort yes
set_option 87 yes
set_option language_mode mixed
set_option designread_disable_flatten yes
set_option enableSV yes
set_option enableSV09 yes
#set_option designread_enable_synthesis no
#set_parameter enable_generated_clock yes
#set_parameter enable_glitchfreecell_detection yes
#set_parameter pt no 
#set_option sgsyn_clock_gating 1
#set_option allow_module_override yes
#set_option vlog2001_generate_name yes
#set_option handlememory yes
#set_option define_cell_sim_depth 11
#set_option mthresh 400000
#set_option incdir {}
set_option ignoredu {pad_s1}
set_option ignoredu {analog_top}

current_methodology $SPYGLASS_HOME/GuideWare/latest/block/rtl_handoff

##lint rtl
current_goal lint/lint_rtl -top ${top}
run_goal
write_report moresimple > ${top}_nLint.rpt

###cdc setup
#current_goal cdc/cdc_setup_check -top ${top}
#run_goal
#write_report moresimple > ${top}_cdc_setup.rpt
#
###cdc verify struct
#current_goal cdc/cdc_verify_struct -top ${top}
#run_goal
#write_report moresimple > ${top}_cdc_verify_struct.rpt
#
###cdc verify
#current_goal cdc/cdc_verify -top ${top}
#run_goal
#write_report moresimple > ${top}_cdc_verify.rpt
#
###rdc verify struct
#current_goal cdc/cdc_verify_struct -top ${top}
#run_goal
#write_report moresimple > ${top}_rdc_verify_struct.rpt

save_project -force ${top}.prj
