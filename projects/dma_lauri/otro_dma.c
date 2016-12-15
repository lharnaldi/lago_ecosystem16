#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/mman.h>

#define MM2S_DMACR 0x0
#define MM2S_DMASR 0x4
#define MM2S_SA 0x18
#define MM2S_SA_MSB 0x1C
#define MM2S_LENGTH 0x28
#define S2MM_DMACR 0x30
#define S2MM_DMASR 0x34
#define S2MM_DA 0x48
#define S2MM_DA_MSB 0x4C
#define S2MM_LENGTH 0x58

int main() 
{
	int uioFd;
	unsigned int uioSize;
	FILE *sizeFd;
	void * baseAddress;
	static const int moveSize = 10;
	char *outBuff;
	char *inBuff;
	int irq = 0;
	int irqClr = 1;
	int mm2sStat;
	int s2mmStat;
	int i;

	// Access AXIDMA space
	uioFd = open("/dev/uio0", O_RDWR);
	if (uioFd < 0) 
	{
		perror("uio open:");
		return errno;
	}

	sizeFd = fopen("/sys/class/uio/uio0/maps/map0/size", O_RDONLY);
	if (sizeFd < 0) 
	{
		perror("uio size access");
		return errno;
	}

	fscanf(sizeFd, "0x%08X", &uioSize);

	printf("uioSize: %d\n", uioSize);

	baseAddress = mmap(NULL, uioSize, PROT_READ|PROT_WRITE, MAP_SHARED, uioFd, 0);

	printf("baseAddress: %d\n", baseAddress);

	// Prepare data

	outBuff = malloc(moveSize * sizeof(char));
	for (i = 0; i < moveSize; i++)
	{
		outBuff[i] = i;
	}

	inBuff = malloc(moveSize * sizeof(char));

	// Configure AXIDMA - S2MM

	*((volatile unsigned long *) (baseAddress + S2MM_DMACR)) = 0x4;
	s2mmStat = *((volatile unsigned long *) (baseAddress + S2MM_DMASR));
	printf("S2MM: %d\n", s2mmStat);
	*((volatile unsigned long *) (baseAddress + S2MM_DMACR)) = 0x1000;
	s2mmStat = *((volatile unsigned long *) (baseAddress + S2MM_DMASR));
	printf("S2MM: %d\n", s2mmStat);

	*((volatile unsigned long *) (baseAddress + S2MM_DA)) = inBuff;
	*((volatile unsigned long *) (baseAddress + S2MM_DA_MSB)) = 0;
	*((volatile unsigned long *) (baseAddress + S2MM_LENGTH)) = moveSize;
	*((volatile unsigned long *) (baseAddress + S2MM_DMACR))  = 0x1001;

	s2mmStat = *((volatile unsigned long *) (baseAddress + S2MM_DMASR));
	printf("S2MM: %d\n", s2mmStat);

	// Configure AXIDMA - MM2S
	*((volatile unsigned long *) (baseAddress + MM2S_DMACR)) = 0x4;  
	mm2sStat = *((volatile unsigned long *) (baseAddress + MM2S_DMASR));
	printf("MM2S: %d\n", mm2sStat);

	*((volatile unsigned long *) (baseAddress + MM2S_DMACR)) = 0x1000;  
	mm2sStat = *((volatile	unsigned long *) (baseAddress + MM2S_DMASR));
	printf("MM2S: %d\n", mm2sStat);

	*((volatile unsigned long *) (baseAddress + MM2S_SA))     = outBuff;
	*((volatile unsigned long *) (baseAddress + MM2S_SA_MSB)) = 0;
	*((volatile unsigned long *) (baseAddress + MM2S_LENGTH)) = moveSize;
	*((volatile unsigned long *) (baseAddress + MM2S_DMACR))  = 0x1001;  

	mm2sStat = *((volatile unsigned long *) (baseAddress + MM2S_DMASR));
	printf("MM2S: %d\n", mm2sStat);

	// Wait for interrupt
	read(uioFd, (void *)&irq, sizeof(int));
	write(uioFd, (void *)&irqClr, sizeof(int));

	// Check received data
	s2mmStat = *((volatile unsigned long *) (baseAddress + S2MM_DMASR));
	printf("S2MM: %d\n", s2mmStat);
	mm2sStat = *((volatile unsigned long *) (baseAddress + MM2S_DMASR));
	printf("MM2S: %d\n", mm2sStat);

	for(i = 0; i < moveSize; i++)
	{
		printf("expected: %d, received: %d\n", outBuff[i], inBuff[i]);
	}

	//Close

	munmap(baseAddress, uioSize);

	return errno;
}
