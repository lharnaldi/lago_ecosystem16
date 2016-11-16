/*
* blink.c - Create an input/output character device
*/
#include <linux/kernel.h> /* We're doing kernel work */
#include <linux/module.h> /* Specifically, a module */
#include <linux/fs.h>
#include <asm/uaccess.h> /* for get_user and put_user */
#include <asm/io.h>
#include "blink.h"
#define SUCCESS 0
#define DEVICE_NAME "/dev/blink_Dev"


#define BLINK_CTRL_REG 	0x7C600000
static void *mmio;
static int major_num;

/*
* Is the device open right now? Used to prevent
* concurent access into the same device
*/
static int Device_Open = 0;


static void set_blink_ctrl(void)
{
	printk("KERNEL PRINT : set_blink_ctrl \n\r");
	*(unsigned int *)mmio = 0x1;
}



static void reset_blink_ctrl(void)
{

	printk("KERNEL PRINT : reset_blink_ctrl \n\r");
	*(unsigned int *)mmio = 0x0;
}
/*
* This is called whenever a process attempts to open the device file
*/
static int device_open(struct inode *inode, struct file *file)
{
	#ifdef DEBUG
		printk(KERN_INFO "device_open(%p)\n", file);
	#endif
	/*
	* We don't want to talk to two processes at the same time
	*/
	if (Device_Open)
		return -EBUSY;
	Device_Open++;
	/*
	* Initialize the message
	*/
//	Message_Ptr = Message;
	try_module_get(THIS_MODULE);
	return SUCCESS;
}
static int device_release(struct inode *inode, struct file *file)
{
	#ifdef DEBUG
		printk(KERN_INFO "device_release(%p,%p)\n", inode, file);
	#endif
	/*
	* We're now ready for our next caller
	*/
	Device_Open--;
	module_put(THIS_MODULE);
	return SUCCESS;
}
/*
* This function is called whenever a process which has already opened the
* device file attempts to read from it.
*/
static ssize_t device_read(	struct file *file, /* see include/linux/fs.h */
							char __user * buffer, /* buffer to be filled with data */
							size_t length, /* length of the buffer */
							loff_t * offset)
{
	return SUCCESS;
}
/*
* This function is called when somebody tries to
* write into our device file.
*/
static ssize_t device_write(struct file *file,
							const char __user * buffer, 
							size_t length, 
							loff_t * offset)
{
	return SUCCESS;
}
/*
* This function is called whenever a process tries to do an ioctl on our
* device file. We get two extra parameters (additional to the inode and file
* structures, which all device functions get): the number of the ioctl called
* and the parameter given to the ioctl function.
*
* If the ioctl is write or read/write (meaning output is returned to the
* calling process), the ioctl call returns the output of this function.
*
*/
int device_ioctl(			struct file *file, /* ditto */
					unsigned int ioctl_num, /* number and param for ioctl */
					unsigned long ioctl_param)
{
//	int i;
	char *temp;
//	char ch;
	/*
	* Switch according to the ioctl called
	*/
	switch (ioctl_num) 
	{
	case IOCTL_ON_LED:
		
		temp = (char *)ioctl_param;
		set_blink_ctrl();
	break;
	case IOCTL_STOP_LED:
		temp = (char *)ioctl_param;
		reset_blink_ctrl();
	break;
	
	}
	return SUCCESS;
}
/* Module Declarations */
/*
* This structure will hold the functions to be called
* when a process does something to the device we
* created. Since a pointer to this structure is kept in
* the devices table, it can't be local to
* init_module. NULL is for unimplemented functions.
*/
struct file_operations Fops = {
								.read = device_read,
								.write = device_write,
								.unlocked_ioctl = device_ioctl,
								.open = device_open,
								.release = device_release, /*close */								};
/*
* Initialize the module - Register the character device
*/
int init_module()
{
	int ret_val;
	
	/*
	* Register the character device (atleast try)
	*/
	major_num = register_chrdev(0,DEVICE_NAME, &Fops);
	/*
	* Negative values signify an error
	*/
	if (major_num < 0) 
	{
		printk(KERN_ALERT "%s failed with %d\n","Sorry, registering the character device ", ret_val);
		return ret_val;
	}
	printk(KERN_INFO "%s The major device number is %d.\n",
	"Registeration is a success", major_num);
	printk(KERN_INFO "If you want to talk to the device driver,\n");
	printk(KERN_INFO "Than create a device file by following command. \n");
	printk(KERN_INFO "mknod %s c %d 0\n", DEVICE_FILE_NAME, major_num);
	printk(KERN_INFO "The device file name is important, because\n");
	printk(KERN_INFO "the ioctl program assumes that's the\n");
	printk(KERN_INFO "file you'll use.\n");

	mmio = ioremap(BLINK_CTRL_REG,0x100);

	return 0;
}
/*
* Cleanup - unregister the appropriate file from /proc
*/
void cleanup_module()
{
	int ret;
	/*
	* Unregister the device
	*/
	iounmap(mmio);
	unregister_chrdev(major_num,DEVICE_NAME);
}

