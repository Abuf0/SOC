#! /bin/csh -f

### set neccesary env
setenv TOP lp_soc_top
setenv VER DEMO_v1
setenv DATE `date +%y%m%d`
setenv syn_style rtl2syn
# rtl2syn / dft2iso

### create new folders
cd ../net/ 
if (-e ${DATE}) then
else mkdir ${DATE}${VER}
endif

cd ../rpt/
if (-e ${DATE}) then
else mkdir ${DATE}${VER}
endif

cd ../sdc/
if (-e ${DATE}) then
else mkdir ${DATE}${VER}
endif

### run script
cd ../run/
/home/jjt/install/synopsys/dc/syn/T-2022.03-SP2/bin/dc_shell-xg-t -f ../scr/compile.tcl |tee ../log/${TOP}_${VER}_${DATE}_compile.log