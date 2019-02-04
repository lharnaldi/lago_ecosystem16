//Sacado de
//https://forum.digilentinc.com/topic/4750-how-to-detect-and-handle-uio-interrupt/
/* 
 * File:   main.c
 * Author: fss
 *
 * Created on August 23, 2017, 12:35 PM
 */
#include <sys/mman.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <poll.h>
#include <fcntl.h>
#include <errno.h>

#define GPIO_DATA_OFFSET 0x00 
#define GPIO_TRI_OFFSET 0x04 
#define GPIO_DATA2_OFFSET 0x08 
#define GPIO_TRI2_OFFSET 0x0C 
#define GPIO_GLOBAL_IRQ 0x11C 
#define GPIO_IRQ_CONTROL 0x128 
#define GPIO_IRQ_STATUS 0x120 

unsigned int get_memory_size(char *sysfs_path_file) { 
				FILE *size_fp; 
				unsigned int size; 
				// open the file that describes the memory range size that is based on the 
				// reg property of the node in the device tree 
				size_fp = fopen(sysfs_path_file, "r"); 
				if (size_fp == NULL) { 
								printf("unable to open the uio size file\n"); 
								exit(-1); 
				} 
				// get the size which is an ASCII string such as 0xXXXXXXXX and then be stop 
				// using the file 
				fscanf(size_fp, "0x%08X", &size); 
				fclose(size_fp); 
				return size; 
} 


void reg_write(void *reg_base, unsigned long offset, unsigned long value) { 
				*((volatile unsigned long *)(reg_base + offset)) = value; 
} 

unsigned long reg_read(void *reg_base, unsigned long offset) { 
				return *((volatile unsigned long *)(reg_base + offset)); 
} 

uint8_t wait_for_interrupt(int fd_int, void *gpio_ptr) { 
				static unsigned int count = 0, bntd_flag = 0, bntu_flag = 0; 
				int flag_end=0;
				int pending = 0; 
				int reenable = 1; 
				unsigned int reg; 
				unsigned int value; 
				// block (timeout for poll) on the file waiting for an interrupt 
				struct pollfd fds = {
								.fd = fd_int,
								.events = POLLIN,
				};

				int ret = poll(&fds, 1, 100);
				printf("ret is : %d\n", ret);
				if (ret >= 1) {
								read(fd_int, (void *)&reenable, sizeof(int));   // &reenable -> &pending
								// channel 1 reading 
								value = reg_read(gpio_ptr, GPIO_DATA2_OFFSET); 
								if ((value & 0x00000001) != 0) { 
												printf("Interrupt recieved");
								} 

								count++; 
								usleep(50000); // anti rebond 
								if(count == 10) 
												flag_end = 1; 
								// the interrupt occurred for the 1st GPIO channel so clear it 
								reg = reg_read(gpio_ptr, GPIO_IRQ_STATUS); 
								if (reg != 0) 
												reg_write(gpio_ptr, GPIO_IRQ_STATUS, 1);  
								// re-enable the interrupt in the interrupt controller thru the 
								// the UIO subsystem now that it's been handled 
								write(fd_int, (void *)&reenable, sizeof(int));
				} 
				return ret;
} 


int main(void){

				int fd = open("/dev/uio0", O_RDWR);
				if (fd < 0) {
								perror("open");
								exit(EXIT_FAILURE);
				}
				int gpio_size = get_memory_size("/sys/class/uio/uio0/maps/map0/size");
				/* mmap the UIO devices */
				void * ptr_axi_gpio = mmap(NULL, gpio_size, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);

				reg_write(ptr_axi_gpio,GPIO_TRI2_OFFSET ,0x1);
				reg_write(ptr_axi_gpio,GPIO_IRQ_CONTROL,0x2);
				//reg_write(ptr_axi_gpio,GPIO_GLOBAL_IRQ,0x1);
				reg_write(ptr_axi_gpio,GPIO_GLOBAL_IRQ,0x80000000);

				while (1) {
								wait_for_interrupt(fd,ptr_axi_gpio); 
				}

				close(fd);
				exit(EXIT_SUCCESS);
}
