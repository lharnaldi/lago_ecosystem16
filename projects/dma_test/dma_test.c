/**
 * Proof of concept offloaded memcopy using AXI Direct Memory Access v7.1
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <sys/mman.h>

#define MM2S_CR       0x00
#define MM2S_SR       0x04
#define MM2S_SRC_ADDR 0x18
#define MM2S_LENGTH   0x28

#define S2MM_CR       0x30
#define S2MM_SR       0x34
#define S2MM_DST_ADDR 0x48
#define S2MM_LENGTH   0x58

unsigned int dma_set(unsigned int* dma_virtual_address, int offset, unsigned int value) {
    dma_virtual_address[offset>>2] = value;
}

unsigned int dma_get(unsigned int* dma_virtual_address, int offset) {
    return dma_virtual_address[offset>>2];
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

void memdump(void* virtual_address, int byte_count) {
    char *p = virtual_address;
    int offset, i;
    int16_t value[2];

    for(i = 0; i < byte_count; ++i)
    {
      value[0] = *((int16_t *)(p + 4*i + 0));
      value[1] = *((int16_t *)(p + 4*i + 2));
      printf("%5d %5d\n", value[0], value[1]);
    }

}


int main() {
    int dh = open("/dev/mem", O_RDWR | O_SYNC); // Open /dev/mem which represents the whole physical memory
    unsigned int* virtual_address = mmap(NULL, 16*sysconf(_SC_PAGESIZE), PROT_READ | PROT_WRITE, MAP_SHARED, dh, 0x40400000); // Memory map AXI Lite register block
    unsigned int* virtual_source_address  = mmap(NULL, 1024*sysconf(_SC_PAGESIZE), PROT_READ | PROT_WRITE, MAP_SHARED, dh, 0x0e000000); // Memory map source address
    unsigned int* virtual_destination_address = mmap(NULL, 1024*sysconf(_SC_PAGESIZE), PROT_READ | PROT_WRITE, MAP_SHARED, dh, 0x0f00000); // Memory map destination address

//    virtual_source_address[0]= 0x11223344; // Write random stuff to source block
//    memset(virtual_destination_address, 0, 32); // Clear destination block

//    printf("Source memory block:      "); memdump(virtual_source_address, 32);
//    printf("Destination memory block: "); memdump(virtual_destination_address, 32);

    printf("Resetting DMA\n");
    dma_set(virtual_address, S2MM_CR, 4);
//    dma_set(virtual_address, MM2S_CR, 4);
    dma_s2mm_status(virtual_address);
//    dma_mm2s_status(virtual_address);

    printf("Halting DMA\n");
    dma_set(virtual_address, S2MM_CR, 0);
//    dma_set(virtual_address, MM2S_CR, 0);
    dma_s2mm_status(virtual_address);
//    dma_mm2s_status(virtual_address);

    printf("Writing destination address\n");
    dma_set(virtual_address, S2MM_DST_ADDR, 0x0f000000); // Write destination address
    dma_s2mm_status(virtual_address);

//    printf("Writing source address...\n");
//    dma_set(virtual_address, MM2S_SRC_ADDR, 0x0e000000); // Write source address
//    dma_mm2s_status(virtual_address);

    printf("Starting S2MM channel with all interrupts masked...\n");
    dma_set(virtual_address, S2MM_CR, 0xf001);
    dma_s2mm_status(virtual_address);

/*    printf("Starting MM2S channel with all interrupts masked...\n");
    dma_set(virtual_address, MM2S_CR, 0xf001);
    dma_mm2s_status(virtual_address);
*/
    printf("Writing S2MM transfer length...\n");
    dma_set(virtual_address, S2MM_LENGTH, 4096);
    dma_s2mm_status(virtual_address);

/*    printf("Writing MM2S transfer length...\n");
    dma_set(virtual_address, MM2S_LENGTH, 32);
    dma_mm2s_status(virtual_address);

    printf("Waiting for MM2S synchronization...\n");
    dma_mm2s_sync(virtual_address);
*/
    printf("Waiting for S2MM sychronization...\n");
    dma_s2mm_sync(virtual_address); // If this locks up make sure all memory ranges are assigned under Address Editor!

//    dma_s2mm_status(virtual_address);
//    dma_mm2s_status(virtual_address);

    printf("Destination memory block: "); memdump(virtual_destination_address, 4096);

    if (munmap(virtual_address, sysconf(_SC_PAGESIZE)) == -1)
        {
                printf("Can't unmap memory from user space.\n");
                exit(0);
        }
    if (munmap(virtual_source_address, 1024*sysconf(_SC_PAGESIZE)) == -1)
        {
                printf("Can't unmap memory from user space.\n");
                exit(0);
        }
    if (munmap(virtual_destination_address, 1024*sysconf(_SC_PAGESIZE)) == -1)
        {
                printf("Can't unmap memory from user space.\n");
                exit(0);
        }
    close(dh);

}
