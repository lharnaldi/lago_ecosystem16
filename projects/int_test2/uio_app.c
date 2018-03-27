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


#define XIL_AXI_INTC_BASEADDR 0x40000000
#define XIL_AXI_INTC_HIGHADDR 0x40000FFF

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

//#define XIL_AXI_INTC_IPISR_INT_OCCURED_MASK 0x00000001
//#define XIL_AXI_INTC2_IPISR_INT_OCCURED_MASK  0x00000002
//#define XIL_AXI_INTC_GIER_ENABLE_INT_MASK 0x80000000
//
//#define XIL_AXI_INTC_CSR_CASC_MASK    0x00000800
//#define XIL_AXI_INTC_CSR_ENABLE_ALL_MASK  0x00000400
//#define XIL_AXI_INTC_CSR_ENABLE_PWM_MASK  0x00000200
//#define XIL_AXI_INTC_CSR_ENABLE_TMR_MASK  0x00000080
//#define XIL_AXI_INTC_CSR_ENABLE_INT_MASK  0x00000040
//#define XIL_AXI_INTC_CSR_LOAD_MASK    0x00000020
//#define XIL_AXI_INTC_CSR_AUTO_RELOAD_MASK 0x00000010
//#define XIL_AXI_INTC_CSR_EXT_CAPTURE_MASK 0x00000008
//#define XIL_AXI_INTC_CSR_EXT_GENERATE_MASK  0x00000004
//#define XIL_AXI_INTC_CSR_DOWN_COUNT_MASK  0x00000002
//#define XIL_AXI_INTC_CSR_CAPTURE_MODE_MASK  0x00000001


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

int wait_for_interrupt(int fd_int, void *dev_ptr) {
				static unsigned int count = 0, bntd_flag = 0, bntu_flag = 0;
				int flag_end=0;
				int pending = 0;
				int reenable = 1;
				unsigned int reg;
				unsigned int value;
				uint32_t info = 1; /* unmask */

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
												/* Do something in response to the interrupt. */
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
}

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

//void *thread_isr(void *p) 
//{
//  wait_for_interrupt(fd, dev_ptr);
//
//}

int main(int argc, char *argv[])
{
				int fd;
				char *uiod = "/dev/uio0";
				void *dev_ptr;
				int dev_size;
				int ocm_size;
				int i, p=0,a;
				unsigned int val;
				pthread_t t1;


				signal(SIGINT, signal_handler);

				printf("INTC UIO int test.\n");

				// open the UIO device file to allow access to the device in user space

				fd = open(uiod, O_RDWR);
				if (fd < 1) {
								printf("Invalid UIO device file:%s.\n", uiod);
								return -1;
				}

				dev_size = get_memory_size("/sys/class/uio/uio0/maps/map0/size");

				// mmap the INTC device into user space

				dev_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
				if (dev_ptr == MAP_FAILED) {
								printf("mmap call failure.\n");
								return -1;
				}

				// steps to accept interrupts -> as pg. 26 of pg099-axi-intc.pdf
				//1) Each bit in the IER corresponding to an interrupt must be set to 1.
				dev_write(dev_ptr,XIL_AXI_INTC_IER_OFFSET, 1);
				//2) There are two bits in the MER. The ME bit must be set to enable the
				//interrupt request outputs.
				dev_write(dev_ptr,XIL_AXI_INTC_MER_OFFSET, XIL_AXI_INTC_MER_ME_MASK | XIL_AXI_INTC_MER_HIE_MASK);
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

				while(!interrupted) wait_for_interrupt(fd, dev_ptr);

				printf("\n\n\n");
				printf("STS: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_ISR_OFFSET));
				printf("IPR: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_IPR_OFFSET));
				printf("IER: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_IER_OFFSET));
				printf("IAR: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_IAR_OFFSET));
				printf("SIE: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_SIE_OFFSET));
				printf("CIE: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_CIE_OFFSET));
				printf("IVR: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_IVR_OFFSET));
				printf("MER: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_MER_OFFSET));
				printf("IMR: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_IMR_OFFSET));
				printf("ILR: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_ILR_OFFSET));
				printf("IVAR: 0x%08d\n",dev_read(dev_ptr, XIL_AXI_INTC_IVAR_OFFSET));

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
