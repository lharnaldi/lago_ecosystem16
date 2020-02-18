#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <fcntl.h>

#include "zynq_io.h"

int intc_fd, cfg_fd, sts_fd, xadc_fd, mem_fd;
void *intc_ptr, *cfg_ptr, *sts_ptr, *xadc_ptr, *mem_ptr;
int dev_size;

void dev_write(void *dev_base, uint32_t offset, int32_t value)
{
				*((volatile unsigned *)(dev_base + offset)) = value;
}

uint32_t dev_read(void *dev_base, uint32_t offset)
{
				return *((volatile unsigned *)(dev_base + offset));
}

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
				char *uiod = "/dev/uio0";

				//printf("Initializing INTC device...\n");

				// open the UIO device file to allow access to the device in user space
				intc_fd = open(uiod, O_RDWR);
				if (intc_fd < 1) {
								printf("intc_init: Invalid UIO device file:%s.\n", uiod);
								return -1;
				}

				dev_size = get_memory_size("/sys/class/uio/uio0/maps/map0/size"); 

				// mmap the INTC device into user space
				intc_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, intc_fd, 0);
				if (intc_ptr == MAP_FAILED) {
								printf("intc_init: mmap call failure.\n");
								return -1;
				}

				return 0;
}

int cfg_init(void)
{
				char *uiod = "/dev/uio0";

				printf("Initializing CFG device...\n");

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
}

int sts_init(void)
{
				char *uiod = "/dev/uio2";

				//printf("Initializing STS device...\n");

				// open the UIO device file to allow access to the device in user space
				sts_fd = open(uiod, O_RDWR);
				if (sts_fd < 1) {
								printf("sts_init: Invalid UIO device file:%s.\n", uiod);
								return -1;
				}

				dev_size = get_memory_size("/sys/class/uio/uio2/maps/map0/size");

				// mmap the STS device into user space
				sts_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, sts_fd, 0);
				if (sts_ptr == MAP_FAILED) {
								printf("sts_init: mmap call failure.\n");
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

				//dev_size = 2048*sysconf(_SC_PAGESIZE);
				dev_size = 1024*sysconf(_SC_PAGESIZE);

				// mmap the mem device into user space 
				mem_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, mem_fd, 0x1E000000);
				if (mem_ptr == MAP_FAILED) {
								printf("mem_init: mmap call failure.\n");
								return -1;
				}

				return 0;
}

//System initialization
int init_system(void)
{
				uint32_t reg_val;

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

int main(int argc, char *argv[])
{
				//int fd;
				//unsigned int size;
				uint32_t i,val=0;
				uint32_t wo;
				int16_t ch[2];

				printf("CFG UIO test\n");

				//initialize devices. TODO: add error checking 
				mem_init();
				//intc_init();
				cfg_init();    
				//sts_init();
				//xadc_init();

				// reset writer
				//*((uint32_t *)(cfg + 0)) &= ~4;
				printf("Reseting writer...\n");
				val=rd_reg_value(1, CFG_RESET_GRAL_OFFSET);
				wr_reg_value(1, CFG_RESET_GRAL_OFFSET, val &= ~4);
				//*((uint32_t *)(cfg + 0)) |= 4;
				val=rd_reg_value(1, CFG_RESET_GRAL_OFFSET);
				wr_reg_value(1, CFG_RESET_GRAL_OFFSET, val |= 4);
				printf("Reseting writer %d ...\n",val);
				printf("Reseting fifo and filters...\n");
				// reset fifo and filters
				//*((uint32_t *)(cfg + 0)) &= ~1;
				val=rd_reg_value(1, CFG_RESET_GRAL_OFFSET);
				wr_reg_value(1, CFG_RESET_GRAL_OFFSET, val &=~1);
				//*((uint32_t *)(cfg + 0)) |= 1;
				val=rd_reg_value(1, CFG_RESET_GRAL_OFFSET);
				wr_reg_value(1, CFG_RESET_GRAL_OFFSET, val |=1);
				printf("Reseting fifo and filters %d ...\n",val);

				// wait 1 second
				sleep(1);

				printf("Reseting packetizer...\n");
				// enter reset mode for packetizer
				//*((uint32_t *)(cfg + 0)) &= ~2; 
				val=rd_reg_value(1, CFG_RESET_GRAL_OFFSET);
				wr_reg_value(1, CFG_RESET_GRAL_OFFSET, val &=~2);

				// set number of samples
				//*((uint32_t *)(cfg + 4)) = 1024 * 1024 - 1;
				wr_reg_value(1, CFG_NSAMPLES_OFFSET, 1024 * 1024 - 1);

				// enter normal mode
				//*((uint32_t *)(cfg + 0)) |= 2;
				val=rd_reg_value(1, CFG_RESET_GRAL_OFFSET);
				wr_reg_value(1, CFG_RESET_GRAL_OFFSET, val |=2);
				printf("Reseting packetizer %d ...\n",val);

				// wait 1 second
				sleep(1);

				// print IN1 and IN2 samples
				for(i = 0; i < 1024 * 1024; ++i){
								ch[0] = *((int16_t *)(mem_ptr + 4*i + 0));
								ch[1] = *((int16_t *)(mem_ptr + 4*i + 2));
								wo = *((uint32_t *)(mem_ptr + i));
								printf("%5d %5d %10d\n", ch[0], ch[1], wo);
				}

				// unmap and close the devices 
				//munmap(intc_ptr, sysconf(_SC_PAGESIZE));
				munmap(cfg_ptr, sysconf(_SC_PAGESIZE));
				//munmap(sts_ptr, sysconf(_SC_PAGESIZE));
				//munmap(xadc_ptr, sysconf(_SC_PAGESIZE));
				munmap(mem_ptr, sysconf(_SC_PAGESIZE));

				//close(intc_fd);
				close(cfg_fd);
				//close(sts_fd);
				//close(xadc_fd);

				return 0;

}
