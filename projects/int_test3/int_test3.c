#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/mman.h>

#define VERSION "0.1"

#define DEVICE_NAME "AXITimer"
#define XIL_AXI_TIMER_TCSR_OFFSET           0x0
#define XIL_AXI_TIMER_TLR_OFFSET            0x4
#define XIL_AXI_TIMER_TCR_OFFSET            0x8
#define XIL_AXI_TIMER_CSR_INT_OCCURED_MASK  0x00000100

#define XIL_AXI_TIMER_CSR_CASC_MASK         0x00000800
#define XIL_AXI_TIMER_CSR_ENABLE_ALL_MASK   0x00000400
#define XIL_AXI_TIMER_CSR_ENABLE_PWM_MASK   0x00000200
#define XIL_AXI_TIMER_CSR_INT_OCCURED_MASK  0x00000100
#define XIL_AXI_TIMER_CSR_ENABLE_TMR_MASK   0x00000080
#define XIL_AXI_TIMER_CSR_ENABLE_INT_MASK   0x00000040
#define XIL_AXI_TIMER_CSR_LOAD_MASK         0x00000020
#define XIL_AXI_TIMER_CSR_AUTO_RELOAD_MASK  0x00000010
#define XIL_AXI_TIMER_CSR_EXT_CAPTURE_MASK  0x00000008
#define XIL_AXI_TIMER_CSR_EXT_GENERATE_MASK 0x00000004
#define XIL_AXI_TIMER_CSR_DOWN_COUNT_MASK   0x00000002
#define XIL_AXI_TIMER_CSR_CAPTURE_MODE_MASK 0x00000001

#define TIMER_CNT                           0xF8000000

int interrupted = 0;

void signal_handler(int sig)
{
	interrupted = 1;
}

uint32_t reg_write(uint32_t *reg_base, int offset, uint32_t value) {
	*((volatile uint32_t *)(reg_base + offset)) = value;
}

uint32_t reg_read(uint32_t *reg_base, int offset) {
	return *((volatile uint32_t *)(reg_base + offset));
}

//int timer_isr(int irq, void*dev_id) {
//  unsigned int data;
//
//  /* Check Timer Counter Value */
//  data = reg_read(dev_virtaddr + XIL_AXI_TIMER_TCR_OFFSET);
//  printk("xilaxitimer_isr: Interrupt Occurred ! Timer Count = 0x%08X\n",data);
//
//  /* 
//   * Clear Interrupt
//   */
//  data = ioread32(dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);
//  iowrite32(data | XIL_AXI_TIMER_CSR_INT_OCCURED_MASK, dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);
//
//  /* 
//   * Disable Timer after 100 Interrupts
//   */
//  int_cnt++;
//
//  if (int_cnt>=100)
//  {
//          printk("xilaxitimer_isr: 100 interrupts have been occurred. Disabling timer");
//          data = ioread32(dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);
//          iowrite32(data & ~(XIL_AXI_TIMER_CSR_ENABLE_TMR_MASK), dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);
//  }
//
//  return IRQ_HANDLED;
//}
//
//int timer_init(void *tmr) {
//  unsigned int data;
//
//  int_cnt = 0;
//
//  printf("Initialize Timer \"%s\"\n", DEVICE_NAME);
//
//  /* Set Timer Counter */
//  iowrite32(TIMER_CNT,dev_virtaddr + XIL_AXI_TIMER_TLR_OFFSET);
//  data = ioread32(dev_virtaddr + XIL_AXI_TIMER_TLR_OFFSET);
//  printk("xilaxitimer_init: Set timer count 0x%08X\n",data);
//
//  /* 
//   * Set Timer mode and enable interrupt
//   */
//  iowrite32(XIL_AXI_TIMER_CSR_LOAD_MASK, dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);
//  iowrite32(XIL_AXI_TIMER_CSR_ENABLE_INT_MASK | XIL_AXI_TIMER_CSR_AUTO_RELOAD_MASK, dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);
//
//  /* 
//   * Register Device Module
//   */
//  pdev = platform_device_register_simple(DEVICE_NAME, 0, NULL, 0);
//  if (pdev == NULL) {
//          printk(KERN_WARNING "xilaxitimer_init: Adding platform device \"%s\" failed\n", DEVICE_NAME);
//          kfree(pdev);
//          return -ENODEV;
//  }
//  /* 
//   * Start Timer
//   */
//  data = ioread32(dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);
//  iowrite32(data | XIL_AXI_TIMER_CSR_ENABLE_TMR_MASK, dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);
//  //iowrite32(XIL_AXI_TIMER_CSR_ENABLE_TMR_MASK, dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);
//  printk("xilaxitimer_init: data leido 0x%08X\n",data);
//  printk("xilaxitimer_init: valor cargado 0x%08X\n",data | XIL_AXI_TIMER_CSR_ENABLE_TMR_MASK);
//
//  data = ioread32(dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);
//  printk("xilaxitimer_init: data leido2 0x%08X\n",data);
//  data = ioread32(dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);
//  printk("xilaxitimer_init: data leido3 0x%08X\n",data);
//  data = ioread32(dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);
//  printk("xilaxitimer_init: data leido4 0x%08X\n",data);
//  return 0;
//}

int main(int argc, char *argv[]) {
	int fd;
	int mfd, i;
	uint32_t wo;
	int16_t ch[2];
	int position, limit, offset;
	volatile uint32_t *gic;
	void *tmr, *sts, *ram;
	char *name = "/dev/mem";
	int32_t mtd_dp = 0, mtd_cdp = 0, mtd_pulse_cnt = 0, mtd_pulse_pnt = 0;
	uint32_t data;


	if((fd = open(name, O_RDWR)) < 0)
	{
		perror("open");
		return 1;
	}

	//  gic = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0xF8F00000);
	tmr = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40000000);
	ram = mmap(NULL, 1024*sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x1E000000);


	//  printf("0x%08X\n", gic[92]);
	//  printf("0x%08X\n", gic[93]);
	//  printf("0x%08X\n", gic[94]);
	//  printf("0x%08X\n", gic[95]);
	// set HP0 bus width to 64 bits
	//slcr[2] = 0xDF0D;
	//slcr[144] = 0;


	signal(SIGINT, signal_handler);

	limit = 512*1024; //middle of the memory

	// wait 1 second
	//sleep(1);
	/* Set Timer Counter */
	reg_write(tmr,XIL_AXI_TIMER_TLR_OFFSET, TIMER_CNT);
	data = reg_read(tmr, XIL_AXI_TIMER_TLR_OFFSET);
	printf("xilaxitimer_init: Set timer count 0x%08X\n",data);

	/* Set Timer mode and enable interrupt */
	reg_write(tmr, XIL_AXI_TIMER_TCSR_OFFSET, XIL_AXI_TIMER_CSR_LOAD_MASK);
	reg_write(tmr, XIL_AXI_TIMER_TCSR_OFFSET, XIL_AXI_TIMER_CSR_ENABLE_INT_MASK | XIL_AXI_TIMER_CSR_AUTO_RELOAD_MASK);

	/* Start Timer */
	data = reg_read(tmr, XIL_AXI_TIMER_TCSR_OFFSET);
	reg_write(tmr, XIL_AXI_TIMER_TCSR_OFFSET, data | XIL_AXI_TIMER_CSR_ENABLE_TMR_MASK);
	printf("xilaxitimer_init: data leido 0x%08X\n",data);


	//  reg_write(tmr,4,0xF80000FF);
	//  printf("Load Reg TLR0: 0x%08X\n", reg_read(tmr,4));
	//  
	//  reg_write(tmr,0,XIL_AXI_TIMER_CSR_LOAD_MASK);
	//  printf("TCSR0: 0x%08X\n", reg_read(tmr,0));
	//  reg_write(tmr,0,XIL_AXI_TIMER_CSR_ENABLE_INT_MASK | XIL_AXI_TIMER_CSR_AUTO_RELOAD_MASK);
	//  printf("TCSR0: 0x%08X\n", reg_read(tmr,0));
	//
	//  
	//  reg_write(tmr,0,reg_read(tmr,0) | XIL_AXI_TIMER_CSR_ENABLE_TMR_MASK);
	//
	//  printf("TCSR0: 0x%08X\n", reg_read(tmr,0));
	//  printf("TLR0: 0x%08X\n", reg_read(tmr,4));
	//  printf("TCR0: 0x%08X\n", reg_read(tmr,8));

	munmap(tmr, sysconf(_SC_PAGESIZE));
	munmap(ram, sysconf(_SC_PAGESIZE));

	return 0;
}

