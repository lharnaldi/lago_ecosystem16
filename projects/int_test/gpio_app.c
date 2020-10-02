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


#define GPIO_MAP_SIZE 		0x1000
#define GPIO_DATA_OFFSET	0x00
#define GPIO_TRI_OFFSET		0x04
#define GPIO2_DATA_OFFSET	0x08
#define GPIO2_TRI_OFFSET	0x0C
#define GPIO_GLOBAL_IRQ		0x11C
#define GPIO_IRQ_CONTROL	0x128
#define GPIO_IRQ_STATUS		0x120

int interrupted = 0;

void signal_handler(int sig)
{
	interrupted = 1;
}

void gpio_write(void *gpio_base, unsigned int offset, unsigned int value)
{
	*((volatile unsigned *)(gpio_base + offset)) = value;
}

uint32_t gpio_read(void *gpio_base, unsigned int offset)
{
	return *((volatile unsigned *)(gpio_base + offset));
}

//uint8_t wait_for_interrupt(int fd_int, void *gpio_ptr) {
//	static unsigned int count = 0, bntd_flag = 0, bntu_flag = 0;
//	int flag_end=0;
//	int pending = 0;
//	int reenable = 1;
//	unsigned int reg;
//	unsigned int value;
//	// block (timeout for poll) on the file waiting for an interrupt 
//	struct pollfd fds = {
//		.fd = fd_int,
//		.events = POLLIN,
//	};
//
//	int ret = poll(&fds, 1, 100);
//	//    printf("ret is : %d\n", ret);
//	if (ret >= 1) {
//		read(fd_int, (void *)&reenable, sizeof(int));   // &reenable -> &pending
//		value = gpio_read(gpio_ptr, GPIO2_DATA_OFFSET);
//		if ((value & 0x00000001) != 0) {
//			printf("XXXX: Interrupt recieved\n");
//		}
//
//		//        count++;
//		//        usleep(50000); // anti rebond 
//		//        if(count == 10)
//		//            flag_end = 1;
//		// the interrupt occurred for the 1st GPIO channel so clear it 
//		reg = gpio_read(gpio_ptr, GPIO_IRQ_STATUS);
//		if (reg != 0)
//			gpio_write(gpio_ptr, GPIO_IRQ_STATUS, 2);
//		// re-enable the interrupt in the interrupt controller thru the 
//		// the UIO subsystem now that it's been handled 
//		write(fd_int, (void *)&reenable, sizeof(int));
//	}
//	return ret;
//}

//void wait_for_interrupt(int fd, void *gpio_ptr)
//{
//	int pending = 0;
//	int reenable = 1;
//	unsigned int reg;
//	int sum = 0, i;
//
//	// block on the file waiting for an interrupt */
//
//	read(fd, (void *)&pending, sizeof(int));
//
//	// the interrupt occurred for the 2nd GPIO channel so clear it
//
//	reg = gpio_read(gpio_ptr, GPIO_IRQ_STATUS);
//	if (reg){
//		printf("Interrupt Catched!!!\n");
//		//gpio_write(gpio_ptr, GPIO_IRQ_STATUS, 2);
//	}
//
//	// re-enable the interrupt in the interrupt controller thru the
//	// the UIO subsystem now that it's been handled
//
//	printf("XXX: Enabling interrupts\n");
//	write(fd, (void *)&reenable, sizeof(int));
//}
//
//uint32_t get_memory_size(char *sysfs_path_file)
//{
//	FILE *size_fp;
//	unsigned int size;
//
//	// open the file that describes the memory range size that is based on the
//	// reg property of the node in the device tree
//
//	size_fp = fopen(sysfs_path_file, "r");
//
//	if (!size_fp) {
//		printf("unable to open the uio size file\n");
//		exit(-1);
//	}
//
//	// get the size which is an ASCII string such as 0xXXXXXXXX and then be stop
//	// using the file
//
//	fscanf(size_fp, "0x%08X", &size);
//	fclose(size_fp);
//
//	return size;
//}
//
//void *thread_isr(void *p) 
//{
//	wait_for_interrupt(fd, gpio_ptr);
//
//}

int main(int argc, char *argv[])
{
	char *name = "/dev/mem";
	int fd;
	void *gpio_ptr;
	int gpio_size;
	int i, p=0;
	uint32_t value;
	uint32_t count = 0;
	int flag_end=0;
	//pthread_t t1;

	printf("GPIO UIO int test.\n");

	if((fd = open(name, O_RDWR)) < 0)
	{
		perror("open");
		return EXIT_FAILURE;
	}

	// open the UIO device file to allow access to the device in user space
	gpio_ptr = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40000000);
	if (gpio_ptr == MAP_FAILED) {
		printf("mmap call failure.\n");
		return -1;
	}

	signal(SIGINT, signal_handler);

	// make the GPIO bits to be outputs to drive the LEDs and the inputs from the switches

	gpio_write(gpio_ptr, GPIO_TRI_OFFSET, 0);
	gpio_write(gpio_ptr, GPIO2_TRI_OFFSET, 0xF);

	gpio_write(gpio_ptr, GPIO_DATA_OFFSET, 0xA);

	value = gpio_read(gpio_ptr, GPIO_DATA_OFFSET);
	printf("GPIO VALUE: %08d\n",value);

	// enable the interrupts from the GPIO

	gpio_write(gpio_ptr, GPIO_GLOBAL_IRQ, 0x80000000);
	gpio_write(gpio_ptr, GPIO_IRQ_CONTROL, 2);

	//pthread_create(&t1,NULL,thread_isr,NULL);
	// wait for interrupts from the GPIO

	while (!interrupted && !flag_end) {
		//value = gpio_read(gpio_ptr, GPIO_IRQ_STATUS);
	//	value = gpio_read(gpio_ptr, GPIO2_DATA_OFFSET);
	//	//printf("GPIO2 VALUE: %08d\n",value);
	//	if ((value & 0x00000001) != 0) {
	//		printf("XXXX: Interrupt recieved\n");
	//	}

		count++;
		usleep(200000); // anti rebond 
		if(count == 10)
			flag_end = 1;
		// the interrupt occurred for the 2nd GPIO channel so clear it 
		value = gpio_read(gpio_ptr, GPIO_IRQ_STATUS);
		printf("STATUS IRQ VALUE: %08d\n",value);
		if (value != 0){
			gpio_write(gpio_ptr, GPIO_IRQ_STATUS, 2);
			printf("XXXX: Interrupt recieved\n");
		}
		// re-enable the interrupt in the interrupt controller thru the 
		// the UIO subsystem now that it's been handled 
		//write(fd_int, (void *)&reenable, sizeof(int));
		//usleep(500000); // anti rebond 
		printf("CNTR: %d\n",count);

	}

	// unmap the GPIO device 
	munmap(gpio_ptr, sysconf(_SC_PAGESIZE));
	//munmap(gpio_ptr, gpio_size);

	return 0;
}
