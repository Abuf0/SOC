APB概述
- 低速低功耗，同步；
- 适用于访问外设的寄存器（APB bridge <--> memory），此时APB bridge = Request，外设 = Completer；
- 一次传输至少需要2 cycles；
- 接口列表详见Spec；
- 写传输(w/wo wait)和读传输(w/wo wait)详见Spec；
- APB接口的operating FSM详见Spec；

AHB概述
- 高速高带宽，同步；
- 适用于core和高速外设、bridge连接；
- 支持多主多从；
- 支持burst传输；
- 支持流水（ADDR和DATA之间）；