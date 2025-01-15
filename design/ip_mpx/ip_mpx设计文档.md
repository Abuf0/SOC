# MPX #
复用IO PAD，用于观测部分内部信号；内部信号通过寄存器选中并送到对应MPX功能的IO PAD上，用于debug

这部分rtl依靠gen_mpx.py脚本生成，分为alon_mpx和shut_mpx，分别用于收集alon和shut domain的debug信号；

- alon_mpx
    | rg_alon_mpx_sel0 | mpx0 | 备注|rg_alon_mpx_sel1 | mpx1 | 备注 |
    | ---- | ----- |---| ---- | ----- |---|
    | 0 | clk_1m | 一般会拉一个校准时钟 | 0 |xx|xx|
    | 1 | da_stb_en | LDO给shut domain的上电使能？| 1 |xx|xx|
    | 2 | pmu_cs[2] | PMU状态位 | 2 |pmu_cs[1]|xx|
    | 3 | pmu_cs[0] | PMU状态位 | 3 |xx|xx|
    | … | … |…| … | … |…|
    | … | shut_mpx0 |…| … | shut_mpx1 |…|
    |
- shut_mpx
   | rg_alon_mpx_sel0 | mpx0 | 备注|rg_alon_mpx_sel1 | mpx1 | 备注 |
   | ---- | ----- |---| ---- | ----- |---|
   | 0 | xx | shut domain用于dbg的信号 |0|xx|xx|
   | … | … |…| … | … |…|
   |

- ### notion
1. 注意复用的IO PAD是否有封装问题（比如CardiffC的SYNC，由于封装可能无法拉出来），因此需要重点观测的信号尽量放在确定可以拉出的IO PAD上；
2. 复用的IO PAD是否能作为MPX用途，比如通讯相关的PAD无法用于MPX，容易导致芯片通讯挂死，切不了功能且无法配置寄存器，会影响后续的功能；
3. 注意MPX通用重点观测信号（clk_dbg、da_stb_en等）；
4. MPX的默认输出不要是clock信号或者频繁翻转的信号；
5. 需要同时观测的信号，尽量摆在不同MPX上；
6. 是否要默认拉出efuse_autoload_done？（han哥提的）
7. MPX拉出的clk_dbg需要跟产测确认频率，TO后产测需要根据clk_dbg来测一些时钟属性，但他们的设备（具体是啥我不知道）难以测量高频时钟，因此大多会把时钟做分频，分成x~几百KHz，通过寄存器选择对应的时钟以及分频系数。注意该时钟最好做gate，只有使能MPX和该通道时开启（for power）
8. MPX会和电压域有关；