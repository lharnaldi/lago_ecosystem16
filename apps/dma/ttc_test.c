/* 
 * PS TTC UIO User Space Driver Example
 *
 * The purpose of this user space driver is to illustrate using the UIO driver framework.
 * This used together with the UIO uio_pdrv_genirq device driver in the kernel. The device
 * tree node for the TTC must have "generic-uio" in the compatible list. 
 *
 * The uio_pdrv_genirq driver is a platform driver that also uses the device tree. For any
 * device tree nodes with "generic-uio" in the compatibility list, it will create a device
 * node, /dev/uioX, where X = 0, 1, 2... and then process the memory range and the interrupt
 * properties in the node. This will allow a user space driver to access the device memory 
 * and be notified of device interrupts.
 * 
 * No kernel space driver is required for this UIO user space driver.
 *
 * This application controls the PS TTC to enable the timer interrupt, start the timer,
 * and then handle the interrupt caused by the timer. The interrupt from the TTC is 
 * handled as an interrupt by the UIO kernel driver and then communicated to the user 
 * space application via the UIO file node.
 */

#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <fcntl.h>

static void *base_address;
#define TTC_COUNTER_CONTROL_REG_OFFSET	0xC
#define TTC_INTERRUPT_REG_OFFSET 	0x60
#define TTC_INTERRUPT_STATUS_REG_OFFSET	0x54

#define OVERFLOW_INTERRUPT_ENABLE	0x10
#define OVERFLOW_INTERRUPT_DISABLE	0
#define START_TIMER			0x20
#define STOP_TIMER			0x21

/* The following functions alter the registers of the PS TTC to allow it to be controlled */

inline void disable_interrupt()
{
	*((volatile unsigned *)(base_address + TTC_INTERRUPT_REG_OFFSET)) = OVERFLOW_INTERRUPT_DISABLE;
}
inline void enable_interrupt() 
{
	*((volatile unsigned *)(base_address + TTC_INTERRUPT_REG_OFFSET)) = OVERFLOW_INTERRUPT_ENABLE;
}

inline void clear_interrupt()
{
	*((volatile unsigned *)(base_address + TTC_INTERRUPT_STATUS_REG_OFFSET));
}
inline void start_timer()
{
	*((volatile unsigned *)(base_address + TTC_COUNTER_CONTROL_REG_OFFSET)) = START_TIMER;
}
inline void stop_timer()
{
	*((volatile unsigned *)(base_address + TTC_COUNTER_CONTROL_REG_OFFSET)) = STOP_TIMER;
}

#define data_memory_barrier() __asm__ __volatile__ ("dmb" : : : "memory")

void wait_for_interrupt(int fd) 
{
	int pending = 0;
	int reenable = 1;

	/* Step 5, block on the file waiting for an interrupt */

	read(fd, (void *)&pending, sizeof(int));

	/* the interrupt occurred so stop the timer and clear the interrupt and then
	 * wait til those are done before re-enabling the interrupt
	 */
	stop_timer();
	clear_interrupt();
	data_memory_barrier();

	/* Step 6, re-enable the interrupt again now that it's been handled */
	
	write(fd, (void *)&reenable, sizeof(int));
}

unsigned int get_memory_size()
{
	FILE *size_fp;
	unsigned int size;

	/* Step 2, open the file that describes the memory range needed to map the TTC into
	 * this address space, this is the range of the TTC in the device tree
	 */
	size_fp = fopen("/sys/class/uio/uio0/maps/map0/size", "r");

	if (!size_fp) {
		printf("unable to open the uio size file\n");
		exit(-1);
	}

	/* Step 3, get the size which is an ASCII string such as 0xXXXXXXXX and then be stop
	 * using the file 
	 */

	fscanf(size_fp, "0x%08X", &size);
	fclose(size_fp);

	return size;
}

int main(int argc, char *argv[])
{
	int fd;
	unsigned int size;
	
	printf("PSTTC UIO test\n");

	/* Step 1, open the UIO device file to allow access to control the device */

	fd = open("/dev/uio0", O_RDWR);

	if (fd < 1) {
		printf("Unable to open UIO device file");
		return -1;
	}

	size = get_memory_size();

	/* Step 4, map the device memory into the process address space so that it can be
 	 * accessed
 	 */

	base_address = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	
	/* exercise the TTC to show that it can be controlled by enabling the 
	 * interrupt and starting the timer counter
	 */
	enable_interrupt();
	start_timer();
	printf("started the timer, waiting for the interrupt\n");
			
	/* process the TTC interrupt seperately as this processing could be done
	 * in a seperate thread to allow more parallelism
	 */
	wait_for_interrupt(fd); 
	printf("interrupt complete\n");

	/* Step 7, clean up by unmapping the TTC from the process address space and stop using
	 * the UIO device
	 */

	munmap(base_address, size);
	close(fd);

	return 0;
}
