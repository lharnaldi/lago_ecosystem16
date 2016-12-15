/*
* DMA memory allocation
* This kernel module allocates coherent, non-cached memory 
* and returns the physical and virtual address of the allocated buffer
*/

#include <linux/module.h>
#include <linux/init.h>
#include <linux/fs.h>
#include <linux/slab.h>
#include <linux/dma-mapping.h>
#include <linux/device.h>
#include <linux/cdev.h>

#include "memalloc.h"

#define DEVICE_NAME "memalloc"

// Max number of buffers
#define BUFFER_MAX_NUMBER 16

// Structure for buffer information
struct bufferInfo {
	int active;
	int size;
	dma_addr_t handle;
	int *kernelAddress;
};
static struct bufferInfo bufferInfoTable[BUFFER_MAX_NUMBER];

// Defines which buffer is currently active - for mmap
static int activeBufferID;

struct memAllocIF {
	struct device *device_p;
	dev_t dev_node;
	struct cdev cdev;
	struct class *class_p;
};

static struct memAllocIF interface;

// Methods

static int releaseBuffer(int i)
{
	if (i > BUFFER_MAX_NUMBER)
	{
		printk("Wrong bufferID %d\n", i);
		return -1;
	}
	printk("Releasing buffer %d\n", i);
	bufferInfoTable[i].active = 0;
	dma_free_coherent(NULL, bufferInfoTable[i].size, bufferInfoTable[i].kernelAddress, bufferInfoTable[i].handle);
	return 0;
}

static int reserveBuffer(size_t size)
{
	int i;
	
	for (i = 0; i < BUFFER_MAX_NUMBER; i++)
	{
		if (bufferInfoTable[i].active == 0)
		{
			printk("Reserving buffer %d\n", i);
			bufferInfoTable[i].active = 1;
			break;
		}
	}
	
	if (i < BUFFER_MAX_NUMBER)
	{
		bufferInfoTable[i].kernelAddress = dma_alloc_coherent(NULL, size, &bufferInfoTable[i].handle, GFP_KERNEL);
		if (bufferInfoTable[i].kernelAddress == NULL)
		{
			printk("Allocation failure\n");
			return -1;
		}
		printk("Allocated buffer with Paddr = %X\n", (unsigned int)bufferInfoTable[i].handle);
		bufferInfoTable[i].size = (int)size;
		return i;
	}
	else
	{
		printk("No buffer available\n");
		return -1;
	}
}

static void cleanup(void)
{
	int i;
	for (i = 0; i < BUFFER_MAX_NUMBER; i++)
	{
		if (bufferInfoTable[i].active != 0)
		{
			dma_free_coherent(NULL, bufferInfoTable[i].size, bufferInfoTable[i].kernelAddress, bufferInfoTable[i].handle);
			bufferInfoTable[i].active = 0;
		}
	}
}

static unsigned int memAllocGetPhysical (int i)
{
	if (i > BUFFER_MAX_NUMBER || bufferInfoTable[i].active == 0)
	{
		printk("Wrong bufferID %d\n", i);
		return -1;
	}
	return (unsigned int)bufferInfoTable[i].handle;
}

static long memAllocIoctl (struct file *fd, unsigned int cmd, unsigned long arg)
{

  printk("received command %u arg %lu\n", cmd, arg);
	switch(cmd)
	{
		case MEMALLOC_RESERVE:
			return reserveBuffer(arg);
			break;
		case MEMALLOC_RELEASE:
			return releaseBuffer(arg);
			break;
		case MEMALLOC_GET_PHYSICAL:
			return memAllocGetPhysical(arg);
			break;
		case MEMALLOC_ACTIVATE_BUFFER:
			if (arg > BUFFER_MAX_NUMBER || bufferInfoTable[arg].active == 0)
			{
				printk("Wrong bufferID %lu\n", arg);
				return -1;
			}
			activeBufferID = arg;
			return arg;
			break;
		default:
		  printk("Wrong command: %d\n", cmd);
			return -1;
			break;
	}
}

static int memAllocMmap (struct file *fd, struct vm_area_struct *vma)
{
  return dma_common_mmap(interface.device_p, vma, bufferInfoTable[activeBufferID].kernelAddress, bufferInfoTable[activeBufferID].handle, vma->vm_end-vma->vm_start);
}

static int memAllocRelease(struct inode *in, struct file *fd)
{
	cleanup();
	return 0;
}

static int memAllocOpen(struct inode *ino, struct file *file)
{
        file->private_data = container_of(ino->i_cdev, struct memAllocIF, cdev);

	return 0;
}

static struct file_operations fops = {
	.unlocked_ioctl = memAllocIoctl,
	.mmap = memAllocMmap,
	.release = memAllocRelease,
	.open = memAllocOpen
};

static int __init memAllocInit(void)
{
	int rc;
	int i;
	static struct class *local_class_p = NULL;
	
	printk("Loading DMA allocation module\n");

	// Allocate a character device from the kernel for this driver
	rc = alloc_chrdev_region(&interface.dev_node, 0, 1, DEVICE_NAME);
	if (rc) 
	{
		printk("Unable to get a char device number\n");
		return rc;
	}
	
	// Initialize the ter device data structure before registering the character device with the kernel
	cdev_init(&interface.cdev, &fops);
	rc = cdev_add(&interface.cdev, interface.dev_node, 1);
	if (rc)
	{
		printk("Unable to add char device\n");
		cdev_del(&interface.cdev);
		return rc;
	}
	
	// Create the device in sysfs which will allow the device node in /dev to be created 
	local_class_p = class_create(THIS_MODULE, DEVICE_NAME);
	interface.class_p = local_class_p;
	
	// Create the device node in /dev so the device is accessible as a character device
	interface.device_p = device_create(interface.class_p, NULL, interface.dev_node, NULL, DEVICE_NAME);

	if (IS_ERR(interface.device_p)) 
	{
		printk("Unable to create the device\n");
		class_destroy(interface.class_p);
		cdev_del(&interface.cdev);
		return rc;
	}
	
	for (i = 0; i < BUFFER_MAX_NUMBER; i++)
	{
		bufferInfoTable[activeBufferID].active = 0;
	}
	
	return 0;
}

static void __exit my_memAllocExit(void)
{
	printk("Module unloading\n");
	cleanup();
	cdev_del(&interface.cdev);
	device_destroy(interface.class_p, interface.dev_node);
	class_destroy(interface.class_p);
	unregister_chrdev_region(interface.dev_node, 1);
}

module_init(memAllocInit);
module_exit(my_memAllocExit);

MODULE_AUTHOR("Massimiliano Giacometti");
MODULE_DESCRIPTION("Create a buffer and return physical and virtual address, for DMA userspace driver");
MODULE_LICENSE("GPL");
