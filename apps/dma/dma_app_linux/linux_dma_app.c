/*
 * Copyright (c) 2012 Xilinx, Inc.  All rights reserved.
 *
 * Xilinx, Inc.
 * XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS" AS A
 * COURTESY TO YOU.  BY PROVIDING THIS DESIGN, CODE, OR INFORMATION AS
 * ONE POSSIBLE   IMPLEMENTATION OF THIS FEATURE, APPLICATION OR
 * STANDARD, XILINX IS MAKING NO REPRESENTATION THAT THIS IMPLEMENTATION
 * IS FREE FROM ANY CLAIMS OF INFRINGEMENT, AND YOU ARE RESPONSIBLE
 * FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE FOR YOUR IMPLEMENTATION.
 * XILINX EXPRESSLY DISCLAIMS ANY WARRANTY WHATSOEVER WITH RESPECT TO
 * THE ADEQUACY OF THE IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO
 * ANY WARRANTIES OR REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE
 * FROM CLAIMS OF INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/mman.h>

// The purpose this test is to show that users can get to devices in user
// mode .This is not to say this should replace a kernel driver, but does
// provide some short term solutions sometimes
// or a debug solution that can be helpful.


// This test was derived from devmem2.c.

#define DMA_BASE_ADDR         0x40000000
#define MM2S_CR_OFFSET        0x00000000
#define MM2S_SR_OFFSET        0x00000004
#define MM2S_SRC_ADDR         0x00000018
#define MM2S_LENGTH           0x00000028

#define S2MM_CR_OFFSET        0x00000030
#define S2MM_SR_OFFSET        0x00000034
#define S2MM_DST_ADDR         0x00000048
#define S2MM_LENGTH           0x00000058

#define MEM_BASE_ADD          0x20000000
#define MEM_BASE_WRITE_ADDR   0x30000000

#define AXIDMA_CR_OFFSET      0x00000000  /**< Control register */
#define AXIDMA_SR_OFFSET      0x00000004  /**< Status register */
#define AXIDMA_CDESC_OFFSET   0x00000008  /**< Current descriptor pointer */
#define AXIDMA_TDESC_OFFSET   0x00000010  /**< Tail descriptor pointer */
#define AXIDMA_SRCADDR_OFFSET 0x00000018  /**< Source address register */
#define AXIDMA_DSTADDR_OFFSET 0x00000020  /**< Destination address register */
#define AXIDMA_BTT_OFFSET     0x00000028  /**< Bytes to transfer */


/** @name Bitmasks of AXIDMA_CR_OFFSET register
 * @{
 */
#define AXIDMA_CR_RESET_MASK	0x00000004 /**< Reset DMA engine */
#define AXIDMA_CR_SGMODE_MASK	0x00000008 /**< Scatter gather mode */

/** @name Bitmask for interrupts
 * These masks are shared by AXIDMA_CR_OFFSET register and
 * AXIDMA_SR_OFFSET register
 * @{
 */
#define AXIDMA_XR_IRQ_IOC_MASK	  0x00001000 /**< Completion interrupt */
#define AXIDMA_XR_IRQ_DELAY_MASK  0x00002000 /**< Delay interrupt */
#define AXIDMA_XR_IRQ_ERROR_MASK  0x00004000 /**< Error interrupt */
#define AXIDMA_XR_IRQ_ALL_MASK	  0x00007000 /**< All interrupts */
#define AXIDMA_XR_IRQ_SIMPLE_ALL_MASK	0x00005000 /**< All interrupts for
						     simple only mode */
/*@}*/

/** @name Bitmasks of AXIDMA_SR_OFFSET register
 * This register reports status of a DMA channel, including
 * idle state, errors, and interrupts
 * @{
 */
#define AXIDMA_SR_IDLE_MASK         0x00000002  /**< DMA channel idle */
#define AXIDMA_SR_SGINCLD_MASK      0x00000008  /**< Hybrid build */
#define AXIDMA_SR_ERR_INTERNAL_MASK 0x00000010  /**< Datamover internal err */
#define AXIDMA_SR_ERR_SLAVE_MASK    0x00000020  /**< Datamover slave err */
#define AXIDMA_SR_ERR_DECODE_MASK   0x00000040  /**< Datamover decode err */
#define AXIDMA_SR_ERR_SG_INT_MASK   0x00000100  /**< SG internal err */
#define AXIDMA_SR_ERR_SG_SLV_MASK   0x00000200  /**< SG slave err */
#define AXIDMA_SR_ERR_SG_DEC_MASK   0x00000400  /**< SG decode err */
#define AXIDMA_SR_ERR_ALL_MASK      0x00000770  /**< All errors */
/*@}*/

//This is to configure the axi-lite port
#define CFG_MAP_SIZE 4096UL //4k
#define CFG_MAP_MASK (CFG_MAP_SIZE - 1)

#define MEM_BASE_ADDR 0x00000000 //2MB  0x10000000
#define MEM_MAP_SIZE  0x00200000 //2MB  0x10000000
#define MEM_MAP_MASK (MEM_MAP_SIZE - 1)

#define DDR_WRITE_OFFSET 0x10000000


#define BUFFER_BYTESIZE		32*1024 //32KB //0x4000	// Length of the buffers for DMA transfer

int main()
{
	int memfd;
	void *cfg_mapped_base, *cfg_mapped_dev_base;
	off_t cfg_dev_base = DMA_BASE_ADDR;

	void *src_mapped_base, *src_mapped_dev_base;
	off_t src_dev_base = MEM_BASE_ADDR;

	void *dst_mapped_base, *dst_mapped_dev_base;
	off_t dst_dev_base = MEM_BASE_ADDR;

	unsigned int TimeOut =5;
	unsigned int ResetMask;
	unsigned int RegValue;
	unsigned int SrcArray[BUFFER_BYTESIZE ];
	unsigned int DestArray[BUFFER_BYTESIZE ];
	unsigned int Index;
	/*======================================================================================
	  STEP 1 : Initialize the source buffer bytes with a pattern  and clear the Destination
	  location
	  =======================================================================================*/
	for (Index = 0; Index < (BUFFER_BYTESIZE/2); Index++)
	{
		SrcArray[Index] = 0x5A5A5A5A/*Index & 0xFF*/;
		DestArray[Index] = 0;
	}
	/*======================================================================================
	  STEP 2 : Map the kernel memory location starting from 0x200000 0x20000000 to the User layer
	  ========================================================================================*/
	memfd = open("/dev/mem", O_RDWR | O_SYNC);
	if (memfd == -1)
	{
		printf("Can't open /dev/mem.\n");
		exit(0);
	}
	printf("/dev/mem opened.\n");
	// Map one page of memory into user space such that the device is in that page, but it may not
	// be at the start of the page.

	// Map one page of memory into user space such that the device is in that page, but it may not
	// be at the start of the page.
	cfg_mapped_base = mmap(0, CFG_MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, memfd, cfg_dev_base & ~CFG_MAP_MASK);
	if (cfg_mapped_base == (void *) -1)
	{
		printf("Can't map the memory to user space.\n");
		exit(0);
	}
	printf("Memory mapped at address %p.\n", cfg_mapped_base);

	// get the address of the device in user space which will be an offset from the base
	// that was mapped as memory is mapped at the start of a page
	cfg_mapped_dev_base = cfg_mapped_base + (cfg_dev_base & CFG_MAP_MASK);

	src_mapped_base = mmap(0, MEM_MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, memfd, src_dev_base & ~MEM_MAP_MASK);
	if (src_mapped_base == (void *) -1)
	{
		printf("Can't map the memory to user space.\n");
		exit(0);
	}
	printf("Memory mapped at address %p.\n", src_mapped_base);
	// get the address of the device in user space which will be an offset from the base
	// that was mapped as memory is mapped at the start of a page
	src_mapped_dev_base = src_mapped_base + (src_dev_base & MEM_MAP_MASK);

	// Map one page of memory into user space such that the device is in that page, but it may not
	// be at the start of the page.
	dst_mapped_base = mmap(0, MEM_MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, memfd, dst_dev_base & ~MEM_MAP_MASK);
	if (dst_mapped_base == (void *) -1)
	{
		printf("Can't map the memory to user space.\n");
		exit(0);
	}
	printf("Memory mapped at address %p.\n", dst_mapped_base);
	// get the address of the device in user space which will be an offset from the base
	// that was mapped as memory is mapped at the start of a page
	dst_mapped_dev_base = dst_mapped_base + (dst_dev_base & MEM_MAP_MASK);
	/*======================================================================================
	  STEP 3 : Copy the Data to the DDR Memory at location 0x20000000
	  ========================================================================================*/
	memcpy(src_mapped_dev_base, SrcArray, (BUFFER_BYTESIZE));
	/*======================================================================================
	  STEP 5 : Map the AXI DMA Register memory to the User layer
	  Do the Register Setting for DMA transfer
	  ========================================================================================*/
	//Reset DMA
	do{
		ResetMask = (unsigned long )AXIDMA_CR_RESET_MASK;
		*((volatile unsigned long *) (cfg_mapped_dev_base + AXIDMA_CR_OFFSET)) = (unsigned long)ResetMask;
		/* If the reset bit is still high, then reset is not done	*/
		ResetMask = *((volatile unsigned long *) (cfg_mapped_dev_base + AXIDMA_CR_OFFSET));
		if(!(ResetMask & AXIDMA_CR_RESET_MASK))
		{
			break;
		}
		TimeOut -= 1;
	}while (TimeOut);
	//enable Interrupt
	RegValue = *((volatile unsigned long *) (cfg_mapped_dev_base + AXIDMA_CR_OFFSET));
	RegValue = (unsigned long)(RegValue | AXIDMA_XR_IRQ_ALL_MASK );
	*((volatile unsigned long *) (cfg_mapped_dev_base + AXIDMA_CR_OFFSET)) = (unsigned long)RegValue;
	// Checking for the Bus Idle
	RegValue = *((volatile unsigned long *) (cfg_mapped_dev_base + AXIDMA_SR_OFFSET));
	if(!(RegValue & AXIDMA_SR_IDLE_MASK))
	{
		printf("BUS IS BUSY Error Condition \n\r");
		return 1;
	}
	// Check the DMA Mode and switch it to simple mode
	RegValue = *((volatile unsigned long *) (cfg_mapped_dev_base + AXIDMA_CR_OFFSET));
	if((RegValue & AXIDMA_CR_SGMODE_MASK))
	{
		RegValue = (unsigned long)(RegValue & (~AXIDMA_CR_SGMODE_MASK));
		printf("Reading \n \r");
		*((volatile unsigned long *) (cfg_mapped_dev_base + AXIDMA_CR_OFFSET)) = (unsigned long)RegValue ;

	}
	//Set the Source Address
	*((volatile unsigned long *) (cfg_mapped_dev_base + AXIDMA_SRCADDR_OFFSET)) = (unsigned long)MM2S_SRC_ADDR;
	//Set the Destination Address
	*((volatile unsigned long *) (cfg_mapped_dev_base + AXIDMA_DSTADDR_OFFSET)) = (unsigned long)S2MM_DST_ADDR;
	RegValue = (unsigned long)(BUFFER_BYTESIZE);
	// write Byte to Transfer
	*((volatile unsigned long *) (cfg_mapped_dev_base + AXIDMA_BTT_OFFSET)) = (unsigned long)RegValue;
	/*======================================================================================
	  STEP 6 : Wait for the DMA transfer Status
	  ========================================================================================*/
	do
	{
		RegValue = *((volatile unsigned long *) (cfg_mapped_dev_base + AXIDMA_SR_OFFSET));
	}while(!(RegValue & AXIDMA_XR_IRQ_ALL_MASK));

	if((RegValue & AXIDMA_XR_IRQ_IOC_MASK))
	{
		printf("Transfer Completed \n\r ");
	}
	if((RegValue & AXIDMA_XR_IRQ_DELAY_MASK))
	{
		printf("IRQ Delay Interrupt\n\r ");
	}
	if((RegValue & AXIDMA_XR_IRQ_ERROR_MASK))
	{
		printf(" Transfer Error Interrupt\n\r ");
	}


	/*======================================================================================
	  STEP 9 : Copy the Data from DDR Memory location 0x20000000 to Destination Buffer
	  ========================================================================================*/
	memcpy(DestArray, dst_mapped_dev_base, (BUFFER_BYTESIZE ));

	/*======================================================================================
	  STEP 7 : Un-map the AXI CDMA memory from the User layer.
	  ========================================================================================*/
	if (munmap(cfg_mapped_base, CFG_MAP_SIZE) == -1)
	{
		printf("Can't unmap memory from user space.\n");
		exit(0);
	}


	/*======================================================================================
	  STEP 4 : Un-map the kernel memory from the User layer.
	  ========================================================================================*/
	if (munmap(src_mapped_base, MEM_MAP_SIZE) == -1)
	{
		printf("Can't unmap memory from user space.\n");
		exit(0);
	}
	/*======================================================================================
	  STEP 8 : Map the kernel memory location starting from 0x30000000 to the User layer
	  ========================================================================================*/
	/*======================================================================================
	  STEP 10 : Un-map the Kernel memory from the User layer.
	  ========================================================================================*/
	if (munmap(dst_mapped_base, MEM_MAP_SIZE) == -1)
	{
		printf("Can't unmap memory from user space.\n");
		exit(0);
	}

	close(memfd);


	/*======================================================================================
	  STEP 11 : Compare Source Buffer with Destination Buffer.
	  ========================================================================================*/
	for (Index = 0; Index < (BUFFER_BYTESIZE/4); Index++)
	{
		if (SrcArray[Index] != DestArray[Index])
		{
			printf("Error in the Data comparison \n \r");
			return 1;
		}
	}
	printf("DATA Transfer is Successfull \n\r");

	return 0;
}
