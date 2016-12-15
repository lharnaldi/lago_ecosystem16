#ifndef MEMALLOC_H
#define MEMALLOC_H

#ifdef __cplusplus
extern "C" {
#endif

#include <linux/types.h>
#include <asm/ioctl.h>

static long memAllocIoctl (struct file *, unsigned int, unsigned long);
static int memAllocMmap (struct file *, struct vm_area_struct *);
static int memAllocRelease (struct inode *, struct file *);
static int memAllocOpen(struct inode *, struct file *);

enum memAllocCmd
{ 
    MEMALLOC_RESERVE = 0, 
    MEMALLOC_RELEASE = 1,
    MEMALLOC_GET_VIRTUAL = 2, 
    MEMALLOC_GET_PHYSICAL = 3,
    MEMALLOC_ACTIVATE_BUFFER = 4,
};

#ifdef __cplusplus
}
#endif
#endif                          /* MEMALLOC_H */
