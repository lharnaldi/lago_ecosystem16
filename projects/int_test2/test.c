/*Tomado de https://yurovsky.github.io/2014/10/10/linux-uio-gpio-interrupt.html*/

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <poll.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/mman.h>

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


inline void dev_write(void *dev_base, unsigned int offset, unsigned int value)
{
	*((volatile unsigned *)(dev_base + offset)) = value;
}

inline unsigned int dev_read(void *dev_base, unsigned int offset)
{
	return *((volatile unsigned *)(dev_base + offset));
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


int main(void)
{
	void *dev_ptr;
	int dev_size;
	int fd = open("/dev/uio0", O_RDWR);
	if (fd < 0) {
		perror("open");
		exit(EXIT_FAILURE);
	}
	dev_size = get_memory_size("/sys/class/uio/uio0/maps/map0/size");

	// mmap the INTC device into user space

	dev_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
	if (dev_ptr == MAP_FAILED) {
		printf("mmap call failure.\n");
		return -1;
	}


	//1) Each bit in the IER corresponding to an interrupt must be set to 1.
	dev_write(dev_ptr,XIL_AXI_INTC_IER_OFFSET, 1);
	//2) There are two bits in the MER. The ME bit must be set to enable the
	//interrupt request outputs.
	dev_write(dev_ptr,XIL_AXI_INTC_MER_OFFSET, XIL_AXI_INTC_MER_ME_MASK | XIL_AXI_INTC_MER_HIE_MASK);
	//        dev_write(dev_ptr,XIL_AXI_INTC_MER_OFFSET, XIL_AXI_INTC_MER_ME_MASK);
	//        dev_write(dev_ptr,XIL_AXI_INTC_IAR_OFFSET, 1);

	//The next block of code is to test interrupts by software
	//3) Software testing can now proceed by writing a 1 to any bit position
	//in the ISR that corresponds to an existing interrupt input.
	//dev_write(dev_ptr,XIL_AXI_INTC_ISR_OFFSET, 1);


	while (1) {
		uint32_t info = 1; /* unmask */

		ssize_t nb = write(fd, &info, sizeof(info));
		if (nb != (ssize_t)sizeof(info)) {
			perror("write");
			close(fd);
			exit(EXIT_FAILURE);
		}

		struct pollfd fds = {
			.fd = fd,
			.events = POLLIN,
		};

		int ret = poll(&fds, 1, 100);
		if (ret >= 1) {
			nb = read(fd, &info, sizeof(info));
			if (nb == (ssize_t)sizeof(info)) {
				/* Do something in response to the interrupt. */
				printf("Interrupt #%u!\n", info);
			}
		} else {
			perror("poll()");
			close(fd);
			exit(EXIT_FAILURE);
		}
	}

	close(fd);
	exit(EXIT_SUCCESS);
}
