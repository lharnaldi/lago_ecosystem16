#include "sdr-rcv-gps-srv.h"

#define TCP_PORT 1001

int interrupted = 0;

void signal_handler(int sig)
{
  interrupted = 1;
}

int wait_for_interrupt(int fd_int, void *dev_ptr) 
{
	uint32_t value;
	uint32_t info = 1; /* unmask */

	ssize_t nb = write(fd_int, &info, sizeof(info));
	if (nb != (ssize_t)sizeof(info)) {
		perror("write");
		close(fd_int);
		exit(EXIT_FAILURE);
	}

	// block (timeout for poll) on the file waiting for an interrupt 
	struct pollfd fds = 
	{
		.fd = fd_int,
		.events = POLLIN,
	};

	int ret = poll(&fds, 1, 1000);
	//printf("ret is : %d\n", ret);
	if (ret >= 1) {
		nb = read(fd_int, &info, sizeof(info));
		if (nb == (ssize_t)sizeof(info)) {
			/* Do something in response to the interrupt. */
			value = dev_read(dev_ptr, XIL_AXI_INTC_IPR_OFFSET);
			if ((value & 0x00000001) != 0) {
				dev_write(dev_ptr, XIL_AXI_INTC_IAR_OFFSET, 1);
				// read writer position 
				position = dev_read(sts_ptr, STS_STATUS_OFFSET);

			}
		} else {
			perror("poll()");
			close(fd_int);
			exit(EXIT_FAILURE);
		}
	}
	return ret;
}

void *thread_isr(void *p) 
{
	int32_t g_tim, g_dat, g_lat, g_lon, g_alt, g_sat;
	//initialize GPS connection
	gps_init();
	while(1)
		if (wait_for_interrupt(intc_fd, intc_ptr)){
			//get GPS data
			gps_location(&g_data);
			//write GPS data into registers
			//FIXME: see how and where to write pressure and temperature data
			// convert float to int32_t to write to FPGA
			g_tim = (int32_t)(g_data.times); 
			g_dat = (int32_t)(g_data.date); 
			g_lat = (int32_t)(g_data.latitude * 65536);
			g_lon = (int32_t)(g_data.longitude * 65536);
			g_alt = (int32_t)(g_data.altitude * 65536);
			g_sat = (int32_t)(g_data.satellites); 

			dev_write(cfg_ptr,CFG_TIME_OFFSET, g_tim);
			dev_write(cfg_ptr,CFG_DATE_OFFSET, g_dat);
			dev_write(cfg_ptr,CFG_LATITUDE_OFFSET, g_lat);
			dev_write(cfg_ptr,CFG_LONGITUDE_OFFSET, g_lon);
			dev_write(cfg_ptr,CFG_ALTITUDE_OFFSET, g_alt);
			dev_write(cfg_ptr,CFG_SATELLITE_OFFSET, g_sat);
			//printf("%lf %lf\n", gps_data.latitude, gps_data.longitude);
		}
}
int main(int argc, char *argv[])
{
  int file, sockServer, sockClient;
  int pos, limit, start;
  void *cfg, *sts, *ram;
  unsigned long size = 0;
  struct sockaddr_in addr;
  uint32_t command = 600000;
  uint32_t freqMin = 50000;
  uint32_t freqMax = 50000000;
  int yes = 1;

  if((file = open("/dev/mem", O_RDWR)) < 0)
  {
    perror("open");
    return 1;
  }

  cfg = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, file, 0x40000000);
  sts = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, file, 0x40001000);
  ram = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, file, 0x40002000);

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
    *((uint32_t *)(cfg + 0)) &= ~15;
    /* set default phase increment */
    *((uint32_t *)(cfg + 4)) = (uint32_t)floor(600000/125.0e6*(1<<30)+0.5);
    /* set default sample rate */
    *((uint32_t *)(cfg + 8)) = 625;
    /* set default amlitude for test signal */
    *((uint32_t *)(cfg + 12)) = (15 << 16);
    /* set default phase increment for test signal */
    *((uint32_t *)(cfg + 16)) = (uint32_t)floor((600000 + 100)/125.0e6*(1<<30)+0.5);

    if((sockClient = accept(sockServer, NULL, NULL)) < 0)
    {
      perror("accept");
      return 1;
    }

    signal(SIGINT, signal_handler);

    /* enter normal operating mode */
    *((uint32_t *)(cfg + 0)) |= 15;

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
            *((uint32_t *)(cfg + 4)) = (uint32_t)floor(command/125.0e6*(1<<30)+0.5);
            /* phase increment for test signal */
            *((uint32_t *)(cfg + 16)) = (uint32_t)floor((command + 100)/125.0e6*(1<<30)+0.5);
            break;
          case 1:
            /* set sample rate */
            switch(command & 3)
            {
              case 0:
                freqMin = 25000;
                *((uint32_t *)(cfg + 0)) &= ~8;
                *((uint32_t *)(cfg + 8)) = 1250;
                *((uint32_t *)(cfg + 0)) |= 8;
                break;
              case 1:
                freqMin = 50000;
                *((uint32_t *)(cfg + 0)) &= ~8;
                *((uint32_t *)(cfg + 8)) = 625;
                *((uint32_t *)(cfg + 0)) |= 8;
                break;
              case 2:
                freqMin = 125000;
                *((uint32_t *)(cfg + 0)) &= ~8;
                *((uint32_t *)(cfg + 8)) = 250;
                *((uint32_t *)(cfg + 0)) |= 8;
                break;
              case 3:
                freqMin = 250000;
                *((uint32_t *)(cfg + 0)) &= ~8;
                *((uint32_t *)(cfg + 8)) = 125;
                *((uint32_t *)(cfg + 0)) |= 8;
                break;
            }
            break;
        }
      }

      /* read ram writer position */
      pos = *((uint32_t *)(sts + 0));

      /* send 1024 bytes if ready, otherwise sleep 0.1 ms */
      if((limit > 0 && pos > limit) || (limit == 0 && pos < 384))
      {
        start = limit > 0 ? limit*8 - 1024 : 3072;
        if(send(sockClient, ram + start, 1024, 0) < 0) break;
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
  *((uint32_t *)(cfg + 0)) &= ~15;

  return 0;
}
