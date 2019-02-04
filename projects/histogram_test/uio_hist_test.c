#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
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

int cfg_init(void)
{
	char *uiod = "/dev/uio1";

	//printf("Initializing CFG device...\n");

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

int init_system(void)
{
	uint32_t reg_val;

	// reset counter
	reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
	dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~1);

	// enter reset mode for hist
	reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
	dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~2);

	// enter reset mode for BRAM reader
	reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
	dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~3);

	// enter reset mode for writer
	reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
	dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~4);

	// set counter count value
	dev_write(cfg_ptr,CFG_CNTR_COUNT_OFFSET,16384);

	// set number of samples to acquire
	dev_write(cfg_ptr,CFG_NSAMPLES_OFFSET, 16384);

	// enter normal mode for writer
	reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
	dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 4);

	// enter normal mode for BRAM reader
	reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
	dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 3);

	// enter normal mode for hist
	reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
	dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 2);

	// enter normal mode for counter
	reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
	dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 1);

	return 0;
}

int main()
{
	int16_t ch[2];
	uint32_t i;

	mem_init();
	//        intc_init();    
	cfg_init();

	init_system();

	// wait 1 second
	sleep(1);

	for(i = 0; i < 16384; i+=4) {
		ch[0] = *((int16_t *)(mem_ptr + i + 0));
		ch[1] = *((int16_t *)(mem_ptr + i + 2));
		printf("%5d %5d\n", ch[0], ch[1]);
	}

	munmap(cfg_ptr, sysconf(_SC_PAGESIZE));
	munmap(mem_ptr, sysconf(_SC_PAGESIZE));

	close(cfg_fd);

	return 0;
}

/*int main()
  {
  int fd, i;
  int16_t value[2];
  void *cfg, *ram;
  char *name = "/dev/mem";

  if((fd = open(name, O_RDWR)) < 0)
  {
  perror("open");
  return 1;
  }

  cfg = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40001000);
  ram = mmap(NULL, 1024*sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x1E000000);

// reset counter
 *((uint32_t *)(cfg + 0)) &= ~1;

// reset hist_0
 *((uint32_t *)(cfg + 0)) &= ~2;

// reset BRAM reader
 *((uint32_t *)(cfg + 0)) &= ~3;

// reset writer
 *((uint32_t *)(cfg + 0)) &= ~4;

// wait 1 second
//sleep(1);

// enter reset mode for packetizer
// *((uint32_t *)(cfg + 0)) &= ~2;

// set counter number
 *((uint32_t *)(cfg + 4)) = 1024;

// set number of samples to acquire
 *((uint32_t *)(cfg + 8)) = 1024 * 1024 -1; //16384;

// enter normal mode
 *((uint32_t *)(cfg + 0)) |= 4;
 *((uint32_t *)(cfg + 0)) |= 3;
 *((uint32_t *)(cfg + 0)) |= 2;
 *((uint32_t *)(cfg + 0)) |= 1;

// wait 1 second
sleep(1);

// print IN1 and IN2 samples
for(i = 0; i < 1024 * 1024; ++i)
{
value[0] = *((int16_t *)(ram + 4*i + 0));
value[1] = *((int16_t *)(ram + 4*i + 2));
printf("%5d %5d\n", value[0], value[1]);
}

munmap(cfg, sysconf(_SC_PAGESIZE));
munmap(ram, sysconf(_SC_PAGESIZE));

return 0;
}*/
