#include <linux/interrupt.h>
#include <linux/irq.h>
#include <linux/platform_device.h>
#include <linux/slab.h>
#include <asm/io.h>
#include <linux/init.h>           // Macros used to mark up functions e.g. __init __exit
#include <linux/module.h>         // Core header for loading LKMs into the kernel
#include <linux/device.h>         // Header to support the kernel Driver Model
#include <linux/kernel.h>         // Contains types, macros, functions for the kernel
#include <linux/fs.h>             // Header for the Linux file system support
#include <linux/uaccess.h>          // Required for the copy to user function
#define  DEVICE_NAME "gpioint"    ///< The device will appear at /dev/gpioint using this value
#define  CLASS_NAME  "gpint"        ///< The device class -- this is a character device driver

MODULE_LICENSE("GPL");            ///< The license type -- this affects available functionality
MODULE_AUTHOR("Horacio Arnaldi");    ///< The author -- visible when you use modinfo
MODULE_DESCRIPTION("A simple Linux char driver for the RP");  ///< The description -- see modinfo
MODULE_VERSION("0.1");            ///< A version number to inform users

#define IRQ_NUM		168

#define XIL_AXI_TIMER_BASEADDR 0x40000000
#define XIL_AXI_TIMER_HIGHADDR 0x40000FFF

#define XIL_AXI_TIMER_TCSR_OFFSET		0x0
#define XIL_AXI_TIMER_TLR_OFFSET		0x4
#define XIL_AXI_TIMER_TCR_OFFSET		0x8

#define XIL_AXI_TIMER_CSR_INT_OCCURED_MASK	0x00000100

#define XIL_AXI_TIMER_CSR_CASC_MASK		     0x00000800
#define XIL_AXI_TIMER_CSR_ENABLE_ALL_MASK	 0x00000400
#define XIL_AXI_TIMER_CSR_ENABLE_PWM_MASK	 0x00000200
#define XIL_AXI_TIMER_CSR_INT_OCCURED_MASK 0x00000100
#define XIL_AXI_TIMER_CSR_ENABLE_TMR_MASK	 0x00000080
#define XIL_AXI_TIMER_CSR_ENABLE_INT_MASK	 0x00000040
#define XIL_AXI_TIMER_CSR_LOAD_MASK        0x00000020
#define XIL_AXI_TIMER_CSR_AUTO_RELOAD_MASK 0x00000010
#define XIL_AXI_TIMER_CSR_EXT_CAPTURE_MASK 0x00000008
#define XIL_AXI_TIMER_CSR_EXT_GENERATE_MASK	0x00000004
#define XIL_AXI_TIMER_CSR_DOWN_COUNT_MASK	  0x00000002
#define XIL_AXI_TIMER_CSR_CAPTURE_MODE_MASK	0x00000001

#define TIMER_CNT	0xF8000000

static int    majorNumber;                  ///< Stores the device number -- determined automatically
static char   message[256] = {0};           ///< Memory for the string that is passed from userspace
static short  size_of_message;              ///< Used to remember the size of the string stored
static int    numberOpens = 0;              ///< Counts the number of times the device is opened
static struct class*  gpiocharClass  = NULL; ///< The device-driver class struct pointer
static struct device* gpiocharDevice = NULL; ///< The device-driver device struct pointer

DECLARE_WAIT_QUEUE_HEAD(hq);
 
static int x=0;
 
// The prototype functions for the character driver -- must come before the
// struct definition
static int     dev_open(struct inode *, struct file *);
static int     dev_release(struct inode *, struct file *);
static ssize_t dev_read(struct file *, char *, size_t, loff_t *);
static ssize_t dev_write(struct file *, const char *, size_t, loff_t *);

/** @brief Devices are represented as file structure in the kernel. The
 * file_operations structure from
 *  /linux/fs.h lists the callback functions that you wish to associated with
 *  your file operations
 *  using a C99 syntax structure. char devices usually implement open, read,
 *  write and release calls
 */
static struct file_operations fops =
{
   .open = dev_open,
   .read = dev_read,
   .write = dev_write,
   .release = dev_release,
};

static struct platform_device *pdev;
void *dev_virtaddr;
static int int_cnt;

static irqreturn_t xilaxitimer_isr(int irq,void*dev_id)		
{      
	unsigned int data;
    x=1;
    wake_up(&hq);
    printk(KERN_DEBUG "Interrupt\n");


	/* 
	 * Check Timer Counter Value
	 */
	data = ioread32(dev_virtaddr + XIL_AXI_TIMER_TCR_OFFSET);
	printk("xilaxitimer_isr: Interrupt Occurred ! Timer Count = 0x%08X\n",data);

	/* 
	 * Clear Interrupt
	 */
	data = ioread32(dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);
	iowrite32(data | XIL_AXI_TIMER_CSR_INT_OCCURED_MASK, dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);

	/* 
	 * Disable Timer after 100 Interrupts
	 */
	int_cnt++;

	if (int_cnt>=100)
	{
					printk("xilaxitimer_isr: 100 interrupts have been occurred. Disabling timer");
					data = ioread32(dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);
					//iowrite32(data & ~(XIL_AXI_TIMER_CSR_ENABLE_TMR_MASK), dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);
	}

	return IRQ_HANDLED;
}

/** @brief The device open function that is called each time the device is
 * opened
 *  This will only increment the numberOpens counter in this case.
 *  @param inodep A pointer to an inode object (defined in linux/fs.h)
 *  @param filep A pointer to a file object (defined in linux/fs.h)
 */
static int dev_open(struct inode *inodep, struct file *filep){
   numberOpens++;
   printk(KERN_INFO "gpioChar: Device has been opened %d time(s)\n", numberOpens);
   return 0;
}

/** @brief This function is called whenever device is being read from user space
 * i.e. data is
 *  being sent from the device to the user. In this case is uses the
 *  copy_to_user() function to
 *  send the buffer string to the user and captures any errors.
 *  @param filep A pointer to a file object (defined in linux/fs.h)
 *  @param buffer The pointer to the buffer to which this function writes the
 *  data
 *  @param len The length of the b
 *  @param offset The offset if required
 */
static ssize_t dev_read(struct file *filep, char *buffer, size_t len, loff_t *offset){
   int error_count = 0;

   wait_event(hq,x);
   x=0;
   // copy_to_user has the format ( * to, *from, size) and returns 0 on success
   error_count = copy_to_user(buffer, message, size_of_message);

   if (error_count==0){            // if true then have success
      printk(KERN_INFO "gpioChar: Sent %d characters to the user\n", size_of_message);
      return (size_of_message=0);  // clear the position to the start and return 0
   }
   else {
      printk(KERN_INFO "gpioChar: Failed to send %d characters to the user\n", error_count);
      return -EFAULT;              // Failed -- return a bad address message (i.e. -14)
   }
}

/** @brief This function is called whenever the device is being written to from
 * user space i.e.
 *  data is sent to the device from the user. The data is copied to the
 *  message[] array in this
 *  LKM using the sprintf() function along with the length of the string.
 *  @param filep A pointer to a file object
 *  @param buffer The buffer to that contains the string to write to the device
 *  @param len The length of the array of data that is being passed in the const
 *  char buffer
 *  @param offset The offset if required
 */
static ssize_t dev_write(struct file *filep, const char *buffer, size_t len, loff_t *offset){
   sprintf(message, "%s(%zu letters)", buffer, len);   // appending received string with its length
   size_of_message = strlen(message);                 // store the length of the stored message
   printk(KERN_INFO "gpioChar: Received %zu characters from the user\n", len);
   return len;
}

/** @brief The device release function that is called whenever the device is
 * closed/released by
 *  the userspace program
 *  @param inodep A pointer to an inode object (defined in linux/fs.h)
 *  @param filep A pointer to a file object (defined in linux/fs.h)
 */
static int dev_release(struct inode *inodep, struct file *filep){
   printk(KERN_INFO "gpioChar: Device successfully closed\n");
   return 0;
}



static int __init xilaxitimer_init(void)  
{
	unsigned int data;

	int_cnt = 0;

	printk(KERN_INFO "xilaxitimer_init: Initialize Module \"%s\"\n", DEVICE_NAME);

  // Try to dynamically allocate a major number for the device -- more difficult
  // but worth it
   majorNumber = register_chrdev(0, DEVICE_NAME, &fops);
   if (majorNumber<0){
      printk(KERN_ALERT "gpioChar failed to register a major number\n");
      return majorNumber;
   }
   printk(KERN_INFO "gpioChar: registered correctly with major number %d\n", majorNumber);

   // Register the device class
   gpiocharClass = class_create(THIS_MODULE, CLASS_NAME);
   if (IS_ERR(gpiocharClass)){                // Check for error and clean up if there is
      unregister_chrdev(majorNumber, DEVICE_NAME);
      printk(KERN_ALERT "Failed to register device class\n");
      return PTR_ERR(gpiocharClass);          // Correct way to return an error on a pointer
   }
   printk(KERN_INFO "gpioChar: device class registered correctly\n");

   // Register the device driver
   gpiocharDevice = device_create(gpiocharClass, NULL, MKDEV(majorNumber, 0), NULL, DEVICE_NAME);
   if (IS_ERR(gpiocharDevice)){               // Clean up if there is an error
      class_destroy(gpiocharClass);           // Repeated code but the alternative is goto statements
      unregister_chrdev(majorNumber, DEVICE_NAME);
      printk(KERN_ALERT "Failed to create the device\n");
      return PTR_ERR(gpiocharDevice);
   }
   printk(KERN_INFO "gpioChar: device class created correctly\n"); // Made it! device was initialized

	/* Register ISR */
	if (request_irq(IRQ_NUM, xilaxitimer_isr, 0, DEVICE_NAME, NULL)) {
					printk(KERN_ERR "xilaxitimer_init: Cannot register IRQ %d\n", IRQ_NUM);
					return -EIO;
	}
	else {
					printk(KERN_INFO "xilaxitimer_init: Registered IRQ %d\n", IRQ_NUM);
	}

	/* Map Physical address to Virtual address 	 */
	dev_virtaddr = ioremap_nocache(XIL_AXI_TIMER_BASEADDR, XIL_AXI_TIMER_HIGHADDR - XIL_AXI_TIMER_BASEADDR + 1);

	/* Set Timer Counter 	 */
	iowrite32(TIMER_CNT,dev_virtaddr + XIL_AXI_TIMER_TLR_OFFSET);
	data = ioread32(dev_virtaddr + XIL_AXI_TIMER_TLR_OFFSET);
	printk("xilaxitimer_init: Set timer count 0x%08X\n",data);

	/* Set Timer mode and enable interrupt */
	iowrite32(XIL_AXI_TIMER_CSR_LOAD_MASK, dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);
	iowrite32(XIL_AXI_TIMER_CSR_ENABLE_INT_MASK | XIL_AXI_TIMER_CSR_AUTO_RELOAD_MASK, dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);

	/* Register Device Module */
	pdev = platform_device_register_simple(DEVICE_NAME, 0, NULL, 0);              
	if (pdev == NULL) {                                                     
					printk(KERN_WARNING "xilaxitimer_init: Adding platform device \"%s\" failed\n", DEVICE_NAME);
					kfree(pdev);                                                             
					return -ENODEV;                                                          
	}

	/* Start Timer */
	data = ioread32(dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);
	iowrite32(data | XIL_AXI_TIMER_CSR_ENABLE_TMR_MASK, dev_virtaddr + XIL_AXI_TIMER_TCSR_OFFSET);
	printk("xilaxitimer_init: data read 0x%08X\n",data);

	return 0;
} 

static void __exit xilaxitimer_exit(void)  		
{
	/* Exit Device Module */
   device_destroy(gpiocharClass, MKDEV(majorNumber, 0));     // remove the device
   class_unregister(gpiocharClass);                          // unregister the device class
   class_destroy(gpiocharClass);                             // remove the device class
   unregister_chrdev(majorNumber, DEVICE_NAME);             // unregister the major number
   printk(KERN_INFO "gpioChar: Goodbye from the LKM!\n");

	iounmap(dev_virtaddr);
	free_irq(IRQ_NUM, NULL);
	platform_device_unregister(pdev);                                             
	printk(KERN_INFO "xilaxitimer_edit: Exit Device Module \"%s\".\n", DEVICE_NAME);
}

module_init(xilaxitimer_init);
module_exit(xilaxitimer_exit);

MODULE_AUTHOR ("Xilinx");
MODULE_DESCRIPTION("Test Driver for Zynq PL AXI Timer.");
MODULE_LICENSE("GPL v2");
MODULE_ALIAS("custom:xilaxitimer");
