#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <sys/mman.h>
#include <fcntl.h>

int interrupted = 0;

void signal_handler(int sig)
{
	interrupted = 1;
}

int main()
{
	int fd, i;
	int position, limit, offset;
	int16_t value[2];
	void *cfg, *ram, *sts;
	char *name = "/dev/mem";

	if((fd = open(name, O_RDWR)) < 0)
	{
		perror("open");
		return 1;
	}

	cfg = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40001000);
	sts = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40002000);
	ram = mmap(NULL, 2*sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40003000);

	/* enter reset mode */
	*((uint32_t *)(cfg + 0)) &= ~3;
	// set counter number
	*((uint32_t *)(cfg + 4)) = 1024-1;
	/* enter normal operating mode */
	*((uint32_t *)(cfg + 0)) |= 3;

	signal(SIGINT, signal_handler);

	limit = 512;
	printf("Pasamos...")

	while(!interrupted)
	{
		/* read ram writer position */
		position = *((uint32_t *)(sts + 0));

		/* send 4096 bytes if ready, otherwise sleep 0.1 ms */
		if((limit > 0 && position > limit) || (limit == 0 && position < 512))
		{
			offset = limit > 0 ? 0 : 4096;
			limit = limit > 0 ? 0 : 512;
			// print IN1 and IN2 samples
			for(i = 0; i < 1024; ++i)
			{
				value[0] = *((int16_t *)(ram + 4*i + 0));
				value[1] = *((int16_t *)(ram + 4*i + 2));
				printf("%5d %5d\n", value[0], value[1]);
			}
			//if(send(sockClient, ram + offset, 4096, MSG_NOSIGNAL) < 0) break;
		}
		else
		{
			usleep(100);
		}

	}

	munmap(cfg, sysconf(_SC_PAGESIZE));
	munmap(sts, sysconf(_SC_PAGESIZE));
	munmap(ram, sysconf(_SC_PAGESIZE));

	return 0;
}
