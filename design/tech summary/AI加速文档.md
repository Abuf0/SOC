# AI加速文档 #
## 常用网络/算子
### 常用网络
- CNN
- Transformer
### 常用算子
- GEMM/MatMul（绝对核心）

    Linear/FC、1x1 Conv、Attention 的 QKV/投影

    变种：batched GEMM、grouped GEMM、block-sparse GEMM

- 卷积类

    Conv2D（KxK）、Depthwise Conv、Group Conv、Deconv/Transposed Conv

    Winograd / FFT（有时用在大核或特定场景）

- Attention 相关

    QK^T、Softmax、(Softmax·V)

    LayerNorm/RMSNorm

    KV Cache 读写（LLM 推理的关键瓶颈之一）

- 逐元素与归约

    Activation：ReLU/GELU/SiLU(Swish)、Tanh

    Eltwise：Add/Mul、BiasAdd

    Reduce：Sum/Max、Mean/Variance（Norm、Pool）

    Pool：MaxPool/AvgPool

- 数据重排/内存相关（经常是性能瓶颈）

    Transpose、Reshape、Concat/Split、Gather/Scatter

    Im2col/col2im（显式或隐式）

    Padding、Layout 转换（NCHW↔NHWC）

- 量化推理常见算子

    int8/int4 GEMM、Scale/Shift、Requantize、Clamp/Saturate

    Dequant/Quant（部分芯片做融合）

## 常用架构
- Systolic Array / 矩阵阵列（最主流NPU风格）

    代表：TPU 风格、NVDLA风格、很多 NPU 的 MAC 阵列、NVDLA

    优点：对 GEMM/Conv 映射简单、能量效率高、易扩展

    关键设计点：tile/流水、数据流（Output-stationary / Weight-stationary / Row-stationary）、片上 SRAM 容量与带宽

- SIMD/Vector + Tensor Core（GPU 风格）

    代表：GPU SM + Tensor Cores、部分可编程 AI Core

    优点：通用性强，算子覆盖广（尤其 attention + 各类 elementwise）

    缺点：能效通常低于专用 systolic（但生态最好）

- Spatial Dataflow / CGRA 类（介于可编程与专用之间）

    代表：可重构阵列、数据流图映射执行

    优点：适配多算子 pipeline、可做算子融合

    难点：编译映射复杂、时序/资源调度难

- 以存储为中心：Near-/In-Memory Compute（CIM）

    面向：大规模 GEMM/embedding（带宽瓶颈）

    常见：HBM-PIM、SRAM CIM、RRAM CIM（模拟/混合信号）

    优点：大幅降低数据搬运

    难点：精度/良率/一致性、编程模型、通用性

### TPU脉动阵列
![alt text](image-10.png)
- 本质上是完成`矩阵乘`计算；
- 需要提前将Conv等算子mapping成GEMM的形式（或者硬件在取数的时候自动mapping）；
- TPU阵列一般外接双重缓冲的InFea/Weight/OutFea buffer，通过ping-pong的方式减少读开销；
  - 矩阵A按照顺序`自左向右斜坡式`传入，矩阵B按照顺序`自上向下斜坡式`传入；
  - 每个PE中自带MAC单元，完成相乘和累加，得到psum；
  - 满转后对应PE中会得到结果，一般会在右侧/底部收集计算结果（PE结果直接bypass到收集网络中）;
  - 满转过后会在缺位补零，直到排空，完成所有计算；
  - 假设TPU阵列size为`M × N`，那么阵列排满并满转时，每周期最多能收集到`min(M,N)`个计算结果；
- Array Size决定了tile的切片尺寸；根据OutFeature Size来决定tile的切片方式；
  - 假设TPU阵列为3×3， GEMM的InFeaSize为4×5，WeightSize为5×6，那么（不考虑padding，strip=1）OutFeaSize为4×6；为了划分到TPU阵列中，会根据OutFeaSize划分出4个tile，分别为3×3、3×3、1×3、1×3，其中1×3会通过补0填充到3×3；此时使用率会有所降低；
  - 估算conv->TPU的计算cycles：以conv=16x16x3 kernel=3x3 outch=8 stride=1为例
    - 考虑padding后，输出size为16x16x8（256x8），根据8x8的TPU阵列，分成32(256/8)个tile，每个tile的patch为27（3x3x3），总共需要计算864（27x32）个cycle，加上头load
  /尾排空需要7个cyle，总共需要871 cycle。（计算与scale-sim一致）
    - 转成GEMM时，M=256，N=8，K=27。

### NVDLA MAC Array
PK & PC并行

### SIMD + Tensor core（合成一个SM）
- Tensor core
  - 包含很多register，用于存储从cache中读到（重排？）的IF和Weight数据，以及PSUM；
  - 包含矩阵乘计算阵列；
  - 包含很多乘法器；
  - 包含很多LD/ST单元；
  - 包含很多SFU？
- SIMD
  - 统一管理指令到tensor core的分配？

## input/weight/output stationary(数据流调度策略)
TODO:

## 常用架构模拟器
### TimeLoop + Acc

### Scale-Sim
- 参考资料：
  - https://mq-group.github.io/Hands_On/tools/simulator_details/scalesim_detailed/
  - https://github.com/scalesim-project/SCALE-Sim

- 该仿真器基于TPU阵列，用于评估`单层映射/单层数据流`；
- Scale-Sim核心是：给定一层（conv/GEMM），在一个固定数据流（WS/OS/RS）和固定阵列/带宽/片上SRAM 下，算这层的 mapping、访存、stall、util；
- 不支持streaming pipeline（即上层->下层不经过完整的RAM，通过一些缓存后直接下发）；这种更关注编译器和算子的调度，复杂度较高；
- v2中的tensor core：
  ![alt text](image-11.png)
- v3升级版：
  ![alt text](image-12.png)


## NPU和Core之间的交互（以ARM为例）
- 编译
  - pytorch release网络，吐出tfile；
  - vela编译器根据tfile，分辨该计算通过NPU/CPU执行，分割tile，分配数据搬运，解析算子配置，生成bin文件；
  - 和CPU生成的bin(elf->bin)一起，静态/动态存放在某个地址空间；
- 运行
  - CPU执行到某段代码后，根据config配置NPU运行环境，包括command stream的base addr，size、数据类型和量化精度等；
  - NPU内部start被触发后，从config配置中解析CMD存放位置，读取地址中的CMD，并完成指令解析；CMD stream中包含DMA搬运信息、卷积参数等；
  - DMA会将数据从SRAM中搬运到缓冲区（BRAM），卷积还涉及im2col的隐式搬运；
  - NPU启动算子进行计算；
  - NPU完成计算后，会返回中断和中断信息给CPU；
  - CPU接受到中断后，进入服务程序，根据所需处理NPU的计算结果，并且下发下一个config，启动NPU；
- 双缓冲机制
  - CPU会将NPU要用的数据通过DMA从外部存储器（FLASH/DRAM）搬运到SRAM_A中；
  - NPU使用SRAM_A时，CPU会将下一次NPU要用的数据从外部RAM搬运到SRAM_B中；
  - 通过这种乒乓式的双缓冲，可以隐藏一部分搬运数据开销；
- Scale-Sim中的DRAM bandwidth/利用率和SRAM bandwidth/利用率
  - 前者评估的是从外部储存器搬运数据到片上SRAM；受限于带宽、delay、总线频率、功耗；
  - 后者评估的是从片上SRAM中读数据到TPU阵列的缓冲区；着重数据的复用；
  - TODO;