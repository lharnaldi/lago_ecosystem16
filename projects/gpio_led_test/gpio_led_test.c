/* basic_design_zynq_hw_exerciser.c
 *
 * This program demonstrates the basic capabilities of a Zynq platform
 * communicating with two axi_gpio peripherals (from the IP catalog) that
 * are implemented as hardware in the PL.
 *
 * NOTE: THE GPIO THAT IS CONTAINED IN THE PS IS NOT BEING USED
 *
 * One of the GPIO's is configured as an 8 bit output driving 8 LED's.
 * The other GPIO is configured as a three input device being driven
 * from push buttons.
 *
 * The program functions in a forever loop, monitoring the input push
 * buttons.  The three buttons are UP, DOWN, and STOP that directly
 * control the a binary counting pattern on the LED's.
 *
 * This application is written to either, use the Standalone library
 * or be compiled as a Linux application. Either flow is supported in
 * the SDK programming development. The default compilation is using
 * the Standalone library. To compile this application as a Linux
 * application, add to the properties of the associated application
 * project, a #define of a symbol named "LINUX_APP". Select properties and
 * C/C++ Build => Settings => ARM Linux gcc compiler => Symbols,
 * adding a -D LINUX_APP to the gcc compiler tool command line.
 *
 * The hardware (axi_gpio) physical device pinout in the PL may vary
 * with the target evaluation board being used. This variation is
 * typically manifested in the constraints file which determines
 * device pin locations for the actual pin numbers used for the LED's
 * and pushbuttons. Other variations in the hardware may be needed to
 * accommodate the fact that varying numbers of pushbutton inputs or
 * LED output actually exist.
 * 
 * The goal is that  this application can be targeted to multiple
 * hardware Zynq platforms (or configurations) either as a Standalone
 * or Linux application.
 *
 * THE FOLLOWING HARDWARE PLATFORMS ARE DEFINED
 * ZC702 BOARD
 * LED's - Eight LED's, DS15-DS22, located towards the center of the
 *         board from the SD card slot
 * Push Buttons - Only two buttons are use, located adjacent to the LED's
 *         UP - SW7
 *         DOWN - SW5
 *         STOP - Pressing both, SW5 and SW7, at the same time provides a STOP
 *         (Due to a lack of pushbuttons accessible by PL pins, hardware
 *          in the PL was added to emulate a third button)
 *
 * ZC702 BOARD WITH CE (Customer Education) FMC CARD IN FMC1 SLOT
 * LED's - Eight LED's, LD0-LD7, located between slide switches and LCD display
 * Push Buttons - Rosetta buttons located on CE FMC card,
 *         UP - BTN3 - West
 *         DOWN - BTN0 - Center
 *         STOP - BTN1 - East
 *
 * ******************************************************************************************************************
 *
 * 
 *   basic_design_exerciser
 *   Ver.:  1.0    6/1/2012 WK/LR
 *
 *   This code generates an LED pattern for the 8 bit LED array present on the ZC702 board. It must have
 *   one of several symbols defined: 
 *      hardware_test   - infinite loop,         long delays for LEDs so user can visually recognize what is happening, uses standalone drivers
 *      profiler_test   - finite loop for gprof, short delays so profiler doesn't report all the activity being in the wait_loop function, uses standalone drivers
 *      CSP_test        - infinite loop,         short delays so multiple datum can be captured with the Analyzer, uses standalone drivers
 *      LINUX_APP       - infinite loop,         long delays for LEDs so user can visually recogize what is happening, uses Linux drivers
 *
 * ******************************************************************************************************************
 */

#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

// Stuff needed for Linux DEVMEM access
#define MAP_SIZE 4096UL
#define MAP_MASK (MAP_SIZE - 1)
#define TRUE 1
#define FALSE 1
typedef int u32;	                              // add this compatibility for int's between Linux and Standalone

// Linux pointers to GPIO's in PL hardware
void *mapped_led_dev_base;		// Address of LED GPIO
void *mapped_button_dev_base;	// Address of Push Button GPIO
void *mapped_base;				// Address of device memory window, it is global for visibility in main to unmount device memory
int memfd; 						// device memory handle for Linux device to memory mapping, it is global for visibility in main to unmount device memory

// Linux application needs gpio base address and register offsets, Standalone application gets it from xparameters.h
#define GPIO_BUTTON_BASE_ADDRESS	0x41240000
#define GPIO_LED_BASE_ADDRESS     	0x40000000
#define GPIO_DATA_OFFSET     		0x0000
#define GPIO_DIRECTION_OFFSET     	0x0004

// access the serial output
#define print printf

// constants
#define LED_DELAY_NORMAL   5000000
#define LED_DELAY_PROFILE        2
#define BUTTON_CHANNEL           1
#define LED_CHANNEL              1
#define ALL_OUTPUTS 0
#define ALL_INPUTS  0xffffffff


// function prototypes  (functions defined in this file after the main)
void *Linux_GPIO_initialize(int gpio_base_address, int direction, int first_call);

// for the hardware exerciser...
void    hardware_exerciser();                                     // name of routine follows common 'C' language convention
#define PI (double)3.141592653                                    // approximation of PI
void    do_sine_sample(int sample);                               // takes sample and calls other routines to get results to LEDs, serial port
void    doBarGraph(int value, int style);                         // name of routine follows common Java language convention (legal for C)
void    driveBarGraph(int value);                                 // actually selects which LEDs are active and makes peripheral call
#define CYLON  1
#define BAR    2
#define BINARY 3
double  sine(double angle_in_radians);
double  factorial(int final_term);
char   *itoa(int value, char *string, int radix);
char   *strcat (char *destination, const char *source);
void    delay_loop(long int delay_count);
int     buttons_get_state(void);
void    LEDs_driver(int pattern);



int   LED_delay_max;                                              // maximum value to delay to for the LED wait loop


/*
 *  ***********************************************************
 */
int main() {

   // local variable
   int mode = 0;                                                 // used to check that one of the environment variables used

   // let the user know that we're starting
   print("---basic_design_zynq Exerciser---\n\r");

   //***** initialize the GPIOs *****
   // For Linux access memory mapped GPIO without kernel driver and initialize.
   // The function returns a pointer address to the associated GPIO and sets the GPIO direction
   mapped_led_dev_base = Linux_GPIO_initialize(GPIO_LED_BASE_ADDRESS, ALL_OUTPUTS, TRUE);
   mapped_button_dev_base = Linux_GPIO_initialize(GPIO_BUTTON_BASE_ADDRESS, ALL_INPUTS, FALSE);


   // determine the use of this software - are we exercising the hardware or doing the profiling exercise?
#ifdef hardware_test
   LED_delay_max = LED_DELAY_NORMAL;
   print("running the hardware test...\n\r");
   mode = 1;
#endif

#ifdef profiler_test
   LED_delay_max = LED_DELAY_PROFILE;
   print("running the profiler code...\n\r");
   mode = 2;
#endif

#ifdef CSP_test
   LED_delay_max = LED_DELAY_PROFILE;
   print("running the CSP analyzer code...\n\r");
   mode = 3;
#endif

   LED_delay_max = LED_DELAY_NORMAL;
   print("running the Linux app...\n\r");
   mode = 4;

   // check to see that one or the other mode was selected, otherwise warn the user and abort
   if (mode != 0) {
	   hardware_exerciser();                                // read switches, detect changes, increment/decrement counter, display count on LEDs...
   } else {
	   print("you must set the symbol \"hardware_test\", \"profiler_test\", \"CSP_test\", or \"LINUX_APP\" in the compiler settings!\n\r");
   }

   print("---Exiting main---\n\r");							// never reached...

   // unmap the memory used for the GPIO device before exiting
   // Linux only, but will never be reached
   // It is a good programming practice to always release the memory space the device was accessing
   // Since the Standalone drivers can always access memory, this sort of functionality is not needed
   if (munmap(mapped_base, MAP_SIZE) == -1) {
       printf("Can't unmap memory from user space.\n");
       exit(0);
   }
   printf("Memory Unmapped\n");
   close(memfd);

   return 0;
}



   /*
    * ************** Hardware Exerciser Code *************************
    */
#define UP    0
#define LEFT  0
#define DOWN  1
#define RIGHT 1
#define STOP  2

#define ONE_PERIOD 128
#define AMPLITUDE  256
#define ABS(a) (((a) < 0) ? -(a) : (a))

/*
 * ****************************************************************************************************
 *    HARDWARE EXERCISER CODE 
 * ****************************************************************************************************
 */

void hardware_exerciser() {
   // local variables
   u32 last_button_state = 0;
   u32 current_button_state = 0;
   u32 button_difference = 0;
   int count_direction = UP;
   int sample = 0;
   int keep_running = 1;
   int profile_iteration_count = 500000;                        // used only in profile mode

   // deliberate infinite loop
   while (keep_running) {
    // read current switch configuration
    current_button_state = buttons_get_state();
    button_difference = (current_button_state ^ last_button_state) & current_button_state; // detect a change and that it has been pushed (not released)
	 if (button_difference != 0) {

       // has anything changed based on the buttons?
	    if      (button_difference & 0x04) { print("Stop counting..."); count_direction = STOP; }
	    else if (button_difference & 0x02) { print("Counting down..."); count_direction = DOWN; }
	    else if (button_difference & 0x01) { print("Counting up...");   count_direction = UP;   }
	 }
     last_button_state = current_button_state;                    // update the button status to prevent runaway button action

   	 // compute the next sample number (period of 256)
   	 if      (count_direction = UP)   { sample++; sample %= ONE_PERIOD; }
   	 else if (count_direction = DOWN) { sample--; if (sample < -1) sample = ONE_PERIOD-1; }
   	 else                              { /* no change */}

   	 // do the math and drive the LEDs
   	 do_sine_sample(sample);

   	 // wait loop - caution - delay loops like this are removed when optimization is turned on!
   	 delay_loop(LED_delay_max);                                      // delay for a slower display

   	 // if this is the profiler mode, we need to quit after a while
#ifdef profiler_test
     keep_running = profile_iteration_count--;
#endif

   }
}


// compute sine, drive LEDs and serial port
// 0 < sample < ONE_PERIOD
void do_sine_sample(int location_in_period) {
	// local variables
	double radian_equivalent;
	int    sine_value;
	char   buf[32],*message, *strValue;                         // used in hardware_test mode only

	// do the computation of this point for sine
	radian_equivalent = (double)(location_in_period)/(double)(ONE_PERIOD) * 3.1415927f * 2.0;   // one full circle
	sine_value = (int)((double)(AMPLITUDE) * sine(radian_equivalent) / 2);                      // this is +/- (i.e. range -1:1 converted to 0:1), so...
	sine_value += AMPLITUDE/2;                                                                  // bias this up so that 0 is in the middle

	// drive the bar graph display
	driveBarGraph(sine_value);

#ifdef hardware_test
	// display the value on the serial port and wait a bit for the LEDs/user to catch up - but only in hardware test mode
	// no output will be present in the profiler_test
	strValue = itoa(sine_value,buf,10);
	message = strcat(strValue,"...");
	xil_printf(message);
#endif
}

/*
 * sine(angle in radians)
 *
 * where: 0 <= angle in radians <= 2 PI
 *
 * does Taylor series expansion (4 terms) to compute sine
 * taylor series good only for small angles - use reflection technique to determine value outside of Q1
 * Q2 = PI - x
 * Q3 = - (x - PI)
 * Q4 = - (2PI - x)
 *
 * Note: this algorithm deliberately uses a slow, iterative way to compute factorials. The faster way:
 * int factorial[] = { 1, 1, 2, 6, 24, 120, 720, 5040 };           // the "fast" way to do it - precompute for the # of terms you need, then it's just a memory lookup
 * result = angle_in_radians - X3/factorial[3] + X5/factorial[5] - X7/factorial[7];
 *
 */
double sine(double angle_in_radians) {
	double X2;
	double X3;
	double X5;
	double X7;
	double result;
	int    quadrant   = 1;                            // begin by assuming Q1

	// determine quadrant and reflect horizontally (if necessary)
	if (angle_in_radians > 3*PI/2) {                  // in Q4?
       quadrant = 4;                                  // remember for later
	   angle_in_radians = 2 * PI - angle_in_radians;  // do horizontal (x) reflection, y reflection done later
	} else if (angle_in_radians > PI) {               // in Q3?
	   quadrant = 3;                                  // remember for later
	   angle_in_radians = angle_in_radians - PI;      // no x reflection, y reflection done later
	} else if (angle_in_radians > PI/2) {             // in Q2?
	   quadrant = 2;                                  // remember for later
       angle_in_radians = PI - angle_in_radians;      // do horizontal (x) reflection
	}

	// compute powers of angle_in_radians
	X2 = angle_in_radians * angle_in_radians;
	X3 = X2 * angle_in_radians;
	X5 = X3 * X2;
	X7 = X5 * X2;

	// compute the sine approximation to 4 places for Q1
	result = angle_in_radians - X3/factorial(3) + X5/factorial(5) - X7/factorial(7);

	// do vertical reflection for Q3 and Q4
    if (quadrant > 2) {
    	result *= -1;                                 // flip the Q1/Q2 result
    }

	return result;
}

double factorial(int final_term) {
	double result = 1.0;
	int    term;

	for (term=2; term<=final_term; term++) {
		result *= term;
	}

	return result;
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
void *Linux_GPIO_initialize(int gpio_base_address, int direction, int first_call)
{
	void *mapped_dev_base;
	off_t dev_base = gpio_base_address;

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
    	printf("Can't map the memory to user space for LED GPIO.\n");
    	exit(0);
    }
    printf("LED GPIO memory mapped at address %p.\n", mapped_base);

    // Get the address of the device in user space which will be an offset from the base
    // that was mapped as memory is mapped at the start of a page
    mapped_dev_base = mapped_base + (dev_base & MAP_MASK);

    // Slight delay for Linux memory access problem
    usleep(50);
    // write to the direction GPIO direction register to set as all inputs or outputs
    *((volatile unsigned long *) (mapped_dev_base + GPIO_DIRECTION_OFFSET)) = direction;
    return mapped_dev_base;
}

/*
 * driveBarGraph(12 bit value)
 *
 * calls doBarGraph. this routine determines which of the 8 possible bins/bars should be illuminated
 *
 */
#define NUMBER_OF_LEDS    8
void driveBarGraph(int value) {
	char buf[32];                                                    // used in hardware test mode
	double bin_range = (AMPLITUDE) / (NUMBER_OF_LEDS);               // how large is each bin?
	int nBars = (int)((double)value / bin_range);                    // how many bars should be lit?

#ifdef hardware_test
	// only print the diagnostic text in hardware_test mode
	xil_printf(itoa(nBars,buf,10)); print("\n\r");
#endif

	// turn on the proper LEDs based on the # of bars and the style
	doBarGraph(nBars,CYLON);                                        //
}


/*
 * doBarGraph(device, value to display, style in which to display
 *
 *
 *    example value = 5,    style shown below:    LED  7  6  5  4  3  2  1  0
 * Style: BAR   - solid up to value                    -  -  *  *  *  *  *  *     * = on, - = off
 *        CYLON - single bar at value                  -  -  *  -  -  -  -  -
 *        BINARY- binary representation of value       -  -  -  -  -  *  -  *
 *        other - displays error pattern               -  *  -  *  -  *  -  *
 *
 */
void doBarGraph(int value, int style) {

	if (style == BAR) {
  	   switch (value) {
	      case 0:  LEDs_driver(0x00); break;
	      case 1:  LEDs_driver(0x01); break;
          case 2:  LEDs_driver(0x03); break;
	      case 3:  LEDs_driver(0x07); break;
	      case 4:  LEDs_driver(0x0f); break;
	      case 5:  LEDs_driver(0x1f); break;
	      case 6:  LEDs_driver(0x3f); break;
	      case 7:  LEDs_driver(0x7f); break;
	      case 8:  LEDs_driver(0xff); break;
	      default: LEDs_driver(0x55);                                          // non-contiguous pattern indicates error
	   }
	} else if (style == CYLON) {
	  	switch (value) {
		   case 0:  LEDs_driver(0x01); break;
	       case 1:  LEDs_driver(0x02); break;
		   case 2:  LEDs_driver(0x04); break;
		   case 3:  LEDs_driver(0x08); break;
		   case 4:  LEDs_driver(0x10); break;
		   case 5:  LEDs_driver(0x20); break;
		   case 6:  LEDs_driver(0x40); break;
		   case 7:  LEDs_driver(0x80); break;
		   default: LEDs_driver(0x55);                                         // non-contiguous pattern indicates error
		}
	} else if (style == BINARY) {
		LEDs_driver(value);                                                    // simple binary value to display
	} else {
		LEDs_driver(0x69);                                                     // different error pattern
	}

}


/*
 * *** buttons_get_state()
 *
 * returns an integer representing the value of the buttons
 *   0 - no buttons pressed
 *   1 - left/down button pressed
 *   2 - right/up button pressed
 *   3 - both buttons pressed
 *
 * this function is coded this way so that it is clear what the Linux vs. Standalone/bare-metal are.
 */
int buttons_get_state()
{
	// local variables
	int current_button_state = 0;
		// Linux read of gpio, notice that it accesses the data register of the GPIO as a memory location, no device driver needed!
		current_button_state = *((volatile unsigned long *) (mapped_button_dev_base + GPIO_DATA_OFFSET));
}


/*
 * *** LEDs_driver(led image (int))
 *
 * sets the LED channel 1 device to the passed value
 *
 * this function is coded this way so that it is clear what the Linux vs. Standalone/bare-metal are.
 */
void LEDs_driver(int led_image)
{
		// Linux write to gpio, by writing to a memory address of the gpio data register, no device driver needed!
		*((volatile unsigned long *) (mapped_led_dev_base + GPIO_DATA_OFFSET)) = led_image;
}


/*
 * *** delay_loop(int delay_count)
 *
 * finite loop which causes a simple delay
 * could have been also performed, more accurately, using the usleep() function
 *
 */
void delay_loop(long int count)
{
	int i;
	for (i=0; i<count; i++); 
}


/*
 * *** itoa
 *
 * converts an integer into a string - also found in the C library
 *
 */
char *itoa(int value, char *string, int radix)
{
  char tmp[33];
  char *tp = tmp;
  int i;
  unsigned v;
  int sign;
  char *sp;

  if (radix > 36 || radix <= 1) { string = "radix out of range 1..36"; return 0; }

  sign = (radix == 10 && value < 0);
  if (sign) { v = -value; }
  else      { v = (unsigned)value; }
  while (v || tp == tmp)  {
    i = v % radix;
    v = v / radix;
    if (i < 10) { *tp++ = i+'0'; }
    else        { *tp++ = i + 'a' - 10; }
  }

  if (string == 0) {
	  string = (char *)malloc((tp-tmp)+sign+1);
	  // xil_printf("call to malloc() made\n\r");
  }
  sp = string;

  if (sign) { *sp++ = '-'; }
  while (tp > tmp) { *sp++ = *--tp; }
  *sp = 0;
  return string;
}

/*
 * *** strcat
 *
 * returns the concatonation of two strings
 *
 * may also be found in string.h
 *
 */
char * strcat ( char * destination, const char * source ){
   char *d = destination;
   while (*d) ++d;
   while ((*d++ = *source++) != '\0') ;
   return (destination);
}



