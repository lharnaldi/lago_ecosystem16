#include <stdlib.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <stdio.h>

// derive this from memalloc.h
enum memAllocCmd
{ 
    MEMALLOC_RESERVE = 0, 
    MEMALLOC_RELEASE = 1,
    MEMALLOC_GET_VIRTUAL = 2, 
    MEMALLOC_GET_PHYSICAL = 3,
    MEMALLOC_ACTIVATE_BUFFER = 4,
};

int main () 
{
    int memAllocFd;
    volatile int iVaddr;
    volatile int oVaddr;
    volatile int iVaddr_2;
    volatile int oVaddr_2;
    volatile void * iPaddr;
    volatile void * oPaddr;

    int iBufID;
    int oBufID;

    int size = 2048;

    memAllocFd = open("/dev/memalloc", O_RDWR);

    // create iBuffer
    iBufID = ioctl(memAllocFd, MEMALLOC_RESERVE, size);
    iPaddr = (void *)ioctl(memAllocFd, MEMALLOC_GET_PHYSICAL, iBufID);
    ioctl(memAllocFd, MEMALLOC_ACTIVATE_BUFFER, iBufID);
    iVaddr = (int)mmap(0, size, PROT_READ | PROT_WRITE, MAP_SHARED, memAllocFd, 0);
    ioctl(memAllocFd, MEMALLOC_GET_VIRTUAL, iBufID);
    /*
    if (iVaddr != iVaddr_2)
    {
      printf("Error: virtual addresses for buffer %d don't match: %X %X\n", iBufID, iVaddr, iVaddr_2);
    }
    */

    // create oBuffer
    oBufID = ioctl(memAllocFd, MEMALLOC_RESERVE, size);
    oPaddr = (void *)ioctl(memAllocFd, MEMALLOC_GET_PHYSICAL, oBufID);
    ioctl(memAllocFd, MEMALLOC_ACTIVATE_BUFFER, oBufID);
    oVaddr = (int)mmap(0, size, PROT_READ | PROT_WRITE, MAP_SHARED, memAllocFd, 0);
    ioctl(memAllocFd, MEMALLOC_GET_VIRTUAL, oBufID);
    /*
    if (oVaddr != oVaddr_2)
    {
      printf("Error: virtual addresses for buffer %d don't match: %X %X\n", oBufID, oVaddr, oVaddr_2);
    }
    */
    ioctl(memAllocFd, MEMALLOC_RELEASE, iBufID);
    ioctl(memAllocFd, MEMALLOC_RELEASE, oBufID);

    return 0;
}
