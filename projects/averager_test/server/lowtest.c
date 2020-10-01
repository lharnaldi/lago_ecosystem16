#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <time.h>

int interrupted = 0;

void signal_handler(int sig)
{
	interrupted = 1;
}

int main()
{
	int fd, i, j;
	uint32_t naverages=0, nsamples=0, timing=0;
	uint32_t position=0, limit, offset;
	int32_t value[2];
	void *cfg, *sts, *ram;
	uint32_t wo;
	const int COPY_BYTES = 4*16*1024;//BRAM size
	const int num_word = COPY_BYTES / 4;
	int32_t buf_o[num_word], buf_i[num_word];
	uint32_t buffer[num_word];
	clock_t time_begin;
	double time_spent;
	int measuring = 0;
	int cnt=0;

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

	//limit = 5000000-2;
	nsamples =12;
	naverages=5;

	/* enter reset mode */
	//*((uint32_t *)(cfg + 0)) &= ~2;
	//*((uint32_t *)(cfg + 0)) &= ~4;
	//usleep(100);
	//// set number of samples 
	//*((uint32_t *)(cfg + 8)) = nsamples;
	//// set number of averages 
	//*((uint32_t *)(cfg + 4)) = naverages;
	//// set trigger time 
	//*((uint32_t *)(cfg + 12)) = 125000; //1 second = 8ns*125e6
	///* enter normal operating mode */
	//*((uint32_t *)(cfg + 0)) |= 2;

	//time_begin = clock();
	///* enable measurement/enable trigger */
	//*((uint32_t *)(cfg + 0)) |= 4;

	//while(cnt<=100)
	//while(1)
	//{
		//position = *((uint32_t *)(sts + 4));
		//printf("POS: %5d \n",position&1);
		//printf("POS: %08x\n",position & 0x1);

		//position = *((uint32_t *)(sts + 0));
		//printf("CNTR: %5d \n",position);
		//printf("CNTR: %08x\n",position );
		/* Check if it is in measuring mode and has finished */
//		if ((*((uint32_t *)(sts + 4)) & 1) != 0)
//		{
//		position = *((uint32_t *)(sts + 4));
//		printf("POS: %5d\n",position);
//	//		time_spent = ((double)(clock() - time_begin)) / CLOCKS_PER_SEC; // measure time
		memcpy(buf_i,ram,COPY_BYTES); //copy bytes from BRAM
		for(i = 0; i < nsamples; ++i)
		{
			buf_o[i] = buf_i[i];
			printf("%d\n",(int16_t *)buf_o[i]);
//	//			//wo = (uint32_t *)(buf_o[i]);
//	//			//printf("%5d\n", wo);
			}
//			/* transfer all samples */
//			//nsmpl = (1<<nsamples);
//			//for(j = 0; j < nsmpl; ++j)
//			//for(j = 0; j < nsamples; ++j)
//			//{
//			//	buffer[j] = (*((uint32_t *)(ram + 4*j)));
//			//	printf("%d\n",(int32_t *)buffer[j]);
//			//}
//
//			//send(sock_client, buffer, 4*nsmpl, MSG_NOSIGNAL);
//			//printf("%d samples measured in %f s\n", nsmpl, time_spent);
//			printf("%d samples measured in %f s\n", nsamples, time_spent);
//			//measuring = 0;
//			break;
//		}
//		++cnt;
//	}

	//while(!interrupted && position < limit)
	//{
	//	/* read writer position */
	//	position = *((uint32_t *)(sts + 0));
	//	//printf("POS: %5d\n", position);

	//	/* print 16384 samples if ready, otherwise sleep 1 us */
	//	if((position >= limit))
	//	{
	//		memcpy(buf_i,ram,COPY_BYTES); //copy bytes from BRAM
	//		for(i = 0; i < num_word; ++i)
	//		{
	//			buf_o[i] = buf_i[i];
	//			printf("%d\n",(int16_t *)buf_o[i]);
	//			//wo = (uint32_t *)(buf_o[i]);
	//			//printf("%5d\n", wo);
	//		}
	//	}
	//	else
	//	{
	//		usleep(100);
	//	}
	//}

	munmap(cfg, sysconf(_SC_PAGESIZE));
	munmap(sts, sysconf(_SC_PAGESIZE));
	munmap(ram, sysconf(_SC_PAGESIZE));

	return 0;
}

