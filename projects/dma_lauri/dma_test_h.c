/**
 * Proof of concept offloaded memcopy using AXI Direct Memory Access v7.1
 */

#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <sys/mman.h>

#define DMA_BASE_ADDRESS         0x40400000

#define MM2S_CONTROL_REGISTER    0x00
#define MM2S_STATUS_REGISTER     0x04
#define MM2S_START_ADDRESS       0x18
#define MM2S_LENGTH              0x28

#define S2MM_CONTROL_REGISTER    0x30
#define S2MM_STATUS_REGISTER     0x34
#define S2MM_DESTINATION_ADDRESS 0x48
#define S2MM_LENGTH              0x58

#define BUFFER_BYTESIZE   16  // Length of the buffers for DMA transfer

unsigned int dma_set(unsigned int* dma_virtual_address, int offset, unsigned int value) {
    dma_virtual_address[offset>>2] = value;
}

unsigned int dma_get(unsigned int* dma_virtual_address, int offset) {
    return dma_virtual_address[offset>>2];
}

int dma_mm2s_sync(unsigned int* dma_virtual_address) {
    unsigned int mm2s_status =  dma_get(dma_virtual_address, MM2S_STATUS_REGISTER);
    while(!(mm2s_status & 1<<12) || !(mm2s_status & 1<<1) ){
        dma_s2mm_status(dma_virtual_address);
        dma_mm2s_status(dma_virtual_address);

        mm2s_status =  dma_get(dma_virtual_address, MM2S_STATUS_REGISTER);
    }
}

int dma_s2mm_sync(unsigned int* dma_virtual_address) {
    unsigned int s2mm_status = dma_get(dma_virtual_address, S2MM_STATUS_REGISTER);
    while(!(s2mm_status & 1<<12) || !(s2mm_status & 1<<1)){
        dma_s2mm_status(dma_virtual_address);
        dma_mm2s_status(dma_virtual_address);

        s2mm_status = dma_get(dma_virtual_address, S2MM_STATUS_REGISTER);
    }
}

void dma_s2mm_status(unsigned int* dma_virtual_address) {
    unsigned int status = dma_get(dma_virtual_address, S2MM_STATUS_REGISTER);
    printf("Stream to memory-mapped status (0x%08x@0x%02x):", status, S2MM_STATUS_REGISTER);
    if (status & 0x00000001) printf(" halted"); else printf(" running");
    if (status & 0x00000002) printf(" idle");
    if (status & 0x00000008) printf(" SGIncld");
    if (status & 0x00000010) printf(" DMAIntErr");
    if (status & 0x00000020) printf(" DMASlvErr");
    if (status & 0x00000040) printf(" DMADecErr");
    if (status & 0x00000100) printf(" SGIntErr");
    if (status & 0x00000200) printf(" SGSlvErr");
    if (status & 0x00000400) printf(" SGDecErr");
    if (status & 0x00001000) printf(" IOC_Irq");
    if (status & 0x00002000) printf(" Dly_Irq");
    if (status & 0x00004000) printf(" Err_Irq");
    printf("\n");
}

void dma_mm2s_status(unsigned int* dma_virtual_address) {
    unsigned int status = dma_get(dma_virtual_address, MM2S_STATUS_REGISTER);
    printf("Memory-mapped to stream status (0x%08x@0x%02x):", status, MM2S_STATUS_REGISTER);
    if (status & 0x00000001) printf(" halted"); else printf(" running");
    if (status & 0x00000002) printf(" idle");
    if (status & 0x00000008) printf(" SGIncld");
    if (status & 0x00000010) printf(" DMAIntErr");
    if (status & 0x00000020) printf(" DMASlvErr");
    if (status & 0x00000040) printf(" DMADecErr");
    if (status & 0x00000100) printf(" SGIntErr");
    if (status & 0x00000200) printf(" SGSlvErr");
    if (status & 0x00000400) printf(" SGDecErr");
    if (status & 0x00001000) printf(" IOC_Irq");
    if (status & 0x00002000) printf(" Dly_Irq");
    if (status & 0x00004000) printf(" Err_Irq");
    printf("\n");
}

void memdump(void* virtual_address, int byte_count) {
    char *p = virtual_address;
    int offset;
    for (offset = 0; offset < byte_count; offset++) {
        printf("%02x", p[offset]);
        if (offset % 4 == 3) { printf(" "); }
    }
    printf("\n");
}


/*int main() {
    int dh = open("/dev/mem", O_RDWR | O_SYNC); // Open /dev/mem which represents the whole physical memory
    unsigned int* virtual_address = mmap(NULL, 65535, PROT_READ | PROT_WRITE, MAP_SHARED, dh, 0x40000000); // Memory map AXI Lite register block
    unsigned int* virtual_source_address  = mmap(NULL, 65535, PROT_READ | PROT_WRITE, MAP_SHARED, dh, 0x0e000000); // Memory map source address
    unsigned int* virtual_destination_address = mmap(NULL, 65535, PROT_READ | PROT_WRITE, MAP_SHARED, dh, 0x0f000000); // Memory map destination address

    virtual_source_address[0]= 0x11223344; // Write random stuff to source block
    memset(virtual_destination_address, 0, 32); // Clear destination block

    printf("Source memory block:      "); memdump(virtual_source_address, 32);
    printf("Destination memory block: "); memdump(virtual_destination_address, 32);

    printf("Resetting DMA\n");
    dma_set(virtual_address, S2MM_CONTROL_REGISTER, 4);
    dma_set(virtual_address, MM2S_CONTROL_REGISTER, 4);
    dma_s2mm_status(virtual_address);
    dma_mm2s_status(virtual_address);

    printf("Halting DMA\n");
    dma_set(virtual_address, S2MM_CONTROL_REGISTER, 0);
    dma_set(virtual_address, MM2S_CONTROL_REGISTER, 0);
    dma_s2mm_status(virtual_address);
    dma_mm2s_status(virtual_address);

    printf("Writing destination address\n");
    dma_set(virtual_address, S2MM_DESTINATION_ADDRESS, 0x0f000000); // Write destination address
    dma_s2mm_status(virtual_address);

    printf("Writing source address...\n");
    dma_set(virtual_address, MM2S_START_ADDRESS, 0x0e000000); // Write source address
    dma_mm2s_status(virtual_address);

    printf("Starting S2MM channel with all interrupts masked...\n");
    dma_set(virtual_address, S2MM_CONTROL_REGISTER, 0xf001);
    dma_s2mm_status(virtual_address);

    printf("Starting MM2S channel with all interrupts masked...\n");
    dma_set(virtual_address, MM2S_CONTROL_REGISTER, 0xf001);
    dma_mm2s_status(virtual_address);

    printf("Writing S2MM transfer length...\n");
    dma_set(virtual_address, S2MM_LENGTH, 32);
    dma_s2mm_status(virtual_address);

    printf("Writing MM2S transfer length...\n");
    dma_set(virtual_address, MM2S_LENGTH, 32);
    dma_mm2s_status(virtual_address);

    printf("Waiting for MM2S synchronization...\n");
    dma_mm2s_sync(virtual_address);

    printf("Waiting for S2MM sychronization...\n");
    dma_s2mm_sync(virtual_address); // If this locks up make sure all memory ranges are assigned under Address Editor!

    dma_s2mm_status(virtual_address);
    dma_mm2s_status(virtual_address);

    printf("Destination memory block: "); memdump(virtual_destination_address, 32);
}*/

int main()
{
  int memfd;
  void *mapped_base, *mapped_dev_base;
  off_t dev_base = DMA_BASE_ADDRESS;

  int memfd_1;
  void *mapped_base_1, *mapped_dev_base_1;
  off_t dev_base_1 = DDR_BASE_ADDRESS;

  int memfd_2;
  void *mapped_base_2, *mapped_dev_base_2;
  off_t dev_base_2 = DDR_BASE_WRITE_ADDRESS;

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
    STEP 2 : Map the kernel memory location starting from 0x20000000 to the User layer
    ========================================================================================*/
    memfd_1 = open("/dev/mem", O_RDWR | O_SYNC);
    if (memfd_1 == -1)
    {
      printf("Can't open /dev/mem.\n");
        exit(0);
    }
    printf("/dev/mem opened.\n");
    // Map one page of memory into user space such that the device is in that page, but it may not
    // be at the start of the page.

    mapped_base_1 = mmap(0, DDR_MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, memfd_1, dev_base_1 & ~DDR_MAP_MASK);
    if (mapped_base_1 == (void *) -1)
    {
      printf("Can't map the memory to user space.\n");
        exit(0);
    }
    printf("Memory mapped at address %p.\n", mapped_base_1);
    // get the address of the device in user space which will be an offset from the base
    // that was mapped as memory is mapped at the start of a page
     mapped_dev_base_1 = mapped_base_1 + (dev_base_1 & DDR_MAP_MASK);
     /*======================================================================================
     STEP 3 : Copy the Data to the DDR Memory at location 0x20000000
     ========================================================================================*/
    memcpy(mapped_dev_base_1, SrcArray, (BUFFER_BYTESIZE));
    /*======================================================================================
     STEP 4 : Un-map the kernel memory from the User layer.
    ========================================================================================*/
    if (munmap(mapped_base_1, DDR_MAP_SIZE) == -1)
    {
      printf("Can't unmap memory from user space.\n");
      exit(0);
    }
    close(memfd_1);
    /*======================================================================================
    STEP 5 : Map the AXI CDMA Register memory to the User layer
        Do the Register Setting for DMA transfer
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
    mapped_base = mmap(0, MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, memfd, dev_base & ~MAP_MASK);
    if (mapped_base == (void *) -1)
    {
        printf("Can't map the memory to user space.\n");
        exit(0);
      }
    // get the address of the device in user space which will be an offset from the base
    // that was mapped as memory is mapped at the start of a page
    mapped_dev_base = mapped_base + (dev_base & MAP_MASK);
    //Reset CDMA
      do{
            ResetMask = (unsigned long )AXIDMA_CR_RESET_MASK;
      *((volatile unsigned long *) (mapped_dev_base + AXIDMA_CR_OFFSET)) = (unsigned long)ResetMask;
      /* If the reset bit is still high, then reset is not done */
      ResetMask = *((volatile unsigned long *) (mapped_dev_base + AXIDMA_CR_OFFSET));
      if(!(ResetMask & AXIDMA_CR_RESET_MASK))
      {
        break;
      }
      TimeOut -= 1;
      }while (TimeOut);
        //enable Interrupt
      RegValue = *((volatile unsigned long *) (mapped_dev_base + AXIDMA_CR_OFFSET));
      RegValue = (unsigned long)(RegValue | AXIDMA_XR_IRQ_ALL_MASK );
      *((volatile unsigned long *) (mapped_dev_base + AXIDMA_CR_OFFSET)) = (unsigned long)RegValue;
      // Checking for the Bus Idle
      RegValue = *((volatile unsigned long *) (mapped_dev_base + AXIDMA_SR_OFFSET));
      if(!(RegValue & AXIDMA_SR_IDLE_MASK))
      {
        printf("BUS IS BUSY Error Condition \n\r");
        return 1;
      }
      // Check the DMA Mode and switch it to simple mode
      RegValue = *((volatile unsigned long *) (mapped_dev_base + AXIDMA_CR_OFFSET));
      if((RegValue & AXIDMA_CR_SGMODE_MASK))
      {
        RegValue = (unsigned long)(RegValue & (~AXIDMA_CR_SGMODE_MASK));
        printf("Reading \n \r");
        *((volatile unsigned long *) (mapped_dev_base + AXIDMA_CR_OFFSET)) = (unsigned long)RegValue ;

      }
      //Set the Source Address
      *((volatile unsigned long *) (mapped_dev_base + AXIDMA_SRCADDR_OFFSET)) = (unsigned long)DDR_BASE_ADDRESS;
      //Set the Destination Address
      *((volatile unsigned long *) (mapped_dev_base + AXIDMA_DSTADDR_OFFSET)) = (unsigned long)DDR_BASE_WRITE_ADDRESS;
      RegValue = (unsigned long)(BUFFER_BYTESIZE);
      // write Byte to Transfer
      *((volatile unsigned long *) (mapped_dev_base + AXIDMA_BTT_OFFSET)) = (unsigned long)RegValue;
      /*======================================================================================
      STEP 6 : Wait for the DMA transfer Status
      ========================================================================================*/
      do
      {
          RegValue = *((volatile unsigned long *) (mapped_dev_base + AXIDMA_SR_OFFSET));
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
       STEP 7 : Un-map the AXI CDMA memory from the User layer.
      ========================================================================================*/
      if (munmap(mapped_base, MAP_SIZE) == -1)
      {
          printf("Can't unmap memory from user space.\n");
          exit(0);
      }

      close(memfd);

    /*======================================================================================
    STEP 8 : Map the kernel memory location starting from 0x30000000 to the User layer
    ========================================================================================*/
      memfd_2 = open("/dev/mem", O_RDWR | O_SYNC);
       if (memfd_2 == -1)
       {
         printf("Can't open /dev/mem.\n");
           exit(0);
       }
       printf("/dev/mem opened.\n");
       // Map one page of memory into user space such that the device is in that page, but it may not
       // be at the start of the page.
       mapped_base_2 = mmap(0, DDR_MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, memfd_2, dev_base_2 & ~DDR_MAP_MASK);
       if (mapped_base_2 == (void *) -1)
       {
         printf("Can't map the memory to user space.\n");
           exit(0);
       }
       printf("Memory mapped at address %p.\n", mapped_base_2);
        // get the address of the device in user space which will be an offset from the base
        // that was mapped as memory is mapped at the start of a page
        mapped_dev_base_2 = mapped_base_2 + (dev_base_2 & DDR_MAP_MASK);

        /*======================================================================================
        STEP 9 : Copy the Data from DDR Memory location 0x20000000 to Destination Buffer
        ========================================================================================*/
        memcpy(DestArray, mapped_dev_base_2, (BUFFER_BYTESIZE ));
        /*======================================================================================
      STEP 10 : Un-map the Kernel memory from the User layer.
        ========================================================================================*/
        if (munmap(mapped_base_2, DDR_MAP_SIZE) == -1)
        {
          printf("Can't unmap memory from user space.\n");
            exit(0);
        }

       close(memfd_2);


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

