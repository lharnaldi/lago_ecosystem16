#include "sdr-rcv-gps-srv.h"

#define TCP_PORT 1001

int interrupted = 0;

void signal_handler(int sig)
{
	interrupted = 1;
}

int main(int argc, char *argv[])
{
	int sockServer, sockClient;
	int32_t pos, limit, start;
	int32_t reg_val;
	unsigned long size = 0;
	struct sockaddr_in addr;
	uint32_t command = 600000;
	uint32_t freqMin = 50000;
	uint32_t freqMax = 50000000;
	uint32_t count = 0;
	int flag_end=0;
	int yes = 1;

	struct timeval tv;
	time_t t;
	struct tm *info;
	char t_buf[64];

	//initialize devices. TODO: add error checking
	mem_init();
	intc_init();
	cfg_init();
	sts_init();
	printf("Init complete!!!!\n");

	if((sockServer = socket(AF_INET, SOCK_STREAM, 0)) < 0)
	{
		perror("socket");
		return 1;
	}

	setsockopt(sockServer, SOL_SOCKET, SO_REUSEADDR, (void *)&yes , sizeof(yes));

	/* setup listening address */
	memset(&addr, 0, sizeof(addr));
	addr.sin_family = AF_INET;
	addr.sin_addr.s_addr = htonl(INADDR_ANY);
	addr.sin_port = htons(TCP_PORT);

	printf("Waiting for client connection...\n");
	if(bind(sockServer, (struct sockaddr *)&addr, sizeof(addr)) < 0)
	{
		perror("bind");
		return 1;
	}

	listen(sockServer, 1024);

	limit = 128;

	while(!interrupted)
	{
		/* enter reset mode */
		reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
		dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~15);
		//*((uint32_t *)(cfg + 0)) &= ~15;
		/* set default phase increment */
		reg_val = dev_read(cfg_ptr, CFG_PHASE_INC_OFFSET);
		dev_write(cfg_ptr, CFG_PHASE_INC_OFFSET, (uint32_t)floor(600000/125.0e6*(1<<30)+0.5));
		//*((uint32_t *)(cfg + 4)) = (uint32_t)floor(600000/125.0e6*(1<<30)+0.5);
		/* set default sample rate */
		reg_val = dev_read(cfg_ptr, CFG_SAMPLE_RATE_OFFSET);
		dev_write(cfg_ptr, CFG_SAMPLE_RATE_OFFSET, 625);
		//*((uint32_t *)(cfg + 8)) = 625;
		/* set default amlitude for test signal */
		reg_val = dev_read(cfg_ptr, CFG_AMPL_OFFSET);
		dev_write(cfg_ptr, CFG_AMPL_OFFSET, (15 << 16));
		//*((uint32_t *)(cfg + 12)) = (15 << 16);
		/* set default phase increment for test signal */
		reg_val = dev_read(cfg_ptr, CFG_PHASE_INC_TSIG_OFFSET);
		dev_write(cfg_ptr, CFG_PHASE_INC_TSIG_OFFSET, (uint32_t)floor((600000 + 100)/125.0e6*(1<<30)+0.5));
		//*((uint32_t *)(cfg + 16)) = (uint32_t)floor((600000 + 100)/125.0e6*(1<<30)+0.5);

		if((sockClient = accept(sockServer, NULL, NULL)) < 0)
		{
			perror("accept");
			return 1;
		}

		signal(SIGINT, signal_handler);

		//wait for GPS/external interrupt signal for initialization
		enable_interrupt();

		//now loop until iterrupt received or timeout
		while (!interrupted && !flag_end) 
		{
			count++;
			// the interrupt occurred 
			reg_val = dev_read(intc_ptr, XIL_AXI_INTC_ISR_OFFSET); //read status register
			printf("STATUS IRQ VALUE: %08d\n",reg_val);
			if (reg_val != 0){
				disable_interrupt();
				printf("XXXX: Interrupt recieved\n");
				break;
			}
			usleep(500000); // anti rebond
			if(count == 10)
			{
				flag_end = 1;
				printf("No interrupt received, so exit\n");
				disable_interrupt();
				exit(-1);  //no interrupt received, so exit
			}
			printf("CNTR: %d\n",count);
		}

		//here should print some initialization text
		printf("DAQ initialization\n");
		gettimeofday(&tv, NULL);
		t = tv.tv_sec;

		info = localtime(&t);
		printf("%s",asctime (info));
		strftime (t_buf, sizeof t_buf, "Today is %A, %B %d.\n", info);
		printf("%s",t_buf);
		strftime (t_buf, sizeof t_buf, "The time is %I:%M %p.\n", info);
		printf("%s",t_buf);
		strftime (t_buf, sizeof t_buf, "DAQ started at: %A, %B %d.\n", info);
		printf("%s",t_buf);

		//gettimeofday(&current_time, NULL);
		printf("seconds : %ld\nmicro seconds : %ld (since 1970)\n",tv.tv_sec, tv.tv_usec);

		/* enter normal operating mode */
		reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
		dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 15);
		//*((uint32_t *)(cfg + 0)) |= 15;

		while(!interrupted)
		{
			ioctl(sockClient, FIONREAD, &size);

			if(size >= 4)
			{
				recv(sockClient, (char *)&command, 4, 0);
				switch(command >> 31)
				{
					case 0:
						/* set phase increment */
						if(command < freqMin || command > freqMax) continue;
						/* phase increment for down converter */
						reg_val = dev_read(cfg_ptr, CFG_PHASE_INC_OFFSET);
						dev_write(cfg_ptr, CFG_PHASE_INC_OFFSET, (uint32_t)floor(command/125.0e6*(1<<30)+0.5));
						//*((uint32_t *)(cfg + 4)) = (uint32_t)floor(command/125.0e6*(1<<30)+0.5);
						/* phase increment for test signal */
						reg_val = dev_read(cfg_ptr, CFG_PHASE_INC_TSIG_OFFSET);
						dev_write(cfg_ptr, CFG_PHASE_INC_TSIG_OFFSET, (uint32_t)floor((command + 100)/125.0e6*(1<<30)+0.5));
						//*((uint32_t *)(cfg + 16)) = (uint32_t)floor((command + 100)/125.0e6*(1<<30)+0.5);
						break;
					case 1:
						/* set sample rate */
						switch(command & 3)
						{
							case 0:
								freqMin = 25000;
								reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
								dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~8);
								reg_val = dev_read(cfg_ptr, CFG_SAMPLE_RATE_OFFSET);
								dev_write(cfg_ptr, CFG_SAMPLE_RATE_OFFSET, 1250);
								reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
								dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 8);
								//*((uint32_t *)(cfg + 0)) &= ~8;
								//*((uint32_t *)(cfg + 8)) = 1250;
								//*((uint32_t *)(cfg + 0)) |= 8;
								break;
							case 1:
								freqMin = 50000;
								reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
								dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~8);
								reg_val = dev_read(cfg_ptr, CFG_SAMPLE_RATE_OFFSET);
								dev_write(cfg_ptr, CFG_SAMPLE_RATE_OFFSET, 625);
								reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
								dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 8);
								//*((uint32_t *)(cfg + 0)) &= ~8;
								//*((uint32_t *)(cfg + 8)) = 625;
								//*((uint32_t *)(cfg + 0)) |= 8;
								break;
							case 2:
								freqMin = 125000;
								reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
								dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~8);
								reg_val = dev_read(cfg_ptr, CFG_SAMPLE_RATE_OFFSET);
								dev_write(cfg_ptr, CFG_SAMPLE_RATE_OFFSET, 250);
								reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
								dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 8);
								//*((uint32_t *)(cfg + 0)) &= ~8;
								//*((uint32_t *)(cfg + 8)) = 250;
								//*((uint32_t *)(cfg + 0)) |= 8;
								break;
							case 3:
								freqMin = 250000;
								reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
								dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~8);
								reg_val = dev_read(cfg_ptr, CFG_SAMPLE_RATE_OFFSET);
								dev_write(cfg_ptr, CFG_SAMPLE_RATE_OFFSET, 125);
								reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
								dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 8);
								//*((uint32_t *)(cfg + 0)) &= ~8;
								//*((uint32_t *)(cfg + 8)) = 125;
								//*((uint32_t *)(cfg + 0)) |= 8;
								break;
						}
						break;
				}
			}

			/* read ram writer position */
			pos = dev_read(sts_ptr, STS_STATUS_OFFSET);
			//pos = *((uint32_t *)(sts + 0));

			/* send 1024 bytes if ready, otherwise sleep 0.1 ms */
			if((limit > 0 && pos > limit) || (limit == 0 && pos < 384))
			{
				start = limit > 0 ? limit*8 - 1024 : 3072;
				if(send(sockClient, mem_ptr + start, 1024, 0) < 0) break;
				limit += 128;
				if(limit == 512) limit = 0;
			}
			else
			{
				usleep(100);
			}
		}

		signal(SIGINT, SIG_DFL);
		close(sockClient);
	}

	close(sockServer);

	/* enter reset mode */
	reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
	dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~15);
	//*((uint32_t *)(cfg + 0)) &= ~15;

	return 0;
}
