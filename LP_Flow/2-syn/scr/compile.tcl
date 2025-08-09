### Set env and path ###
set TOP [getenv TOP]
set DATE [getenv DATE]
set VER [getenv VER]
set INCLUDE_PATH ../hdl/
set SCRIPT_PATH ../scr/
set NETLIST_PATH ../net/
set REPORT_PATH ../rpt/
set DDC_PATH ../ddc/
set SDC_PATH ../sdc/
set SDF_PATH ../sdf/
set LIB_PATH ../lib/

### Develop HDL files ###
set RTL_INCLUDE ${INCLUDE_PATH}rtl_include.v

### Specify libraries ###
set base_path { /home/jjt/library/tsmc40/tcbn40lpbwp12t40m1p_200a_nldm/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn40lpbwp12t40m1p_200a/   \
                ${LIB_PATH} \
                /home/jjt/projects/LP_Flow/2-syn/lib \
    }
set search_path [concat $search_path [list . /home/jjt/install/synopsys/dc/syn/T-2022.03-SP2/libraries/syn    \
                 $base_path  \
    ]]
# set link_library -- 所有相关电路的db库（包括stdcell、ip等）
## TT -- tcbn40lpbwp12t40m1ptc.db
## FF -- tcbn40lpbwp12t40m1plt.db
## SS -- tcbn40lpbwp12t40m1pwc.db (0.99, std w/o ISO)
##       tcbn40lpbwp12t40m1pwc0d810d91 (0.81, ISO)
set link_library [list \
    tcbn40lpbwp12t40m1pwc0d81.db \
    tcbn40lpbwp12t40m1pwc0d810d81.db \
    pad_s1.db \
    analog_top.db \
    standard.sldb   \
    dw_foundation.sldb  \
    ]
# set target_library -- 综合生成网表的目标工艺db库
set target_library [list    \
    tcbn40lpbwp12t40m1pwc0d81.db \
    tcbn40lpbwp12t40m1pwc0d810d81.db \
    ]

# set symbol_library [optional] --GUI界面图形符号库

# set synthetic_library -- DesignWare的db库（包括标准的verilog运算符、扩展的运算符）
set synthetic_library [list\
    standard.sldb   \
    dw_foundation.sldb  \
    ]
# set create_mw_lib [optional] --milkyway物理库
# set mw_design_library $TOP
# create_mw_lib -technology $tech_file    \
#               -mw_reference_library $mw_reference_library   \
#                                     $mw_design_library
# open_mw_lib $mw_design_library

define_design_lib WORK -path ./work
set_svf ${REPORT_PATH}${DATE}${VER}/${TOP}.svf

### Read design ###
analyze -format sverilog ${RTL_INCLUDE}
elaborate $TOP

current_design $TOP

### Define design enviroment ###
#set_operating_conditions CCOM
set_operating_conditions WC0D810COM
set_operating_conditions WC0D810D81COM
set_wire_load_mode top
# set_drive
# set_driving_cell
# set_load
# set_fanout_load
# set_min_library

### Set design constraints ###
source -e -v ${SCRIPT_PATH}${TOP}_cons.sdc

### Select compile strategy

### Synthesize and optimize the design ###
# ICG
set INSERT_CG true
set CG_MIN_BITWIDTH 5
# DONT USE
set DONT_USE false
set DONT_USE_CELL {
    */DLY*  \
    }
# DONT TOUCH
set DONT_TOUCH enable
set DONT_TOUCH_CELL {    }
set DONT_TOUCH_NET {\
    *VDD* \
    *VSS*\
    }

set congestion_high_effort false
# POWER
set power_high_effort false
# Others
set verilogout_no_tri true
set verilogout_equation false
set_fix_multiple_port_nets  -feedthroughs   -outputs    -buffer_constant
change_names -rules verilog -hier -verbose

#set dc_allow_rtl_pg true
set write_name_nets_same_as_ports true
set compile_seqmap_propagate_constants false
set compile_preserve_subdesign_interfaces true
set power_preserve_rtl_hier_name true

compile_ultra -no_autoungroup -no_boundary_optimization -gate_clock -retime -scan -no_seq_output_inversion

### Analyze and resolve design problems ###
check_design > ${REPORT_PATH}${DATE}${VER}/${TOP}_check_design.rpt
check_timing > ${REPORT_PATH}${DATE}${VER}/${TOP}_check_timing.rpt
report_clock > ${REPORT_PATH}${DATE}${VER}/${TOP}_clock_pre.rpt
report_area -hierarchy -nosplit > ${REPORT_PATH}${DATE}${VER}/${TOP}_area_pre.rpt
report_constraint -all > ${REPORT_PATH}${DATE}${VER}/${TOP}_all_vio_pre.rpt
report_clock_gating -hier > ${REPORT_PATH}${DATE}${VER}/${TOP}_icg_pre.rpt
report_power > ${REPORT_PATH}${DATE}${VER}/${TOP}_power_pre.rpt
report_timing -loops -max_path 100 -nworst 100 > ${REPORT_PATH}${DATE}${VER}/${TOP}_loop_pre.rpt
report_resources -hierarchy -nosplit > ${REPORT_PATH}${DATE}${VER}/${TOP}_resources_pre.rpt

### Save the design database ###
write_sdc -version 1.4 ${SDC_PATH}${DATE}${VER}/${TOP}_cons.sdc
write -format ddc -hierarchy -output ${DDC_PATH}${TOP}${VER}_${DATE}.ddc
write -format verilog -hierarchy -output ${NETLIST_PATH}${DATE}${VER}/${TOP}.v
write_sdf -version 1.4 ${SDF_PATH}${DATE}${VER}/${TOP}_dc.spf
### DFT Flow ###

### UPF ###
set UPF_FLOW true
if {${UPF_FLOW} == "true"} {

remove_upf;
load_upf ${SCRIPT_PATH}${TOP}_dc.upf
save_upf ${REPORT_PATH}${DATE}${VER}/${TOP}.upf

# set voltage on supply nets(not supply ports like VDD1)
set_voltage 0.81 -object_list {VVDD1 VVDD2 VVDD3}
set_voltage 0 -object_list {VVSS}

insert_mv_cells -isolation -verbose
check_mv_design -verbose > ${REPORT_PATH}${DATE}${VER}/${TOP}_preupf_mv.rpt

set verilogout_no_tri true
set verilogout_equation false
set_fix_multiple_port_nets -all -buffer_constant [get_designs *]
change_names -rules verilog -hier -verbose
set write_name_nets_same_as_ports true

compile_ultra -incremental -no_autoungroup -no_boundary_optimization

check_mv_design -verbose > ${REPORT_PATH}${DATE}${VER}/${TOP}_postupf_mv.rpt

write -format ddc -hierarchy -output ${DDC_PATH}${TOP}_upf${VER}_${DATE}.ddc
write -format verilog -hierarchy -output ${NETLIST_PATH}${DATE}${VER}/${TOP}_upf.v
write_sdf -version 1.4 ${SDF_PATH}${DATE}${VER}/${TOP}_upf_dc.spf

check_design > ${REPORT_PATH}${DATE}${VER}/${TOP}_upf_check_design.rpt
report_clock > ${REPORT_PATH}${DATE}${VER}/${TOP}_upf_clock_pre.rpt
report_area -hierarchy -nosplit > ${REPORT_PATH}${DATE}${VER}/${TOP}_upf_area_pre.rpt
report_constraint -all > ${REPORT_PATH}${DATE}${VER}/${TOP}_upf_all_vio_pre.rpt
#report_operand_isolation -all -verbose > ${REPORT_PATH}${DATE}${VER}/${TOP}_upf_opiso_pre.rpt
report_clock_gating -hier > ${REPORT_PATH}${DATE}${VER}/${TOP}_pf_icg_pre.rpt
report_power > ${REPORT_PATH}${DATE}${VER}/${TOP}_upf_power_pre.rpt
report_timing -loops -max_path 100 -nworst 100 > ${REPORT_PATH}${DATE}${VER}/${TOP}_upf_loop_pre.rpt
report_resources -hierarchy -nosplit > ${REPORT_PATH}${DATE}${VER}/${TOP}_upf_resources_pre.rpt

}