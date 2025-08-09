### sdc version
set sdc_version 1.4

### Set Variaty/Units

### DRC-- design rule constrants
set_input_transition 2 [all_inputs]
set_max_transition 2.5 [current_design]
set_max_fanout 32 [current_design]
set_load 50 [all_outputs]

### Timing constrants
# clock definitions/clock lantency/uncertainty/groups/icg
## clk_400m domain
create_clock [get_pins u_da_top/analog_top_inst/ad_osc400m] -name clk_400m -period 2.5 -add
set_clock_uncertainty -setup 0 [get_clocks clk_400m]
set_clock_uncertainty -hold 0.3 [get_clocks clk_400m]

# divider output
create_generated_clock [get_pins u_digital_top/u_crgu/clk_div_0/clk_div_reg/Q] -name clk_20m   -source [get_pins u_da_top/analog_top_inst/ad_osc400m]    -master_clock clk_400m  -divide_by 20  -add
set_clock_uncertainty -setup 0 [get_clocks clk_20m]
set_clock_uncertainty -hold 0.3 [get_clocks clk_20m]
#
create_generated_clock [get_pins u_digital_top/u_crgu/clk_div_1/clk_div_reg/Q] -name clk_5m   -source [get_pins u_digital_top/u_crgu/clk_div_0/clk_div_reg/Q]    -master_clock clk_20m  -divide_by 4  -add
set_clock_uncertainty -setup 0 [get_clocks clk_5m]
set_clock_uncertainty -hold 0.3 [get_clocks clk_5m]

# invert output
#create_generated_clock [get_pins top_inst/crgu_inst/clk_100m_inv/dtc_ckinvd4_inst/Y] -name clk_100m_inv   -source [get_pins top_inst/clk_100m]    -master_clock clk_100m  -divide_by 1  combination -invert  -add
#set_clock_uncertainty -setup 0 [get_clocks clk_100m_inv]
#set_clock_uncertainty -hold 0.3 [get_clocks clk_100m_inv]

## clk_100m domain
create_clock [get_pins u_da_top/analog_top_inst/ad_pll100m] -name clk_100m -period 10 -add
set_clock_uncertainty -setup 0 [get_clocks clk_100m]
set_clock_uncertainty -hold 0.3 [get_clocks clk_100m]

## clk_32k domain
create_clock [get_pins u_da_top/analog_top_inst/ad_wdt32k] -name clk_32k -period 31250 -add
set_clock_uncertainty -setup 0 [get_clocks clk_32k]
set_clock_uncertainty -hold 0.3 [get_clocks clk_32k]

## spi sck domain
create_clock [get_ports PAD_SCK]    -name spi_clk   -period 25  -add
set_clock_uncertainty -setup 0 [get_clocks spi_clk]
set_clock_uncertainty -hold 0.3 [get_clocks spi_clk]

## groups
set_clock_groups    -name clk_grp_0 -group [get_clocks  {clk_400m clk_20m clk_5m}]    \
                                    -group [get_clocks  {clk_100m}] \
                                    -group [get_clocks  {clk_32k}]  \
                                    -group [get_clocks  {spi_clk}]  \
                                    -asynchronous

## icg
set_clock_gating_check  -rise  -setup 0.5 [current_design]
set_clock_gating_check  -fall  -setup 0.5 [current_design]
set_clock_gating_check  -rise  -hold 0.5 [current_design]
set_clock_gating_check  -fall  -hold 0.5 [current_design]

# set input/output delay (output clock can be virtual clock)
#set_input_delay 5 [all_inputs]  -max  -clock clk_100m
#set_output_delay 5 [all_outputs]    -min    -clock clk_100m
set_input_delay 3.0 [get_ports PAD_CSN] -max -clock spi_clk -clock_fall -add
set_input_delay 0.0 [get_ports PAD_CSN] -min -clock spi_clk -clock_fall -add

### Timing exceptions -- multi-cycle/false path/disable_timing/case_analysis
# set_false_path -from    -to
# set_disable_timing -from  -to
# set_multicycle_path   -setup/hold 2 -from  -to
# set_case_analysis 0 xx
set_dont_touch [get_cells -hierarchical dtc* -filter "is_hierarchical==false"]
set_dont_touch [get_nets -of *VDD* *VSS*] true