#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/mman.h>

int interrupted = 0;

void signal_handler(int sig)
{
	interrupted = 1;
}

int main()
{
	int fd, i;
	int position=0, limit, offset;
	int32_t value[2];
	void *cfg, *sts, *ram;
	uint32_t wo;
	const int COPY_BYTES = 4*16*1024;
	const int num_word = COPY_BYTES / 4;
	int32_t buf_o[num_word], buf_i[num_word];

	if((fd = open("/dev/mem", O_RDWR)) < 0)
	{
		perror("open");
		return 1;
	}

	cfg = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40001000);
	sts = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40002000);
	ram = mmap(NULL, 16*sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40010000);
	//printf("%d\n",sysconf(_SC_PAGESIZE));

	signal(SIGINT, signal_handler);

	limit = 5000000-2;

	/* enter reset mode */
	*((uint32_t *)(cfg + 0)) &= ~2;
	usleep(100);
	//*((uint32_t *)(cfg + 0)) &= ~1;
	// set counter number
	//*((uint32_t *)(cfg + 4)) = 4096-1;
	// set number  of samples in histogramer
	*((uint32_t *)(cfg + 8)) = limit+1;
	*((uint32_t *)(cfg + 16)) = 10;
	/* enter normal operating mode */
	*((uint32_t *)(cfg + 0)) |= 2;

	while(!interrupted && position < limit)
	{
		/* read writer position */
		position = *((uint32_t *)(sts + 0));
		//printf("POS: %5d\n", position);

		/* print 16384 samples if ready, otherwise sleep 1 us */
		if((position >= limit))
		{
			memcpy(buf_i,ram,COPY_BYTES); //copy bytes from BRAM
			for(i = 0; i < num_word; ++i)
			{
				buf_o[i] = buf_i[i];
				printf("%d\n",(int16_t *)buf_o[i]);
				//wo = (uint32_t *)(buf_o[i]);
				//printf("%5d\n", wo);
			}
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

