/*
 * pt_linux.c
 *
 *   THIS PROGRAM IS UPLOADED FOR TROUBLESHOOTING PURPOSES ONLY! IT IS NOT COMPLETE, CONTAINS ONLY CODE
 *   PERTAINING TO ISSUES DISCUSSED IN THIS FORUM THREAD.
 */

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

#include <getopt.h>
#include <sys/mman.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <time.h>
#include <unistd.h>
#include <errno.h>

#define __USE_GNU // to get macros like CPU_ZERO
#include <sched.h>  // to set affinity

#define PACKET_SIZE			256
#define INCREMENT			100
#define ROLLOVER			1024

#define SAMPLE_BYTES		4
#define S2MM_NUM_CHS		1
#define PACKET_BYTES		PACKET_SIZE * S2MM_NUM_CHS * SAMPLE_BYTES

#define DRAM_BUFFER_ADDR	0x2f000000

//AXI DMA Address Map, Direct Mode
//Refer to PG021, Page 14-15, Table 2-8
#define S2MM_DMACR					0x30					//S2MM DMA Control Register
#define S2MM_DMASR					0x34					//S2MM DMA Status Register
#define S2MM_DA						0x48					//S2MM DMA Destination Register
#define S2MM_DA_MSB					0x4C					//S2MM DMA Destination Register MSB
#define S2MM_LENGTH					0x58					//S2MM DMA Transfer Length Register

//AXI Stream-to-Memory Map Control Register Settings
//See S2MM_DMACR Register (offset x30), PG021, P27, Table 2-19
#define S2MM_DMACR_CONFIG_RESET		0x01015004				//S2MM DMA Control  - Reset
#define S2MM_DMACR_CONFIG_STOP		0x01015000				//S2MM DMA Control  - Stop
#define S2MM_DMACR_CONFIG_RUN		0x01015001				//S2MM DMA Control  - Run, Non-Cyclic Mode, IOC_IrqEN & ERR_IrqEN

static void *DMA_Base_Addr;			//virtual address of DMA hardware, return via mmap
static void *DMA_Data_Addr;		    //virtual address of DMA buffer for S2MM data, returned via mmap (I think??)

off_t Dram_Buff_Addr = DRAM_BUFFER_ADDR;	//hardware address to place S2MM data, will be given to mmap

//working variables, clean up later ...
int retval=0;
long addr,val,val2,val3;
int valuefd, exportfd, directionfd;
int fd_uio, fd_mem;
int size;
int counter=0;

//helper - set mmaped DMA register
void DMA_Set(unsigned int * memaddr, unsigned int value)
{
	*((volatile unsigned *) (memaddr)) = value;
}//DMA_Set

//helper - read mmap DMA register
unsigned int DMA_Get(unsigned int * memaddr)
{
	int value;
	value = *((volatile unsigned *) (memaddr));
    return value;
}//DMA_Get

//helper - used to check for DMA reset
unsigned int DMA_isReset(void)
{
	//check halted bit of DMACR
	return ((DMA_Get(DMA_Base_Addr + S2MM_DMACR)&4)==4);
}

//helper - used to check for DMA running
unsigned int DMA_isRunning(void)
{
	//check running bit of DMACR and halted bit of DMASR
	return (((DMA_Get(DMA_Base_Addr+S2MM_DMACR)&1)==1) && ((DMA_Get(DMA_Base_Addr+S2MM_DMASR)&1)==0));
}

//gets memory size of DMA peripheral in hardware via uio
unsigned int get_memory_size(void)
{
	FILE *size_fp;
	unsigned int size;

	/* open the file that describes the memory range needed to map the TTC into
	 * this address space, this is the range of the TTC in the device tree
	 */
	size_fp = fopen("/sys/class/uio/uio0/maps/map0/size", "r");
	if (!size_fp) {
		printf("unable to open the uio size file\n");
		exit(-1);
	}//

	/* Get the size which is an ASCII string such as 0xXXXXXXXX and then be stop
	 * using the file
	 */
	fscanf(size_fp, "0x%08X", &size);
	fclose(size_fp);

	return size;
}//get_memory_size

//polled interrupt handler
void wait_for_interrupt(void)
{

	//local working variables
	unsigned int pending = 0;
	unsigned int reenable = 1;
	unsigned int control, status, data;
	unsigned int Err_Flg   = 0;
	unsigned int Err_Irq   = 0;
	unsigned int SGDecErr  = 0;
	unsigned int SGSlvErr  = 0;
	unsigned int SGIntErr  = 0;
	unsigned int DMADecErr = 0;
	unsigned int DMASlvErr = 0;
	unsigned int DMAIntErr = 0;
	unsigned int Idle      = 0;
	unsigned int Halted    = 0;

	printf ( "##WAITING ON INTERRUPT##\n\r");

	/* block on the file waiting for an interrupt */
	read(fd_uio, (void *)&pending, sizeof(int));

	printf ( "##INTERUPT RECIEVED##\n\r");

	counter++;											//increment debug counter

	//read control, status and data
	control = DMA_Get(DMA_Base_Addr+S2MM_DMACR);		//read control
	status = DMA_Get(DMA_Base_Addr+S2MM_DMASR);			//read status
	data = DMA_Get(DMA_Data_Addr);						//read first word of data (I think??)

	//debug - decode S2MM_DMASR register, check for status and errors:
	if  ((status >> 14) & 1) Err_Irq =   1; else Err_Irq   = 0;
	if  ((status >> 10) & 1) SGDecErr  = 1; else SGDecErr  = 0;
	if  ((status >> 9 ) & 1) SGSlvErr  = 1; else SGSlvErr  = 0;
	if  ((status >> 8 ) & 1) SGIntErr  = 1; else SGIntErr  = 0;
	if  ((status >> 6 ) & 1) DMADecErr = 1; else DMADecErr = 0;
	if  ((status >> 5 ) & 1) DMASlvErr = 1; else DMASlvErr = 0;
	if  ((status >> 4 ) & 1) DMAIntErr = 1; else DMAIntErr = 0;
	if  ((status >> 1 ) & 1) Idle      = 1; else Idle      = 0;
	if  ((status >> 0 ) & 1) Halted    = 1; else Halted    = 0;

	//check for errors - this should stop processing
	if (Err_Irq||DMADecErr||DMASlvErr||DMAIntErr||Halted) Err_Flg =1; else Err_Flg =0;

	//for simulation, print the results:
	printf ( "## INT, %d >> S2MM_DMASR: %08x, S2MM_DMACR: %08x, DATA: %08x ",counter,status,control,data);
	if (Err_Irq)   printf ( "!!Err_IRQ!! ");
	if (SGDecErr)  printf ( "!!SGDecErr!! ");
	if (SGSlvErr)  printf ( "!!SGSlvErr!! ");
	if (SGIntErr)  printf ( "!!SGIntErr!! ");
	if (DMADecErr) printf ( "!!DMADecErr!! ");
	if (DMASlvErr) printf ( "!!DMASlvErr!! ");
	if (DMAIntErr) printf ( "!!DMAIntErr!! ");
	if (Idle )     printf ( "Idle ");
	if (Halted )   printf ( "Halted ");
	printf ( "\r\n");

	// Clear interrupt. just perform a write to bit no. 12 of S2MM_DMASR
	status |= 1 << 12;		//set bit 12 will clear it!!
	DMA_Set(DMA_Base_Addr+S2MM_DMASR, status);

	/* re-enable the interrupt again now that it's been handled */
	write(fd_uio, (void *)&reenable, sizeof(int));

	//RESTART DMA TRANSFER
	//1. Set Destination Address, map DMA 1
	DMA_Set(DMA_Base_Addr + S2MM_DA, Dram_Buff_Addr);			//set destination data address
	//2. Set Transfer Length (number of bytes in packet)
	DMA_Set(DMA_Base_Addr + S2MM_LENGTH, PACKET_BYTES);			//set data transfer length in bytes

	printf ( "##INTERUPT CLEARED##\n\r");

}//wait_for_interrupt


//
// MAIN
//
int main (int argc, char **argv) {

	
	//////////////////////////////////////////////////////////////////////////////
	///	SETUP GPIO FOR STREAMING DATA CONTROL
	//////////////////////////////////////////////////////////////////////////////
	//THIS SECTION OF CODE REDACTED FOR BREVITY.
	//
	
	//////////////////////////////////////////////////////////////////////////////
	///	MMAP DMA PERIPHERAL / DATA ADDR
	//////////////////////////////////////////////////////////////////////////////

	//open UIO and get file handle
	printf("Open /dev/uio0 ...\n");
	fd_uio = open("/dev/uio0",O_RDWR);
	if (fd_uio < 1) {
		printf("Unable to open UIO device file");
		return -1;
	}

	/* get the size of the memory to be mapped into this process address space
	 * and then map it in such that the device memory is accessible
	 */
	size = get_memory_size();
	printf("Get memory size returned = 0x%X\n", size);

	/* open the UIO device file to allow access to control the device */
	DMA_Base_Addr  =   mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd_uio, (off_t) 0);
	if (DMA_Base_Addr == MAP_FAILED) {
		printf("!!!MMAP DMA  FAILED!!!\n\n");
		return -1;
	}

	//open dev/mem
	printf("Open /dev/mem ...\n");
	fd_mem = open("/dev/mem", O_RDWR);
	if (fd_mem < 1) {
		printf("Unable to open /dev/mem for mapping DMA memory");
		return -1;
	}

	// mmmap area for S2MM data, pass Dram_Buff_Addr which is a specified location memory, 
	// outside of kernel space (I think??)
	DMA_Data_Addr  =  mmap(NULL, PACKET_BYTES, PROT_READ | PROT_WRITE, MAP_SHARED, fd_mem, Dram_Buff_Addr);
	if (DMA_Data_Addr == MAP_FAILED) {
		printf("!!!MMAP DMA Data  FAILED!!!\n\n");
		return -1;
	}

	//////////////////////////////////////////////////////////////////////////////
	///	Initialize DMA via register direct method ///
	//////////////////////////////////////////////////////////////////////////////
	printf("<><><><>INIT DMA<><><><>\n");
	//1. Reset DMA, set S2MM_DMACR (PG021, p27, Figure 2-2)
	printf ("Reset DMA ...\n\r");
	DMA_Set(DMA_Base_Addr + S2MM_DMACR, S2MM_DMACR_CONFIG_RESET);		//reset DMA
	printf ( "Wait for DMA Reset ...\n\r");
	while ((DMA_Get(DMA_Base_Addr + S2MM_DMACR)&4)==4);					//wait for reset clear
	printf("DMA Status: %X\n\r",DMA_Get(DMA_Base_Addr+S2MM_DMASR));		//report status
	DMA_Set(DMA_Base_Addr+S2MM_DMASR, 0xFFFFFFFF);						//remove any errors
	printf("DMA Status: %X\n\r",DMA_Get(DMA_Base_Addr+S2MM_DMASR));
	usleep(100000);														//sleep
	//2. RUN DMA, set S2MM_DMACR (PG021, p27, Figure 2-2)
	printf ("Run DMA ...\n\r");
	DMA_Set(DMA_Base_Addr + S2MM_DMACR, S2MM_DMACR_CONFIG_RUN);			//run DMA
    // wait for run, polls DMACR run bit and DMASR halted bit
    while (((DMA_Get(DMA_Base_Addr+S2MM_DMACR)&1)==0) || ((DMA_Get(DMA_Base_Addr+S2MM_DMASR)&1)==1))
    {
    	printf("DMA Control: %X\n\r",DMA_Get(DMA_Base_Addr+S2MM_DMACR));
    	printf("DMA Status : %X\n\r",DMA_Get(DMA_Base_Addr+S2MM_DMASR));
    	usleep(10000);
    }//

	// ENABLE STREAMING
    // THIS SECTION OF CODE REDACTED FOR BREVITY.
	// SENDS GPIO CODE TO START A DATA STREAM

	///START DMA TRANSFER
	//1. Set Destination Address
	printf ("Set Destination Address ...\n\r");
	DMA_Set(DMA_Base_Addr + S2MM_DA, Dram_Buff_Addr);			//set destination data address
	//2. Set Transfer Length (number of bytes in packet)
	printf ("Set Transfer Length Address ...\n\r");
	DMA_Set(DMA_Base_Addr + S2MM_LENGTH, PACKET_BYTES);			//set data transfer length in bytes

	//loop and try for 50 times
	while (counter<50){
		//WAIT FOR INTERRUPT
		wait_for_interrupt();	
	}

	// DISABLE STREAMING
    // THIS SECTION OF CODE REDACTED FOR BREVITY.
	// SENDS GPIO CODE TO STOP A DATA STREAM

	//RESET DMA
	printf ("Stop DMA ...\n\r");
	DMA_Set(DMA_Base_Addr + S2MM_DMACR, S2MM_DMACR_CONFIG_STOP);		//stop DMA
	printf ("Reset DMA ...\n\r");
	DMA_Set(DMA_Base_Addr + S2MM_DMACR, S2MM_DMACR_CONFIG_RESET);		//reset DMA
	printf ( "Wait for DMA Reset ...\n\r");
	while ((DMA_Get(DMA_Base_Addr + S2MM_DMACR)&4)==4);					//wait for reset
	usleep(100000);

	/* disable the UIO DMA interrupt */
	write(fd_uio, 0, sizeof(int));

	//clean up / munmaps / close
	printf("Clean up ...\n");
	munmap(DMA_Base_Addr,size);
	munmap(DMA_Data_Addr,PACKET_BYTES);
	close(fd_uio);
	close(fd_mem);

	printf("!!!FINISH !!!!\n");

	return 0;

}//end int main
