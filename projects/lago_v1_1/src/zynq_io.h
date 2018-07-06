#ifndef _ZYNQ_IO_H_
#define _ZYNQ_IO_H_

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#define INTC_BASEADDR 0x40000000
#define INTC_HIGHADDR 0x40000FFF

#define CFG_BASEADDR  0x40001000
#define CFG_HIGHADDR  0x40001FFF

#define STS_BASEADDR  0x40002000
#define STS_HIGHADDR  0x40002FFF

#define XADC_BASEADDR 0x40003000
#define XADC_HIGHADDR 0x40003FFF

#define XIL_AXI_INTC_ISR_OFFSET    0x0
#define XIL_AXI_INTC_IPR_OFFSET    0x4
#define XIL_AXI_INTC_IER_OFFSET    0x8
#define XIL_AXI_INTC_IAR_OFFSET    0xC
#define XIL_AXI_INTC_SIE_OFFSET    0x10
#define XIL_AXI_INTC_CIE_OFFSET    0x14
#define XIL_AXI_INTC_IVR_OFFSET    0x18
#define XIL_AXI_INTC_MER_OFFSET    0x1C
#define XIL_AXI_INTC_IMR_OFFSET    0x20
#define XIL_AXI_INTC_ILR_OFFSET    0x24
#define XIL_AXI_INTC_IVAR_OFFSET   0x100

#define XIL_AXI_INTC_MER_ME_MASK 0x00000001
#define XIL_AXI_INTC_MER_HIE_MASK 0x00000002

//CFG
#define CFG_RESET_GRAL_OFFSET    0x0
#define CFG_NSAMPLES_OFFSET      0x4
#define CFG_TRLVL_1_OFFSET       0x8
#define CFG_TRLVL_2_OFFSET       0xC
#define CFG_STRLVL_1_OFFSET      0x10
#define CFG_STRLVL_2_OFFSET      0x14
#define CFG_TEMPERATURE_OFFSET   0x18
#define CFG_PRESSURE_OFFSET      0x1C
#define CFG_TIME_OFFSET          0x20
#define CFG_DATE_OFFSET          0x24
#define CFG_LATITUDE_OFFSET      0x28
#define CFG_LONGITUDE_OFFSET     0x2C
#define CFG_ALTITUDE_OFFSET      0x30
#define CFG_SATELLITE_OFFSET     0x34
#define CFG_HV1_OFFSET           0x40
#define CFG_HV2_OFFSET           0x44

//CFG Slow DAC
#define CFG_DAC_PWM0_OFFSET 0x40
#define CFG_DAC_PWM1_OFFSET 0x44
#define CFG_DAC_PWM2_OFFSET 0x48
#define CFG_DAC_PWM3_OFFSET 0x4C

#define ENBL_ALL_MASK         0xFFFFFFFF
#define RST_ALL_MASK          0x00000000
#define RST_PPS_TRG_FIFO_MASK 0x00000001
#define RST_TLAST_GEN_MASK    0x00000002
#define RST_WRITER_MASK       0x00000004
#define RST_AO_MASK           0x00000008
#define FGPS_EN_MASK          0x00000010

//STS
#define STS_STATUS_OFFSET     0x0

//XADC
#define XADC_SRR_OFFSET          0x0
#define XADC_SR_OFFSET           0x4
#define XADC_AOSR_OFFSET         0x8
#define XADC_CONVSTR_OFFSET      0xC
#define XADC_SYSMONRR_OFFSET     0x10
#define XADC_GIER_OFFSET         0x5C
#define XADC_IPISR_OFFSET        0x60
#define XADC_IPIER_OFFSET        0x68
#define XADC_TEMPERATURE_OFFSET  0x200
#define XADC_VCCINT_OFFSET       0x204
#define XADC_VCCAUX_OFFSET       0x208
#define XADC_VPVN_OFFSET         0x20C
#define XADC_VREFP_OFFSET        0x210
#define XADC_VREFN_OFFSET        0x214
#define XADC_VBRAM_OFFSET        0x218
#define XADC_UNDEF_OFFSET        0x21C
#define XADC_SPLYOFF_OFFSET      0x220
#define XADC_ADCOFF_OFFSET       0x224
#define XADC_GAIN_ERR_OFFSET     0x228
#define XADC_ZDC_SPLY_OFFSET     0x234
#define XADC_ZDC_AUX_SPLY_OFFSET 0x238
#define XADC_ZDC_MEM_SPLY_OFFSET 0x23C
#define XADC_VAUX_PN_0_OFFSET    0x240
#define XADC_VAUX_PN_1_OFFSET    0x244
#define XADC_VAUX_PN_2_OFFSET    0x248
#define XADC_VAUX_PN_3_OFFSET    0x24C
#define XADC_VAUX_PN_4_OFFSET    0x250
#define XADC_VAUX_PN_5_OFFSET    0x254
#define XADC_VAUX_PN_6_OFFSET    0x258
#define XADC_VAUX_PN_7_OFFSET    0x25C
#define XADC_VAUX_PN_8_OFFSET    0x260
#define XADC_VAUX_PN_9_OFFSET    0x264
#define XADC_VAUX_PN_10_OFFSET   0x268
#define XADC_VAUX_PN_11_OFFSET   0x26C
#define XADC_VAUX_PN_12_OFFSET   0x270
#define XADC_VAUX_PN_13_OFFSET   0x274
#define XADC_VAUX_PN_14_OFFSET   0x278
#define XADC_VAUX_PN_15_OFFSET   0x27C

#define XADC_AI0_OFFSET XADC_VAUX_PN_8_OFFSET
#define XADC_AI1_OFFSET XADC_VAUX_PN_0_OFFSET
#define XADC_AI2_OFFSET XADC_VAUX_PN_1_OFFSET
#define XADC_AI3_OFFSET XADC_VAUX_PN_9_OFFSET

#define XADC_CONV_VAL 0.00171191993362 //(A_ip/2^12)*(34.99/4.99)

extern int intc_fd, cfg_fd, sts_fd, xadc_fd, mem_fd;
extern void *intc_ptr, *cfg_ptr, *sts_ptr, *xadc_ptr, *mem_ptr;

void     dev_write(void *dev_base, uint32_t offset, int32_t value);
uint32_t dev_read(void *dev_base, uint32_t offset);
//int    dev_init(int n_dev);
int32_t  rd_reg_value(int n_dev, uint32_t reg_off);
int32_t  wr_reg_value(int n_dev, uint32_t reg_off, int32_t reg_val);
int32_t  rd_cfg_status(void);
int      intc_init(void);
int      cfg_init(void);
int      sts_init(void);
int      xadc_init(void);
int      mem_init(void);
float    get_voltage(uint32_t offset);
void     set_voltage(uint32_t offset, int32_t value);
int      init_system(void);
int      enable_interrupt(void);
int      disable_interrupt(void);

#endif

