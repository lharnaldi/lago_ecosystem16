#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <poll.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>

//See page 17 of PG091
#define XADC_SRR_OFFSET          0x00	//Software reset register
#define XADC_SR_OFFSET           0x04	//Status Register
#define XADC_AOSR_OFFSET         0x08	//Alarm Out Status Register
#define XADC_CONVSTR_OFFSET      0x0C	//CONVST Register
#define XADC_SYSMONRR_OFFSET     0x10	//XADC Reset Register
#define XADC_GIER_OFFSET         0x5C	//Global Interrupt Enable Register
#define XADC_IPISR_OFFSET        0x60	//IP Interrupt Status Register
#define XADC_IPIER_OFFSET        0x68	//IP Interrupt Enable Register
#define XADC_TEMPERATURE_OFFSET  0x200	//Temperature
#define XADC_VCCINT_OFFSET       0x204	//VCCINT
#define XADC_VCCAUX_OFFSET       0x208	//VCCAUX
#define XADC_VPVN_OFFSET         0x20C	//VP/VN
#define XADC_VREFP_OFFSET        0x210	//VREFP
#define XADC_VREFN_OFFSET        0x214	//VREFN
#define XADC_VBRAM_OFFSET        0x218	//VBRAM
#define XADC_UNDEF_OFFSET        0x21C	//Undefined
#define XADC_SPLYOFF_OFFSET      0x220	//Supply Offset
#define XADC_ADCOFF_OFFSET       0x224	//ADC Offset
#define XADC_GAIN_ERR_OFFSET     0x228	//Gain Error
#define XADC_ZDC_SPLY_OFFSET     0x234	//Zynq-7000 Device Core Supply
#define XADC_ZDC_AUX_SPLY_OFFSET 0x238	//Zynq-7000 Device Core Aux Supply
#define XADC_ZDC_MEM_SPLY_OFFSET 0x23C	//Zynq-7000 Device Core Memory Supply
#define XADC_VAUX_PN_0_OFFSET    0x240	//VAUXP[0]/VAUXN[0]
#define XADC_VAUX_PN_1_OFFSET    0x244	//VAUXP[1]/VAUXN[1]
#define XADC_VAUX_PN_2_OFFSET    0x248	//VAUXP[2]/VAUXN[2]
#define XADC_VAUX_PN_3_OFFSET    0x24C	//VAUXP[3]/VAUXN[3]
#define XADC_VAUX_PN_4_OFFSET    0x250	//VAUXP[4]/VAUXN[4]
#define XADC_VAUX_PN_5_OFFSET    0x254	//VAUXP[5]/VAUXN[5]
#define XADC_VAUX_PN_6_OFFSET    0x258	//VAUXP[6]/VAUXN[6]
#define XADC_VAUX_PN_7_OFFSET    0x25C	//VAUXP[7]/VAUXN[7]
#define XADC_VAUX_PN_8_OFFSET    0x260	//VAUXP[8]/VAUXN[8]
#define XADC_VAUX_PN_9_OFFSET    0x264	//VAUXP[9]/VAUXN[9]
#define XADC_VAUX_PN_10_OFFSET   0x268	//VAUXP[10]/VAUXN[10]
#define XADC_VAUX_PN_11_OFFSET   0x26C	//VAUXP[11]/VAUXN[11]
#define XADC_VAUX_PN_12_OFFSET   0x270	//VAUXP[12]/VAUXN[12]
#define XADC_VAUX_PN_13_OFFSET   0x274	//VAUXP[13]/VAUXN[13]
#define XADC_VAUX_PN_14_OFFSET   0x278	//VAUXP[14]/VAUXN[14]
#define XADC_VAUX_PN_15_OFFSET   0x27C	//VAUXP[15]/VAUXN[15]

#define XADC_AI0_OFFSET XADC_VAUX_PN_8_OFFSET
#define XADC_AI1_OFFSET XADC_VAUX_PN_0_OFFSET
#define XADC_AI2_OFFSET XADC_VAUX_PN_1_OFFSET
#define XADC_AI3_OFFSET XADC_VAUX_PN_9_OFFSET

#define XADC_CONV_VAL 0.00171191993362
#define XADC_RDIV_VAL 1.798     //voltage divisor in board (15k+16.983k)/16.983k

int interrupted = 0;

void signal_handler(int sig)
{
	interrupted = 1;
}

inline void dev_write(void *dev_base, unsigned int offset, unsigned int value)
{
	*((volatile unsigned *)(dev_base + offset)) = value;
}

inline unsigned int dev_read(void *dev_base, unsigned int offset)
{
	return *((volatile unsigned *)(dev_base + offset));
}

/*int wait_for_interrupt(int fd_int, void *dev_ptr) 
  {
  static unsigned int count = 0, bntd_flag = 0, bntu_flag = 0;
  int flag_end=0;
  int pending = 0;
  int reenable = 1;
  unsigned int reg;
  unsigned int value;
  uint32_t info = 1; // unmask

  ssize_t nb = write(fd_int, &info, sizeof(info));
  if (nb != (ssize_t)sizeof(info)) {
  perror("write");
  close(fd_int);
  exit(EXIT_FAILURE);
  }

// block (timeout for poll) on the file waiting for an interrupt 
struct pollfd fds = {
.fd = fd_int,
.events = POLLIN,
};

int ret = poll(&fds, 1, 8000);
printf("ret is : %d\n", ret);
if (ret >= 1) {
nb = read(fd_int, &info, sizeof(info));
if (nb == (ssize_t)sizeof(info)) {
// Do something in response to the interrupt. 
value = dev_read(dev_ptr, XIL_AXI_INTC_IPR_OFFSET);
if ((value & 0x00000001) != 0) {
dev_write(dev_ptr, XIL_AXI_INTC_IAR_OFFSET, 1);
printf("Interrupt #%u!\n", info);
}
} else {
perror("poll()");
close(fd_int);
exit(EXIT_FAILURE);
}
}

return ret;
}*/

unsigned int get_memory_size(char *sysfs_path_file)
{
	FILE *size_fp;
	unsigned int size;

	// open the file that describes the memory range size that is based on the
	// reg property of the node in the device tree

	size_fp = fopen(sysfs_path_file, "r");

	if (!size_fp) {
		printf("unable to open the uio size file\n");
		exit(-1);
	}

	// get the size which is an ASCII string such as 0xXXXXXXXX and then be stop
	// using the file

	fscanf(size_fp, "0x%08X", &size);
	fclose(size_fp);

	return size;
}

/*void *thread_isr(void *p) 
  {
  wait_for_interrupt(fd, dev_ptr);

  }*/

int main(int argc, char *argv[])
{
	int fd;
	char *uiod = "/dev/uio3";
	void *dev_ptr;
	int dev_size;
	int ocm_size;
	int i, p=0,a;
	unsigned int val;
	int16_t value;  
	float rvalue;
	pthread_t t1;


	signal(SIGINT, signal_handler);

	printf("INTC UIO int test.\n");

	// open the UIO device file to allow access to the device in user space

	fd = open(uiod, O_RDWR);
	if (fd < 1) {
		printf("Invalid UIO device file:%s.\n", uiod);
		return -1;
	}

	dev_size = get_memory_size("/sys/class/uio/uio3/maps/map0/size");

	// mmap the INTC device into user space

	dev_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
	if (dev_ptr == MAP_FAILED) {
		printf("mmap call failure.\n");
		return -1;
	}

	value = (int16_t) dev_read(dev_ptr, XADC_AI0_OFFSET);
	printf("The Voltage at pin AI0 is: %lf V\n", (value>>4)*XADC_CONV_VAL*XADC_RDIV_VAL);
	value = (int16_t) dev_read(dev_ptr, XADC_AI1_OFFSET);
	printf("The Voltage at pin AI1 is: %lf V\n", (value>>4)*XADC_CONV_VAL*XADC_RDIV_VAL);
	value = (int16_t) dev_read(dev_ptr, XADC_AI2_OFFSET);
	printf("The Voltage at pin AI2 is: %lf V\n", (value>>4)*XADC_CONV_VAL*XADC_RDIV_VAL);
	value = (int16_t) dev_read(dev_ptr, XADC_AI3_OFFSET);
	printf("The Voltage at pin AI3 is: %lf V\n", (value>>4)*XADC_CONV_VAL*XADC_RDIV_VAL);

	//Temperature read
	value = (uint16_t) dev_read(dev_ptr, XADC_TEMPERATURE_OFFSET);
	printf("The internal temperature is: %lf degC\n", (((value>>4)*503.975)/65536) - 273.15);
	printf("The internal temperature is: %d degC\n", (value>>4));

	//Supply coefficient offset
	value = (int16_t) dev_read(dev_ptr, XADC_SPLYOFF_OFFSET);
	printf("The supply coeff. offset is: %04x \n", value);
	//VCCINT read
	value = (int16_t) dev_read(dev_ptr, XADC_VPVN_OFFSET);
	printf("The internal VCCINT is: %lf V\n", (((value>>4))/4096)*3.0);
	// steps to accept interrupts -> as pg. 26 of pg099-axi-intc.pdf
	//1) Each bit in the IER corresponding to an interrupt must be set to 1.
	//dev_write(dev_ptr,XIL_AXI_INTC_IER_OFFSET, 1);
	//2) There are two bits in the MER. The ME bit must be set to enable the
	//interrupt request outputs.
	//dev_write(dev_ptr,XIL_AXI_INTC_MER_OFFSET, XIL_AXI_INTC_MER_ME_MASK | XIL_AXI_INTC_MER_HIE_MASK);
	//				dev_write(dev_ptr,XIL_AXI_INTC_MER_OFFSET, XIL_AXI_INTC_MER_ME_MASK);

	//The next block of code is to test interrupts by software
	//3) Software testing can now proceed by writing a 1 to any bit position
	//in the ISR that corresponds to an existing interrupt input.
	//       dev_write(dev_ptr,XIL_AXI_INTC_ISR_OFFSET, 1);

	//        for(a=0; a<10; a++)
	//        {
	//         wait_for_interrupt(fd, dev_ptr);
	//         dev_write(dev_ptr,XIL_AXI_INTC_ISR_OFFSET, 1); //regenerate interrupt
	//        }
	//
	//

	//while(!interrupted) wait_for_interrupt(fd, dev_ptr);

	//				printf("\n\n\n");
	//				printf("STS: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_ISR_OFFSET));
	//				printf("IPR: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_IPR_OFFSET));
	//				printf("IER: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_IER_OFFSET));
	//				printf("IAR: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_IAR_OFFSET));
	//				printf("SIE: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_SIE_OFFSET));
	//				printf("CIE: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_CIE_OFFSET));
	//				printf("IVR: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_IVR_OFFSET));
	//				printf("MER: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_MER_OFFSET));
	//				printf("IMR: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_IMR_OFFSET));
	//				printf("ILR: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_ILR_OFFSET));
	//				printf("IVAR: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_IVAR_OFFSET));

	//				dev_write(dev_ptr, INTC_TRI_OFFSET, 0);
	//				dev_write(dev_ptr, INTC_TRI2_OFFSET, 0xF);
	//
	//				// enable the interrupts from the INTC
	//
	//				dev_write(dev_ptr, INTC_GLOBAL_IRQ, 0x80000000);
	//				dev_write(dev_ptr, INTC_IRQ_CONTROL, 2);
	//
	//        pthread_create(&t1,NULL,thread_isr,NULL);
	//				// wait for interrupts from the INTC
	//
	//				while (!interrupted) {
	//								
	//				}
	//
	//				// unmap the INTC device 

	munmap(dev_ptr, dev_size);
	close(fd);

	return 0;
}
