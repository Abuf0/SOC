#ifndef __TYPE_H__
#define __TYPE_H__

#define REG32(_register_) (*(volatile unsigned int *)(_register_))
#define REG8(_register_)  (*(volatile unsigned char *)(_register_))

#endif

/************************** Constant Definitions *****************************/
#ifndef __REG_TOP_H__
#define __REG_TOP_H__

#define REG_TOP_BASEADDR    0x0000
#define CHIP_INFO_ADDR      (REG_TOP_BASEADDR + 0x00)
#define CRGU_CTRL_ADDR      (REG_TOP_BASEADDR + 0x02)
#define PIXEL_SIZE_ADDR     (REG_TOP_BASEADDR + 0x04)
#define FIFO_THRESHOLD_ADDR (REG_TOP_BASEADDR + 0x06)
#define FIFO_USED_ADDR      (REG_TOP_BASEADDR + 0x08)
#define ADC_CFG_ADDR        (REG_TOP_BASEADDR + 0x0a)
#define CTRL_REG_ADDR       (REG_TOP_BASEADDR + 0x0c)
#define INT_CLEAR_ADDR      (REG_TOP_BASEADDR + 0x0e)
#define INT_STATUS_ADDR     (REG_TOP_BASEADDR + 0x10)
#define PMU_CFG0_ADDR       (REG_TOP_BASEADDR + 0x12)
#define PMU_CFG1_ADDR       (REG_TOP_BASEADDR + 0x14)
#define PAD_CTRL_ADDR       (REG_TOP_BASEADDR + 0x16)
#define ISP_PATTERN_CFG_ADDR (REG_TOP_BASEADDR + 0x18)
#define ISP_DPC_CFG_ADDR    (REG_TOP_BASEADDR + 0x20)

#endif
