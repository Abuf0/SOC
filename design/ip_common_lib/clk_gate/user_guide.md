## clock gate cases ##
> 喂大模型只需要看`0-Structure`、`1-Case list`、`3-Testbench Structure/defines`
### 0. Structure
- 每个module的rtl中包含了*时钟门控前*和*时钟门控后*的代码，通过`USE_ICG`宏定义作区分；
- 每个module的rtl中包含了必要的`SVA Checker`，通过`ASSERT_ON`宏定义来标识；
- `<ckgate_cell.v>`为时钟门控的rtl文件，如果只做行为级仿真，需要打开`FPAG`宏定义选项，否则需要在`<ckgate_cell.v>`中补充对应technology library的标准单元；
- `<tb.sv>`为激励文件；
- `<filelist.f>`为文件列表；
- `<Makefile>`为仿真和dump波形的basic script；
### 1. Case List
> 注意：无特殊说明时，默认是同步电路
#### 1.1 外部激励相关
- counter_level_clr_1

    使能enable时，每隔100个时钟周期，打出一个counter_out脉冲；
- mul_unit

    两个8bit有符号数相乘，in_valid拉高时，在下一周期送出out_valid和计算结果mul_out；
- mul_unit_nonvld

    两个8bit有符号数相乘，使能enable时，在下一周期送出计算结果mul_out；
- mpx_hgt

    NOTE: MPX的作用是将芯片内部需要dbg的信号通过MUX拉到PAD上，用于观察检测；对于高频翻转信号（例如时钟），建议gate后再通过MPX送出；至于哪些是需要gate的高频翻转信号，需要设计人员定义；
    
    使能rg_mpx_en，rg_mpx_sel=1时选中4分频后的时钟clk_div（该信号需要经过ICG）；

- lp_pulse_sync
  
  跨时钟脉冲同步器（支持多个pulse共用一个ckgate）；

- spi_wr_reg
  
  //SPI读写寄存器（有读写动作时才使能寄存器时钟）;

#### 1.2 内部状态相关
- reg_wr
  
  //除了SPI读写寄存器，内部功能也会更新寄存器；

- fsm_e1
  状态机列表：S0 -> S1 -> S2 -> S3 -> S0 ...
  - S0：初始态IDLE，fsm_start_trig拉高时，进入S1；
  - S1：counter计数100个时钟周期后，进入S2；
  - S2：连续计算10个mula[7:0]*mulb[7:0]；
  - S3：counter计数100个时钟周期后，回到S0；

  
### 2. Assertion Discription
- 每个module的.sv文件中包含对应的SVA Check，通过<`define ASSERT_ON>启用assertion check功能；
- 只针对涉及“插入时钟门控”的功能做了SVA Check；
- 要求激励满足模块SPEC；（即testbench中的激励需要和模块SPEC保持一致）
- 只适用于通用场景，覆盖率有限；
### 3. Testbench Struction
- defines
  - `define ASSERT_ON: 打开SVA Check开关
  - `define FPGA: clock gate使用rtl model（适用于不带工艺库的仿真和FPGA仿真）；否则需要在./ckgate_cell.v中实例化对应工艺库下的clock gate单元
  - `define USE_ICG: 插入时钟门控后的电路；否则是前端不插时钟门控
  - `define CLK_PERIOD: 仿真时钟频率，单位ns，可以根据工艺和仿真时长需求修改，默认100MHz
  - `define CLK_DST_PERIOD: 异步时钟频率，单位ns，可以修改，默认40MHz
- variable
  - 默认，有需要建议联系DE修改
- simulation init
  - startup和仿真时长设置，可修改
- test case
  - 默认所有module在复位释放后才会开始操作
  - 只针对每个module给出了常用场景下的示例
### 4. Simulation Quich Start
- Step.1 environment setup
  - 确保所有module的rtl、testbench、时钟门控单元、filelist和Makefile文件在同一目录下，如需改变，则修改filelist.f和Makefile里对应的路径；
  - 如需使用ICG标准单元，则在ckgate_cell.v中实例化ICG；
- Step.2 Simulation & Waveform
  - VCS仿真：
    - 在Makefile所在目录下```make vcs_compile```，生成对应的log和fsdb文件；
  - VERDI查看波形：
    - 在Makefile所在目录下```make verdi &```
    - 可从Window -> Assertion Debug Mode查看SVA断言