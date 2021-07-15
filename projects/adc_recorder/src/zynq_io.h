#ifndef _ZYNQ_IO_H_
#define _ZYNQ_IO_H_

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/ioctl.h>

#define CMA_ALLOC _IOWR('Z', 0, uint32_t)
#define INTC_BASEADDR 0x40000000
#define INTC_HIGHADDR 0x40000FFF

#define CFG_BASEADDR  0x40000000
#define CFG_HIGHADDR  0x40000FFF

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
#define CFG_WR_ADDR_OFFSET       0x4
#define CFG_NSAMPLES_OFFSET      0x8
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
#define CFG_TR_SCAL_A_OFFSET     0x38
#define CFG_TR_SCAL_B_OFFSET     0x3C
#define CFG_HV1_OFFSET           0x4C //DAC_PWM3
#define CFG_HV2_OFFSET           0x48 //DAC_PWM2
#define CFG_HV3_OFFSET           0x40 //DAC_PWM0
#define CFG_HV4_OFFSET           0x44 //DAC_PWM1

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
//See page 17 of PG091
#define XADC_SRR_OFFSET          0x00   //Software reset register
#define XADC_SR_OFFSET           0x04   //Status Register
#define XADC_AOSR_OFFSET         0x08   //Alarm Out Status Register
#define XADC_CONVSTR_OFFSET      0x0C   //CONVST Register
#define XADC_SYSMONRR_OFFSET     0x10   //XADC Reset Register
#define XADC_GIER_OFFSET         0x5C   //Global Interrupt Enable Register
#define XADC_IPISR_OFFSET        0x60   //IP Interrupt Status Register
#define XADC_IPIER_OFFSET        0x68   //IP Interrupt Enable Register
#define XADC_TEMPERATURE_OFFSET  0x200  //Temperature
#define XADC_VCCINT_OFFSET       0x204  //VCCINT
#define XADC_VCCAUX_OFFSET       0x208  //VCCAUX
#define XADC_VPVN_OFFSET         0x20C  //VP/VN
#define XADC_VREFP_OFFSET        0x210  //VREFP
#define XADC_VREFN_OFFSET        0x214  //VREFN
#define XADC_VBRAM_OFFSET        0x218  //VBRAM
#define XADC_UNDEF_OFFSET        0x21C  //Undefined
#define XADC_SPLYOFF_OFFSET      0x220  //Supply Offset
#define XADC_ADCOFF_OFFSET       0x224  //ADC Offset
#define XADC_GAIN_ERR_OFFSET     0x228  //Gain Error
#define XADC_ZDC_SPLY_OFFSET     0x234  //Zynq-7000 Device Core Supply
#define XADC_ZDC_AUX_SPLY_OFFSET 0x238  //Zynq-7000 Device Core Aux Supply
#define XADC_ZDC_MEM_SPLY_OFFSET 0x23C  //Zynq-7000 Device Core Memory Supply
#define XADC_VAUX_PN_0_OFFSET    0x240  //VAUXP[0]/VAUXN[0]
#define XADC_VAUX_PN_1_OFFSET    0x244  //VAUXP[1]/VAUXN[1]
#define XADC_VAUX_PN_2_OFFSET    0x248  //VAUXP[2]/VAUXN[2]
#define XADC_VAUX_PN_3_OFFSET    0x24C  //VAUXP[3]/VAUXN[3]
#define XADC_VAUX_PN_4_OFFSET    0x250  //VAUXP[4]/VAUXN[4]
#define XADC_VAUX_PN_5_OFFSET    0x254  //VAUXP[5]/VAUXN[5]
#define XADC_VAUX_PN_6_OFFSET    0x258  //VAUXP[6]/VAUXN[6]
#define XADC_VAUX_PN_7_OFFSET    0x25C  //VAUXP[7]/VAUXN[7]
#define XADC_VAUX_PN_8_OFFSET    0x260  //VAUXP[8]/VAUXN[8]
#define XADC_VAUX_PN_9_OFFSET    0x264  //VAUXP[9]/VAUXN[9]
#define XADC_VAUX_PN_10_OFFSET   0x268  //VAUXP[10]/VAUXN[10]
#define XADC_VAUX_PN_11_OFFSET   0x26C  //VAUXP[11]/VAUXN[11]
#define XADC_VAUX_PN_12_OFFSET   0x270  //VAUXP[12]/VAUXN[12]
#define XADC_VAUX_PN_13_OFFSET   0x274  //VAUXP[13]/VAUXN[13]
#define XADC_VAUX_PN_14_OFFSET   0x278  //VAUXP[14]/VAUXN[14]
#define XADC_VAUX_PN_15_OFFSET   0x27C  //VAUXP[15]/VAUXN[15]

#define XADC_AI0_OFFSET XADC_VAUX_PN_8_OFFSET
#define XADC_AI1_OFFSET XADC_VAUX_PN_0_OFFSET
#define XADC_AI2_OFFSET XADC_VAUX_PN_1_OFFSET
#define XADC_AI3_OFFSET XADC_VAUX_PN_9_OFFSET

#define XADC_CONV_VAL 0.00171191993362 //(A_ip/2^12)*(34.99/4.99)
#define XADC_RDIV_VAL 1.883236177     //voltage divisor in board (15k+16.983k)/16.983k = 1.88
#define XADC_BASE_HVDIV 0.00294088    //voltage divisor in HV base board (100k/31.3Meg) = 3.194888179. The value I put here is the measured one.

extern int intc_fd, cfg_fd, sts_fd, xadc_fd, mem_fd, cma_fd;
extern void *intc_ptr, *cfg_ptr, *sts_ptr, *xadc_ptr, *mem_ptr, *cma_ptr;
extern uint32_t dev_size;

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
int      cma_init(void);
float    get_voltage(uint32_t offset);
void     set_voltage(uint32_t offset, int32_t value);
float    get_temp_AD592(uint32_t offset);
int      init_system(void);
int      enable_interrupt(void);
int      disable_interrupt(void);

#endif

