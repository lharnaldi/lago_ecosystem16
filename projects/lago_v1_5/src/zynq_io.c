#include "zynq_io.h"

int intc_fd, cfg_fd, sts_fd, xadc_fd, mem_fd, hst0_fd, hst1_fd, cma_fd;
void *intc_ptr, *cfg_ptr, *sts_ptr, *xadc_ptr, *mem_ptr, *hst0_ptr, hst1_ptr, *cma_ptr;
uint32_t dev_size;

void dev_write(void *dev_base, uint32_t offset, int32_t value)
{
	*((volatile unsigned *)(dev_base + offset)) = value;
}

uint32_t dev_read(void *dev_base, uint32_t offset)
{
	return *((volatile unsigned *)(dev_base + offset));
}

/*int dev_init(int n_dev)
	{
	char *uiod; = "/dev/uio1";

	printf("Initializing device...\n");

// open the UIO device file to allow access to the device in user space
cfg_fd = open(uiod, O_RDWR);
if (cfg_fd < 1) {
printf("cfg_init: Invalid UIO device file:%s.\n", uiod);
return -1;
}

dev_size = get_memory_size("/sys/class/uio/uio1/maps/map0/size");

// mmap the cfgC device into user space
cfg_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, cfg_fd, 0);
if (cfg_ptr == MAP_FAILED) {
printf("cfg_init: mmap call failure.\n");
return -1;
}

return 0;
}*/

int32_t rd_reg_value(int n_dev, uint32_t reg_off)
{
	int32_t reg_val;
	switch(n_dev)
	{
		case 0:
			reg_val = dev_read(intc_ptr, reg_off);
			break;
		case 1:
			reg_val = dev_read(cfg_ptr, reg_off);
			break;
		case 2:
			reg_val = dev_read(sts_ptr, reg_off);
			break;
		case 3:
			reg_val = dev_read(xadc_ptr, reg_off);
			break;
		default:
			printf("Invalid option: %d\n", n_dev);
			return -1;
	}
	printf("Complete. Received data 0x%08x\n", reg_val);
	//printf("Complete. Received data %d\n", reg_val);

	return reg_val;
}

int32_t wr_reg_value(int n_dev, uint32_t reg_off, int32_t reg_val)
{
	switch(n_dev)
	{
		case 0:
			dev_write(intc_ptr, reg_off, reg_val);
			break;
		case 1:
			dev_write(cfg_ptr, reg_off, reg_val);
			break;
		case 2:
			dev_write(sts_ptr, reg_off, reg_val);
			break;
		case 3:
			dev_write(xadc_ptr, reg_off, reg_val);
			break;
		default:
			printf("Invalid option: %d\n", n_dev);
			return -1;
	}
	printf("Complete. Data written: 0x%08x\n", reg_val);
	//printf("Complete. Data written: %d\n", reg_val);

	return 0;
}

int32_t rd_cfg_status(void)
{
	//float a = 0.0382061, b = 4.11435;  // For gain = 1.45
	float a = 0.0882006, b = 7.73516;  // For gain = 3.2

	printf("#Trigger Level Ch1 = %d\n", dev_read(cfg_ptr, CFG_TRLVL_1_OFFSET));
	printf("#Trigger Level Ch2 = %d\n", dev_read(cfg_ptr, CFG_TRLVL_2_OFFSET));
	//printf("#Subtrigger Ch1    = %d\n", dev_read(cfg_ptr, CFG_STRLVL_1_OFFSET));
	//printf("#Subtrigger Ch2    = %d\n", dev_read(cfg_ptr, CFG_STRLVL_2_OFFSET));
	printf("#High Voltage 1    = %.1f mV\n", a*dev_read(cfg_ptr, CFG_HV1_OFFSET)+b);
	printf("#High Voltage 2    = %.1f mV\n", a*dev_read(cfg_ptr, CFG_HV2_OFFSET)+b);
	printf("#Trigger Scaler 1  = %d\n", dev_read(cfg_ptr, CFG_TR_SCAL_A_OFFSET));
	printf("#Trigger Scaler 2  = %d\n", dev_read(cfg_ptr, CFG_TR_SCAL_B_OFFSET));
	if (((dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET)>>4) & 0x1) == 1) { // No GPS is present
		printf("#No GPS device is present or enabled\n");
	}else{
		printf("#Using GPS data\n");
	}
	if (((dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET)>>5) & 0x1) == 0) //Slave
	{
		printf("#Working mode is SLAVE\n");
	}else{
		printf("#Working mode is MASTER\n");
	}
	printf("\n");
	printf("Status from registers complete!\n");
	return 0;
}

static uint32_t get_memory_size(char *sysfs_path_file)
{
	FILE *size_fp;
	uint32_t size;

	// open the file that describes the memory range size that is based on
	// the reg property of the node in the device tree
	size_fp = fopen(sysfs_path_file, "r");

	if (!size_fp) {
		printf("unable to open the uio size file\n");
		exit(-1);
	}

	// get the size which is an ASCII string such as 0xXXXXXXXX and then be
	// stop using the file
	if(fscanf(size_fp, "0x%08X", &size) == EOF){
		printf("unable to get the size of the uio size file\n");
		exit(-1);
	}
	fclose(size_fp);

	return size;
}

int intc_init(void)
{
	char *mem_name = "/dev/mem";

	//printf("Initializing INTC device...\n");

	// open the memory device file to allow access to the device in user space
	intc_fd = open(mem_name, O_RDWR);
	if (intc_fd < 1) {
		printf("intc_init: Invalid memory device file:%s.\n", mem_name);
		return -1;
	}

	//dev_size = sysconf(_SC_PAGESIZE);

	// mmap the INTC device into user space
	intc_ptr = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, intc_fd, INTC_BASEADDR);
	if (intc_ptr == MAP_FAILED) {
		printf("intc_init: mmap call failure.\n");
		return -1;
	}

	return 0;
}

int cfg_init(void)
{
	char *mem_name = "/dev/mem";

	//printf("Initializing CFG device...\n");

	// open the CFG device file to allow access to the device in user space
	cfg_fd = open(mem_name, O_RDWR);
	if (cfg_fd < 1) {
		printf("cfg_init: Invalid memory device file:%s.\n", mem_name);
		return -1;
	}

	//dev_size = sysconf(_SC_PAGESIZE);

	// mmap the cfg device into user space
	cfg_ptr = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, cfg_fd, CFG_BASEADDR);
	if (cfg_ptr == MAP_FAILED) {
		printf("cfg_init: mmap call failure.\n");
		return -1;
	}

	return 0;
}

int sts_init(void)
{
	char *mem_name = "/dev/mem";

	//printf("Initializing STS device...\n");

	// open the UIO device file to allow access to the device in user space
	sts_fd = open(mem_name, O_RDWR);
	if (sts_fd < 1) {
		printf("sts_init: Invalid memory device file:%s.\n", mem_name);
		return -1;
	}

	//dev_size = sysconf(_SC_PAGESIZE);

	// mmap the STS device into user space
	sts_ptr = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, sts_fd, STS_BASEADDR);
	if (sts_ptr == MAP_FAILED) {
		printf("sts_init: mmap call failure.\n");
		return -1;
	}

	return 0;
}

int xadc_init(void)
{
	char *mem_name = "/dev/mem";

	//printf("Initializing XADC device...\n");

	// open the UIO device file to allow access to the device in user space
	xadc_fd = open(mem_name, O_RDWR);
	if (xadc_fd < 1) {
		printf("xadc_init: Invalid memory device file:%s.\n", mem_name);
		return -1;
	}

	//dev_size = sysconf(_SC_PAGESIZE);

	// mmap the XADC device into user space
	xadc_ptr = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, xadc_fd, XADC_BASEADDR);
	if (xadc_ptr == MAP_FAILED) {
		printf("xadc_init: mmap call failure.\n");
		return -1;
	}

	return 0;
}

int mem_init(void)
{
	char *mem_name = "/dev/mem";

	//printf("Initializing mem device...\n");

	// open the UIO device file to allow access to the device in user space
	mem_fd = open(mem_name, O_RDWR);
	if (mem_fd < 1) {
		printf("mem_init: Invalid device file:%s.\n", mem_name);
		return -1;
	}

	dev_size = 2048*sysconf(_SC_PAGESIZE);

	// mmap the mem device into user space 
	mem_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, mem_fd, 0x1E000000);
	if (mem_ptr == MAP_FAILED) {
		printf("mem_init: mmap call failure.\n");
		return -1;
	}

	return 0;
}

int hst0_init(void)
{
	char *mem_name = "/dev/mem";

	//printf("Initializing mem device...\n");

	// open the UIO device file to allow access to the device in user space
	hst0_fd = open(mem_name, O_RDWR);
	if (hst0_fd < 1) {
		printf("hst0_init: Invalid device file:%s.\n", mem_name);
		return -1;
	}

	// mmap the mem device into user space 
	hst0_ptr = mmap(NULL, 16*sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, hst0_fd, HST0_BASEADDR);
	if (hst0_ptr == MAP_FAILED) {
		printf("mem_init: mmap call failure.\n");
		return -1;
	}

	return 0;
}

int hst1_init(void)
{
	char *mem_name = "/dev/mem";

	//printf("Initializing mem device...\n");

	// open the UIO device file to allow access to the device in user space
	hst1_fd = open(mem_name, O_RDWR);
	if (hst1_fd < 1) {
		printf("hst1_init: Invalid device file:%s.\n", mem_name);
		return -1;
	}

	// mmap the mem device into user space 
	hst1_ptr = mmap(NULL, 16*sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, hst1_fd, HST1_BASEADDR);
	if (hst1_ptr == MAP_FAILED) {
		printf("mem_init: mmap call failure.\n");
		return -1;
	}

	return 0;
}

int cma_init(void)
{
	char *cma_name = "/dev/cma";

	//printf("Initializing mem device...\n");

	// open the UIO device file to allow access to the device in user space
	cma_fd = open(cma_name, O_RDWR);
	if (cma_fd < 1) {
		printf("cma_init: Invalid device file:%s.\n", cma_name);
		return -1;
	}

	dev_size = 1024*sysconf(_SC_PAGESIZE);

	if(ioctl(cma_fd, CMA_ALLOC, &dev_size) < 0) {
		perror("ioctl");
		return EXIT_FAILURE;
	}
	// mmap the mem device into user space 
	cma_ptr = mmap(NULL, 1024*sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, cma_fd, 0);
	if (cma_ptr == MAP_FAILED) {
		printf("cma_init: mmap call failure.\n");
		return -1;
	}

	return 0;
}

float get_voltage(uint32_t offset)
{
	int16_t value;
	value = (int16_t) dev_read(xadc_ptr, offset);
	//  printf("The Voltage is: %lf V\n", (value>>4)*XADC_CONV_VAL);
	return ((value>>4)*XADC_CONV_VAL);
}       

/*void set_voltage(uint32_t offset, int32_t value)
	{       
//fit after calibration. See file data_calib.txt in /ramp_test directory 
// y = a*x + b
//a               = 0.0382061     
//b               = 4.11435   
uint32_t dac_val;
float a = 0.0382061, b = 4.11435; 

dac_val = (uint32_t)(value - b)/a;

dev_write(cfg_ptr, offset, dac_val);
printf("The Voltage is: %d mV\n", value);
printf("The DAC value is: %d DACs\n", dac_val);
}
*/

void set_voltage(uint32_t offset, int32_t value)
{       
	//fit after calibration. See file data_calib2.txt in /ramp_test directory 
	// y = a*x + b
	//a               = 0.0882006     
	//b               = 7.73516   
	uint32_t dac_val;
	float a = 0.0882006, b = 7.73516; 

	dac_val = (uint32_t)(value - b)/a;

	dev_write(cfg_ptr, offset, dac_val);
	printf("The Voltage is: %d mV\n", value);
	printf("The DAC value is: %d DACs\n", dac_val);
}

float get_temp_AD592(uint32_t offset)
{
	float value;
	value = get_voltage(offset);
	return ((value*1000)-273.15);
}       

//System initialization
int init_system(void)
{
	uint32_t reg_val;

	//FIXME: replace hardcoded values for defines
	// set trigger_lvl_1
	dev_write(cfg_ptr,CFG_TRLVL_1_OFFSET,8190);

	// set trigger_lvl_2
	dev_write(cfg_ptr,CFG_TRLVL_2_OFFSET,8190);

	// set subtrigger_lvl_1
	dev_write(cfg_ptr,CFG_STRLVL_1_OFFSET,8190);

	// set subtrigger_lvl_2
	dev_write(cfg_ptr,CFG_STRLVL_2_OFFSET,8190);

	// set hv1 and hv2 to zero
	dev_write(cfg_ptr,CFG_HV1_OFFSET,0);
	dev_write(cfg_ptr,CFG_HV2_OFFSET,0);

	// reset ramp generators
	reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
	dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~8);

	// reset pps_gen, fifo and trigger modules
	reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
	dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~1);

	/* reset data converter and writer */
	reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
	dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~4);

	// enter reset mode for tlast_gen
	reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
	dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~2);

	// set number of samples
	dev_write(cfg_ptr,CFG_NSAMPLES_OFFSET, 1024 * 1024);

	// set default value for trigger scalers a and b
	dev_write(cfg_ptr,CFG_TR_SCAL_A_OFFSET, 1);
	dev_write(cfg_ptr,CFG_TR_SCAL_B_OFFSET, 1);

	// enter normal mode for tlast_gen
	/*        reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
	//printf("reg_val : 0x%08x\n",reg_val);
	dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 2);
	//printf("written reg_val tlast : 0x%08x\n",reg_val | 2);
	// enter normal mode for pps_gen, fifo and trigger modules
	reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
	//printf("reg_val : 0x%08x\n",reg_val);
	dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 1);
	//printf("written reg_val pps_gen, fifo : 0x%08x\n",reg_val | 1);
	*/
	// enable false GPS
	reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
	//printf("reg_val : 0x%08x\n",reg_val);
	dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | FGPS_EN_MASK);
	//printf("written reg_val : 0x%08x\n",reg_val | 16);
	// disable
	//dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~16);
	//dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~FGPS_EN_MASK);
	//printf("written reg_val : 0x%08x\n",reg_val & ~16);

	/*        // enter normal mode for data converter and writer
						reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
						dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 4);
	//printf("written reg_val : 0x%08hx\n",reg_val | 4);
	*/
	// enter normal mode for ramp generators
	reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
	dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 8);
	// enter in MASTER mode (default)
	reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
	dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 0x20);

	return 0;
}

int enable_interrupt(void)
{
	// steps to accept interrupts -> as pg. 26 of pg099-axi-intc.pdf
	//1) Each bit in the IER corresponding to an interrupt must be set to 1.
	dev_write(intc_ptr,XIL_AXI_INTC_IER_OFFSET, 1);
	//2) There are two bits in the MER. The ME bit must be set to enable the
	//interrupt request outputs.
	dev_write(intc_ptr,XIL_AXI_INTC_MER_OFFSET, XIL_AXI_INTC_MER_ME_MASK | XIL_AXI_INTC_MER_HIE_MASK);
	//dev_write(dev_ptr,XIL_AXI_INTC_MER_OFFSET, XIL_AXI_INTC_MER_ME_MASK);

	//The next block of code is to test interrupts by software
	//3) Software testing can now proceed by writing a 1 to any bit position
	//in the ISR that corresponds to an existing interrupt input.
	/*        dev_write(intc_ptr,XIL_AXI_INTC_IPR_OFFSET, 1);

						for(a=0; a<10; a++)
						{
						wait_for_interrupt(fd, dev_ptr);
						dev_write(dev_ptr,XIL_AXI_INTC_ISR_OFFSET, 1); //regenerate interrupt
						}
						*/
	return 0;

}

int disable_interrupt(void)
{
	uint32_t value;
	//Disable interrupt INTC0
	dev_write(intc_ptr,XIL_AXI_INTC_IER_OFFSET, 0);
	//disable IRQ
	value = dev_read(intc_ptr, XIL_AXI_INTC_MER_OFFSET);
	dev_write(intc_ptr,XIL_AXI_INTC_MER_OFFSET, value | ~1);
	//Acknowledge any previous interrupt
	dev_write(intc_ptr, XIL_AXI_INTC_IAR_OFFSET, 1);

	return 0;
}

