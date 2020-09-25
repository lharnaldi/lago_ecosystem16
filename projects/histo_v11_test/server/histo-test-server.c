#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>
#include <math.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define TCP_PORT 1001

int interrupted = 0;

void signal_handler(int sig)
{
	interrupted = 1;
}

int main(int argc, char *argv[])
{
	int file, sockServer, sockClient;
	int pos, limit, start;
	pid_t pid;
	//volatile void *cfg, *sts, *ram;
	void *cfg, *sts, *ram;
	unsigned long size = 0;
	struct sockaddr_in addr;
	int yes = 1;

	if((file = open("/dev/mem", O_RDWR)) < 0)
	{
		perror("open");
		return 1;
	}

	cfg = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, file, 0x40001000);
	sts = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, file, 0x40002000);
	ram = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, file, 0x40003000);

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

	limit = 2048; //128

	while(1)
	{
		if((sockClient = accept(sockServer, NULL, NULL)) < 0)
		{
			perror("accept");
			return 1;
		}

		signal(SIGINT, signal_handler);

		/* enter reset mode */
		*(uint8_t *)(cfg + 0) &= ~1;
		usleep(100);
		*(uint8_t *)(cfg + 0) &= ~2;
		/* enter reset mode */
		//*((uint32_t *)(cfg + 0)) &= ~3;
		// set counter number
		*((uint32_t *)(cfg + 4)) = 1024-1;
		// light the LEDS
		*((uint32_t *)(cfg + 16)) = 11;
		/* enter normal operating mode */
		*((uint32_t *)(cfg + 0)) |= 3;

	while(!interrupted)
	{
		/* read ram writer position */
		pos = *((uint32_t *)(sts + 0));
		printf("%d\n",pos);

		/* send 1024 bytes if ready, otherwise sleep 0.1 ms */
		//if((limit > 0 && pos > limit) || (limit == 0 && pos < 6144)) //384))
		if((limit > 0 && pos > limit) || (limit == 0 && pos < 6144)) //384))
		{
			start = limit > 0 ? limit*8 - 16384 : 3072;
			//if(send(sockClient, ram + start, 1024, 0) < 0) break;
			if(send(sockClient, ram + start, 16384, 0) < 0) break;
			limit += 2048;//128;
			if(limit == 4096) limit = 0;//512) limit = 0;
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
  *(uint8_t *)(cfg + 0) &= ~1;
  usleep(100);
  *(uint8_t *)(cfg + 0) &= ~2;
	/* enter reset mode */
	//*((uint32_t *)(cfg + 0)) &= ~3;

	return 0;
}
