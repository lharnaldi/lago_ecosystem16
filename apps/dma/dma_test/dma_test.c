/**
 * Proof of concept offloaded memcopy using AXI Direct Memory Access v7.1
 */

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <sys/mman.h>

#define MM2S_CR    0x00
#define MM2S_SR     0x04
#define MM2S_SRC_ADDR       0x18
#define MM2S_LENGTH              0x28

#define S2MM_CR    0x30
#define S2MM_SR     0x34
#define S2MM_DST_ADDR 0x48
#define S2MM_LENGTH              0x58


unsigned int dma_set(unsigned int* dma_virtual_address, int offset, unsigned int value) {
    dma_virtual_address[offset>>2] = value;
}

unsigned int dma_get(unsigned int* dma_virtual_address, int offset) {
    return dma_virtual_address[offset>>2];
}

int dma_mm2s_sync(unsigned int* dma_virtual_address) {
    unsigned int mm2s_status =  dma_get(dma_virtual_address, MM2S_SR);
    while(!(mm2s_status & 1<<12) || !(mm2s_status & 1<<1) ){
        dma_s2mm_status(dma_virtual_address);
        dma_mm2s_status(dma_virtual_address);

        mm2s_status =  dma_get(dma_virtual_address, MM2S_SR);
    }
}

int dma_s2mm_sync(unsigned int* dma_virtual_address) {
    unsigned int s2mm_status = dma_get(dma_virtual_address, S2MM_SR);
    while(!(s2mm_status & 1<<12) || !(s2mm_status & 1<<1)){
        dma_s2mm_status(dma_virtual_address);
        dma_mm2s_status(dma_virtual_address);

        s2mm_status = dma_get(dma_virtual_address, S2MM_SR);
    }
}

void dma_s2mm_status(unsigned int* dma_virtual_address) {
    unsigned int status = dma_get(dma_virtual_address, S2MM_SR);
    printf("Stream to memory-mapped status (0x%08x@0x%02x):", status, S2MM_SR);
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
    unsigned int status = dma_get(dma_virtual_address, MM2S_SR);
    printf("Memory-mapped to stream status (0x%08x@0x%02x):", status, MM2S_SR);
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
    int offset, i;
    int16_t value[2];
//    for (offset = 0; offset < byte_count; offset++) {
//        printf("%02x", p[offset]);
//        if (offset % 4 == 3) { printf(" "); }
//    }
//    printf("\n");
  for(i = 0; i < byte_count; ++i)
  {
    value[0] = *((int16_t *)(p + 4*i + 0));
    value[1] = *((int16_t *)(p + 4*i + 2));
    printf("%5d %5d\n", value[0], value[1]);
  }

}

/******************************************************************************************************
* LINUX GPIO INITIALIZATION
* This function performs two operations:
* 1) Opens a device to memory window in Linux so a GPIO that exists at a physical address is mapped
*    to a fixed logical address. This logical address is returned by the function.
* 2) Initialize the GPIO for either input or output mode.
*
* INPUT PARAMETERS:
* gpio_base_address - physical hardware base address of GPIO, you have to get this from XML file
* direction - 32 bits indicating direction for each bit; 0 - output; 1 - input
* first_call - boolean indicating that this is first call to function. The first time and only the first
*              time should the Linux device memory mapping service be mounted. Call for subsequent
*              gpio mapping this should be set to FALSE (0).
*
* RETURNS:
* mapped_dev_base - memory pointer to the GPIO that was specified by the gpio_base_address
*******************************************************************************************************/
/*void *dma_initialize(int dma_base_address, int first_call) //,int direction)
{
        void *mapped_dev_base;
        off_t dev_base = DMA_BASE_ADDRESS;//gpio_base_address;

        // Linux service to directly access PL hardware as memory without using a device driver
        // The memory mapping to device service should only be called once
        if (first_call) {
                memfd = open("/dev/mem", O_RDWR | O_SYNC);
                if (memfd == -1) {
                        printf("Can't open /dev/mem.\n");
                        exit(0);
                }
                printf("/dev/mem opened.\n");
        }

        // Map one page of memory into user space such that the device is in that page, but it may not
        // be at the start of the page.
        mapped_base = mmap(0, MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, memfd, dev_base & ~MAP_MASK);
    if (mapped_base == (void *) -1) {
        printf("Can't map the memory to user space for DMA access.\n");
        exit(0);
    }
    printf("DMA memory mapped at address %p.\n", mapped_base);

    // Get the address of the device in user space which will be an offset from the base
    // that was mapped as memory is mapped at the start of a page
    mapped_dev_base = mapped_base + (dev_base & MAP_MASK);

    // Slight delay for Linux memory access problem
    usleep(50);
    // write to the direction GPIO direction register to set as all inputs or outputs
    //*((volatile unsigned long *) (mapped_dev_base + GPIO_DIRECTION_OFFSET)) = direction;
    return mapped_dev_base;
}*/


int main() {
    int dh = open("/dev/mem", O_RDWR | O_SYNC); // Open /dev/mem which represents the whole physical memory
    unsigned int* virtual_address = mmap(NULL, 65535, PROT_READ | PROT_WRITE, MAP_SHARED, dh, 0x40400000); // Memory map AXI Lite register block
    unsigned int* virtual_source_address  = mmap(NULL, 65535, PROT_READ | PROT_WRITE, MAP_SHARED, dh, 0x0e000000); // Memory map source address
    unsigned int* virtual_destination_address = mmap(NULL, 65535, PROT_READ | PROT_WRITE, MAP_SHARED, dh, 0x0f000000); // Memory map destination address

    virtual_source_address[0]= 0x11223344; // Write random stuff to source block
    memset(virtual_destination_address, 0, 32); // Clear destination block

    printf("Source memory block:      "); memdump(virtual_source_address, 32);
    printf("Destination memory block: "); memdump(virtual_destination_address, 32);

    printf("Resetting DMA\n");
    dma_set(virtual_address, S2MM_CR, 4);
    dma_set(virtual_address, MM2S_CR, 4);
    dma_s2mm_status(virtual_address);
    dma_mm2s_status(virtual_address);

    printf("Halting DMA\n");
    dma_set(virtual_address, S2MM_CR, 0);
    dma_set(virtual_address, MM2S_CR, 0);
    dma_s2mm_status(virtual_address);
    dma_mm2s_status(virtual_address);

    printf("Writing destination address\n");
    dma_set(virtual_address, S2MM_DST_ADDR, 0x0f000000); // Write destination address
    dma_s2mm_status(virtual_address);

    printf("Writing source address...\n");
    dma_set(virtual_address, MM2S_SRC_ADDR, 0x0e000000); // Write source address
    dma_mm2s_status(virtual_address);

    printf("Starting S2MM channel with all interrupts masked...\n");
    dma_set(virtual_address, S2MM_CR, 0xf001);
    dma_s2mm_status(virtual_address);

    printf("Starting MM2S channel with all interrupts masked...\n");
    dma_set(virtual_address, MM2S_CR, 0xf001);
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
}
