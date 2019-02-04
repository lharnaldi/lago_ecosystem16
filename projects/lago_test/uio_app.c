#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <poll.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>

#include <string.h>
#include <time.h>
#include <math.h>
#include <sys/time.h>
//#include <fstream>
//#include <iostream>
//#include <vector>

#include "defs.h"

//*****************************************************
// Pressure, temperature and other constants
//****************************************************
uint32_t  ptC1, ptC2, ptC3, ptC4, ptC5, ptC6, ptC7, ptD1, ptD2;
uint8_t   ptAA, ptBB, ptCC, ptDD;
//extern uint32_t  ptC1, ptC2, ptC3, ptC4, ptC5, ptC6, ptC7, ptD1, ptD2;
//extern uint8_t   ptAA, ptBB, ptCC, ptDD;
uint8_t   gpsDate[7];
double  bl1=0,bl2=0,bl3=0;
int     tmp_gps_lat,tmp_gps_lon,tmp_gps_elips;
double  gps_lat,gps_lon,gps_elips;
uint32_t  gfT1,gfT2,gfT3,gfST1,gfST2,gfST3,gfHV1,gfHV2,gfHV3,gGPSTM;

//Globals
int int_fd, cfg_fd, sts_fd, xadc_fd, mem_fd;
void *intc_ptr, *cfg_ptr, *sts_ptr, *xadc_ptr, *mem_ptr;
int dev_size;
int interrupted = 0;
int n_dev;
uint32_t reg_off;
uint32_t reg_val;
int position, limit, offset;

int fReadReg, fGetCfgStatus, fGetPT, fGetGPS, fWriteReg, fSetCfgReg,
		fToFile, fToStdout, fFile, fCount, fByte, fRegValue, fData, fFirstTime=1,
		fshowversion;

char charAction[MAXCHRLEN], scRegister[MAXCHRLEN], charReg[MAXCHRLEN],
		 charFile[MAXCHRLEN], charCurrentFile[MAXCHRLEN], charCount[MAXCHRLEN],
		 scByte[MAXCHRLEN], charRegValue[MAXCHRLEN], charCurrentMetaData[MAXCHRLEN];

//FILE        *fhin = NULL;
FILE         *fhout = NULL;
FILE         *fhmtd = NULL;
struct FLContext  *handle = NULL;

extern long Tab_BasicAltitude[80];

#ifdef FUTURE
unordered_map<string, string> hConfigs;
#endif

//****************************************************
// Time globals for filenames
//****************************************************
time_t    fileTime;
struct tm  *fileDate;
int        falseGPS=0;

//****************************************************
// Metadata
//****************************************************
// Metadata calculations, dataversion v5 need them
// average rates and deviation per trigger condition
// average baseline and deviation per channel
// using long int as max_rate ~ 50 kHz * 3600 s = 1.8x10^7 ~ 2^(20.5)
// and is even worst for baseline
#define MTD_TRG   8
#define MTD_BL    3
#define MTD_BLBIN 1
//daq time
int mtd_seconds=0;
// trigger rates
long int mtd_rates[MTD_TRG], mtd_rates2[MTD_TRG];
//base lines
long int mtd_bl[MTD_BL], mtd_bl2[MTD_BL];
int mtd_iBin=0;
long int mtd_cbl=0;
// deat time defined as the number of missing pulses over the total number
// of triggers. We can determine missing pulses as the sum of the differences 
// between consecutive pulses
long int mtd_dp = 0, mtd_cdp = 0, mtd_pulse_cnt = 0, mtd_pulse_pnt = 0;
// and finally, a vector of strings to handle configs file. I'm also including a
// hash table
// for future implementations. For now, we just dump the lago-configs file
//vector <string> configs_lines;

typedef struct ldata 
{
				int trigg_1;   // trigger level ch1
				int trigg_2;   // trigger level ch2
				int strigg_1;  // sub-trigger level ch1
				int strigg_2;  // sub-trigger level ch2
				int nsamples;  // N of samples
				int time;
				double latitude;
				char lat;
				double longitude;
				char lon;
				uint8_t quality;
				uint8_t satellites;
				double altitude;
} ldata_t;

void signal_handler(int sig)
{
				interrupted = 1;
}

inline void dev_write(void *dev_base, uint32_t offset, uint32_t value)
{
				*((volatile unsigned *)(dev_base + offset)) = value;
}

inline uint32_t dev_read(void *dev_base, uint32_t offset)
{
				return *((volatile unsigned *)(dev_base + offset));
}

/*int dev_init(int n_dev)
	{
	char *uiod; = "/dev/uio1";

	printf("Initializing device...\n");

// open the UIO device file to allow access to the device in user space
cfg_fd = open(uiod, O_RDWR);
if (cfg_fd < 1) {
printf("cfg_init: Invalid UIO device file:%s.\n", uiod);
return -1;
}

dev_size = get_memory_size("/sys/class/uio/uio1/maps/map0/size");

// mmap the cfgC device into user space
cfg_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, cfg_fd, 0);
if (cfg_ptr == MAP_FAILED) {
printf("cfg_init: mmap call failure.\n");
return -1;
}

return 0;
}*/

int32_t rd_reg_value(int n_dev, uint32_t reg_off) 
{
				int32_t reg_val;
				switch(n_dev) 
				{
								case 0:
												reg_val = dev_read(intc_ptr, reg_off);
												break;
								case 1:
												reg_val = dev_read(cfg_ptr, reg_off);
												break;
								case 2:
												reg_val = dev_read(sts_ptr, reg_off);
												break;
								case 3:
												reg_val = dev_read(xadc_ptr, reg_off);
												break;
								default:
												printf("Invalid option: %d\n", n_dev);
												return -1;
				}
				//printf("Complete. Received data %d\n", reg_val);

				return reg_val;
}

int32_t wr_reg_value(int n_dev, uint32_t reg_off, uint32_t reg_val) 
{
				switch(n_dev) 
				{
								case 0:
												dev_write(intc_ptr, reg_off, reg_val);
												break;
								case 1:
												dev_write(cfg_ptr, reg_off, reg_val);
												break;
								case 2:
												dev_write(sts_ptr, reg_off, reg_val);
												break;
								case 3:
												dev_write(xadc_ptr, reg_off, reg_val);
												break;
								default:
												printf("Invalid option: %d\n", n_dev);
												return -1;
				}
				//printf("Complete. Data written to register %d\n", reg_val);

				return 0;
}

int32_t rd_cfg_status() 
{

				printf("#Trigger Level Ch1 = %d\n", dev_read(cfg_ptr, CFG_TRLVL_1_OFFSET));
				printf("#Trigger Level Ch2 = %d\n", dev_read(cfg_ptr, CFG_TRLVL_2_OFFSET));
				//printf("#Subtrigger Ch1    = %d\n", dev_read(cfg_ptr, CFG_STRLVL_1_OFFSET));
				//printf("#Subtrigger Ch2    = %d\n", dev_read(cfg_ptr, CFG_STRLVL_2_OFFSET));
				printf("#High Voltage 1    = %d\n", dev_read(cfg_ptr, CFG_HV1_OFFSET));
				printf("#High Voltage 2    = %d\n", dev_read(cfg_ptr, CFG_HV2_OFFSET));
				printf("\n");
				printf("Status from registers complete!\n");
				return 0;
}

int wait_for_interrupt(int fd_int, void *dev_ptr) 
{
				uint32_t reg;
				uint32_t value;
				uint32_t info = 1; /* unmask */

				ssize_t nb = write(fd_int, &info, sizeof(info));
				if (nb != (ssize_t)sizeof(info)) {
								perror("write");
								close(fd_int);
								exit(EXIT_FAILURE);
				}

				// block (timeout for poll) on the file waiting for an interrupt 
				struct pollfd fds = 
				{
								.fd = fd_int,
								.events = POLLIN,
				};

				int ret = poll(&fds, 1, 1000);
				printf("ret is : %d\n", ret);
				if (ret >= 1) {
								nb = read(fd_int, &info, sizeof(info));
								if (nb == (ssize_t)sizeof(info)) {
												/* Do something in response to the interrupt. */
												value = dev_read(dev_ptr, XIL_AXI_INTC_IPR_OFFSET);
												if ((value & 0x00000001) != 0) {
																dev_write(dev_ptr, XIL_AXI_INTC_IAR_OFFSET, 1);
																printf("Interrupt #%u!\n", info);
												}
								} else {
												perror("poll()");
												close(fd_int);
												exit(EXIT_FAILURE);
								}
				}

				return ret;
}

uint32_t get_memory_size(char *sysfs_path_file)
{
				FILE *size_fp;
				uint32_t size;

				// open the file that describes the memory range size that is based on the
				// reg property of the node in the device tree

				size_fp = fopen(sysfs_path_file, "r");

				if (!size_fp) {
								printf("unable to open the uio size file\n");
								exit(-1);
				}

				// get the size which is an ASCII string such as 0xXXXXXXXX and then be stop
				// using the file

				fscanf(size_fp, "0x%08X", &size);
				fclose(size_fp);

				return size;
}

/*void *thread_isr(void *p) 
	{
	wait_for_interrupt(fd, dev_ptr);

	}*/

int intc_init()
{
				char *uiod = "/dev/uio0";

				printf("Initializing INTC device...\n");

				// open the UIO device file to allow access to the device in user space
				int_fd = open(uiod, O_RDWR);
				if (int_fd < 1) {
								printf("intc_init: Invalid UIO device file:%s.\n", uiod);
								return -1;
				}

				dev_size = get_memory_size("/sys/class/uio/uio0/maps/map0/size");

				// mmap the INTC device into user space
				intc_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, int_fd, 0);
				if (intc_ptr == MAP_FAILED) {
								printf("intc_init: mmap call failure.\n");
								return -1;
				}


				// steps to accept interrupts -> as pg. 26 of pg099-axi-intc.pdf
				//1) Each bit in the IER corresponding to an interrupt must be set to 1.
				dev_write(intc_ptr,XIL_AXI_INTC_IER_OFFSET, 1);
				//2) There are two bits in the MER. The ME bit must be set to enable the
				//interrupt request outputs.
				dev_write(intc_ptr,XIL_AXI_INTC_MER_OFFSET, XIL_AXI_INTC_MER_ME_MASK | XIL_AXI_INTC_MER_HIE_MASK);
				//				dev_write(dev_ptr,XIL_AXI_INTC_MER_OFFSET, XIL_AXI_INTC_MER_ME_MASK);

				//The next block of code is to test interrupts by software
				//3) Software testing can now proceed by writing a 1 to any bit position
				//in the ISR that corresponds to an existing interrupt input.
				//				dev_write(intc_ptr,XIL_AXI_INTC_IPR_OFFSET, 1);

				//        for(a=0; a<10; a++)
				//        {
				//         wait_for_interrupt(fd, dev_ptr);
				//         dev_write(dev_ptr,XIL_AXI_INTC_ISR_OFFSET, 1); //regenerate interrupt
				//        }
				//
				//

				return 0;
}

int cfg_init()
{
				char *uiod = "/dev/uio1";

				printf("Initializing CFG device...\n");

				// open the UIO device file to allow access to the device in user space
				cfg_fd = open(uiod, O_RDWR);
				if (cfg_fd < 1) {
								printf("cfg_init: Invalid UIO device file:%s.\n", uiod);
								return -1;
				}

				dev_size = get_memory_size("/sys/class/uio/uio1/maps/map0/size");

				// mmap the cfgC device into user space
				cfg_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, cfg_fd, 0);
				if (cfg_ptr == MAP_FAILED) {
								printf("cfg_init: mmap call failure.\n");
								return -1;
				}

				return 0;
}

int sts_init()
{
				char *uiod = "/dev/uio2";

				printf("Initializing STS device...\n");

				// open the UIO device file to allow access to the device in user space
				sts_fd = open(uiod, O_RDWR);
				if (sts_fd < 1) {
								printf("sts_init: Invalid UIO device file:%s.\n", uiod);
								return -1;
				}

				dev_size = get_memory_size("/sys/class/uio/uio2/maps/map0/size");

				// mmap the STS device into user space
				sts_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, sts_fd, 0);
				if (sts_ptr == MAP_FAILED) {
								printf("sts_init: mmap call failure.\n");
								return -1;
				}

				return 0;
}

int xadc_init()
{
				char *uiod = "/dev/uio3";

				printf("Initializing XADC device...\n");

				// open the UIO device file to allow access to the device in user space
				xadc_fd = open(uiod, O_RDWR);
				if (xadc_fd < 1) {
								printf("xadc_init: Invalid UIO device file:%s.\n", uiod);
								return -1;
				}

				dev_size = get_memory_size("/sys/class/uio/uio3/maps/map0/size");

				// mmap the XADC device into user space
				xadc_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, xadc_fd, 0);
				if (xadc_ptr == MAP_FAILED) {
								printf("xadc_init: mmap call failure.\n");
								return -1;
				}

				return 0;
}

int mem_init()
{
				char *mem_name = "/dev/mem";

				printf("Initializing mem device...\n");

				// open the UIO device file to allow access to the device in user space
				mem_fd = open(mem_name, O_RDWR);
				if (mem_fd < 1) {
								printf("mem_init: Invalid device file:%s.\n", mem_name);
								return -1;
				}

				dev_size = 1024*sysconf(_SC_PAGESIZE);

				// mmap the mem device into user space 
				mem_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, mem_fd, 0x1E000000);
				if (mem_ptr == MAP_FAILED) {
								printf("mem_init: mmap call failure.\n");
								return -1;
				}

				return 0;
}

void show_usage(char *progname) 
{
				if (fshowversion) {
								printf("LAGO ACQUA BRC v%dr%d data v%d\n",VERSION,REVISION,DATAVERSION);
				} else {
								printf("\n\tThe LAGO ACQUA suite\n");
								printf("\tData acquisition system for the LAGO BRC electronic\n");
								printf("\t(c) 2012-Today, The LAGO Project, http://lagoproject.org\n");
								printf("\t(c) 2012, LabDPR, http://labdpr.cab.cnea.gov.ar\n");
								printf("\n\tThe LAGO Project, lago@lagoproject.org\n");
								printf("\n\tDPR Lab. 2012\n");
								printf("\tH. Arnaldi, lharnaldi@gmail.com - H. Asorey, asoreyh@gmail.com\n");
								printf("\t%s v%dr%d comms soft\n\n",EXP,VERSION,REVISION);
								printf("Usage: %s <action> <register> <value> [options]\n", progname);

								printf("\n\tActions:\n");
								//  printf("\t-r\t\t\t\tGet a single register value\n");
								//  printf("\t-p\t\t\t\tSet a value into a single register\n");
								printf("\t-a\t\t\t\tGet all registers status\n");
								printf("\t-s\t\t\t\tSet registers\n");
								printf("\t-f\t\t\t\tStart DAQ and save data to file\n");
								printf("\t-o\t\t\t\tStart DAQ and send data to stdout\n");
								printf("\t-g\t\t\t\tGet GPS data\n");
								printf("\t-t\t\t\t\tGet Pressure and Temperature data\n");
								printf("\t-v\t\t\t\tShow DAQ version\n");

								printf("\n\tRegisters:\n");
								printf("\tt1, t2, t3\t\t\tSpecify triggers 1, 2 and 3\n");
								//printf("\tst1, st2, st3\t\t\tSpecify subtriggers 1, 2 and
								//3\n");
								printf("\thv1, hv2, hv3\t\t\tSpecify high voltages ...\n");

								printf("\n\tOptions:\n");
								printf("\t-f <filename>\t\t\tSpecify file name\n");
								printf("\t-c <# bytes>\t\t\tNumber of bytes to read/write\n");
								printf("\t-b <byte>\t\t\tValue to load into register\n");

								printf("\n\n");
				}
}

//TODO: change this function to just strncpy
void StrcpyS(char *szDst, size_t cchDst, const char *szSrc) 
{

#if defined (WIN32)     

				strcpy_s(szDst, cchDst, szSrc);

#else

				if ( 0 < cchDst ) {

								strncpy(szDst, szSrc, cchDst - 1);
								szDst[cchDst - 1] = '\0';
				}

#endif
}      

int parse_param(int argc, char *argv[]) 
{

				int    arg;

				// Initialize default flag values 
				fReadReg    = 0;
				fWriteReg    = 0;
				fGetCfgStatus = 0;
				fSetCfgReg = 0;
				fToFile    = 0;
				fToStdout  = 0;
				fGetPT     = 0;
				fGetGPS    = 0;
				fFile      = 0;
				fCount     = 0;
				fByte      = 0;
				fData      = 0;
				fRegValue  = 0;

				// Ensure sufficient paramaters. Need at least program name and action
				// flag
				if (argc < 2) 
				{
								return 0;
				}

				// The first parameter is the action to perform. Copy the first
				// parameter into the action string.
				StrcpyS(charAction, MAXCHRLEN, argv[1]);
				if(strcmp(charAction, "-r") == 0) {
								fReadReg = 1;
				} 
				else if( strcmp(charAction, "-w") == 0) {
								fWriteReg = 1;
				} 
				else if( strcmp(charAction, "-a") == 0) {
								fGetCfgStatus = 1;
								return 1;
				} 
				else if( strcmp(charAction, "-v") == 0) {
								fshowversion = 1;
								return 0;
				} 
				else if( strcmp(charAction, "-s") == 0) {
								fSetCfgReg = 1;
				} 
				else if( strcmp(charAction, "-f") == 0) {
								fToFile = 1;
				} 
				else if( strcmp(charAction, "-o") == 0) {
								fToStdout = 1;
								return 1;
				} 
				else if( strcmp(charAction, "-t") == 0) {
								fGetPT = 1;
								return 1;
				} 
				else if( strcmp(charAction, "-g") == 0) {
								fGetGPS = 1;
								return 1;
				} 
				else { // unrecognized action
								return 0;
				}

				// Second paramater is target register on device. Copy second paramater
				// to the register string
				if((fReadReg == 1) || (fWriteReg == 1)) {
								StrcpyS(charReg, MAXCHRLEN, argv[2]);
								if(strcmp(charReg, "intc") == 0) {
												n_dev = 0; 
								} 
								else if(strcmp(charReg, "cfg") == 0) {
												n_dev = 1; 
								} 
								else if(strcmp(charReg, "sts") == 0) {
												n_dev = 2; 
								} 
								else if(strcmp(charReg, "xadc") == 0) {
												n_dev = 3; 
								}
								else { // unrecognized device to set
												return 0;
								}
								reg_off = strtoul(argv[3],NULL, 16);
								//FIXME: see if this can be done better
								if (fWriteReg) reg_val = strtoul(argv[4],NULL,10);
								return 1;
				}

				else if(fSetCfgReg) {
								StrcpyS(charReg, MAXCHRLEN, argv[2]);
								// Registers for Triggers
								if(strcmp(charReg, "t1") == 0) {
												reg_off = CFG_TRLVL_1_OFFSET;
								} 
								else if(strcmp(charReg, "t2") == 0) {
												reg_off = CFG_TRLVL_2_OFFSET;
								} 
								// Registers for Subtriggers
								else if(strcmp(charReg, "st1") == 0) {
												reg_off = CFG_STRLVL_1_OFFSET;
								} 
								else if(strcmp(charReg, "st2") == 0) {
												reg_off = CFG_STRLVL_2_OFFSET;
								} 
								// Registers for High Voltage
								else if(strcmp(charReg, "hv1") == 0) {
												reg_off = CFG_HV1_OFFSET;
								} 
								else if(strcmp(charReg, "hv2") == 0) {
												reg_off = CFG_HV2_OFFSET;
								} 
								// Unrecognized
								else { // unrecognized register to set
												return 0;
								}
								//charCount[0] = '4';
								//fCount = 1;
								StrcpyS(charRegValue, 16, argv[3]);
								if((strncmp(charReg, "hv",2) == 0)) {
												if (atoi(charRegValue)>2500) {
																printf ("Error: maximum voltage is 2500 mV\n");
																exit(1);
												}
												fRegValue = 1;
								}
								//fData = 1; FIXME: not used apparently
				} 
				else if(fToFile) {
								if(argv[2] != NULL) {
												StrcpyS(charFile, MAXFILENAMELEN, argv[2]);
												fFile = 1;
								} 
								else {
												return 0;
								}
				} 
				else {
								StrcpyS(scRegister, MAXCHRLEN, argv[2]);

								// Parse the command line parameters.
								arg = 3;
								while(arg < argc) {

												// Check for the -f parameter used to specify the
												// input/output file name.
												if (strcmp(argv[arg], "-f") == 0) {
																arg += 1;
																if (arg >= argc) {
																				return 0;
																}
																StrcpyS(charFile, 16, argv[arg++]);
																fFile = 1;
												}

												// Check for the -c parameter used to specify the number
												// of bytes to read/write from file.
												else if (strcmp(argv[arg], "-c") == 0) {
																arg += 1;
																if (arg >= argc) {
																				return 0;
																}
																StrcpyS(charCount, 16, argv[arg++]);
																fCount = 1;
												}

												// Check for the -b paramater used to specify the value
												// of a single data byte to be written to the register 
												else if (strcmp(argv[arg], "-b") == 0) {
																arg += 1;
																if (arg >= argc) {
																				return 0;
																}
																StrcpyS(scByte, 16, argv[arg++]);
																fByte = 1;
												}

												// Not a recognized parameter
												else {
																return 0;
												}
								} // End while

								// Input combination validity checks 
								if( fWriteReg && !fByte ) {
												printf("Error: No byte value provided\n");
												return 0;
								}
								if( (fToFile ) && !fFile ) {
												printf("Error: No filename provided\n");
												return 0;
								}

								return 1;
				}
				return 1;
}

float get_voltage(uint32_t offset)
{
				int16_t value;
				value = (int16_t) dev_read(xadc_ptr, offset);
				//  printf("The Voltage is: %lf V\n", (value>>4)*XADC_CONV_VAL);
				return ((value>>4)*XADC_CONV_VAL);
}

void set_voltage(uint32_t offset, uint32_t value)
{
				//fit after calibration. See file data_calib.txt in /ramp_test directory 
				// y = a*x + b
				//a               = 0.0382061     
				//b               = 4.11435   
				uint32_t dac_val;
				float a = 0.0382061, b = 4.11435;

				dac_val = (uint32_t)(value - b)/a;

				dev_write(cfg_ptr, offset, dac_val);
				printf("The Voltage is: %d mV\n", value);
				printf("The DAC value is: %d DACs\n", dac_val);
}

//System initialization
int init_system()
{
				// set trigger_lvl_1
				dev_write(cfg_ptr,CFG_TRLVL_1_OFFSET,8190); 

				// set trigger_lvl_2
				dev_write(cfg_ptr,CFG_TRLVL_2_OFFSET,8190); // *((uint32_t *)(cfg + 10)) = 8190;
				//reg_val = dev_read(cfg_ptr, 10);
				//printf("reg_val for trg_lvl_b : %d\n",reg_val);

				// set subtrigger_lvl_1
				dev_write(cfg_ptr,CFG_STRLVL_1_OFFSET,8190); // *((uint32_t *)(cfg + 12)) = 8190;

				// set subtrigger_lvl_2
				dev_write(cfg_ptr,CFG_STRLVL_2_OFFSET,8190); // *((uint32_t *)(cfg + 14)) = 8190;

				// reset pps_gen, fifo and trigger modules
				reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
				//printf("reg_val : 0x%08d\n",reg_val);
				dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~1); 
				//printf("written reg_val : 0x%08d\n",reg_val & ~1);

				/* reset data converter and writer */
				reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
				dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~4); 

				// enter reset mode for tlast_gen
				reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
				dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~2); 

				// set number of samples
				dev_write(cfg_ptr,CFG_NSAMPLES_OFFSET, 1024 * 1024); 

				// enter normal mode for tlast_gen
				reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
				//printf("reg_val : 0x%08x\n",reg_val);
				dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 2); 
				//printf("written reg_val tlast : 0x%08x\n",reg_val | 2);
				// enter normal mode for pps_gen, fifo and trigger modules
				reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
				//printf("reg_val : 0x%08x\n",reg_val);
				dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 1); 
				//printf("written reg_val pps_gen, fifo : 0x%08x\n",reg_val | 1);

				// enable false GPS
				reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
				//printf("reg_val : 0x%08x\n",reg_val);
				dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 16);
				//printf("written reg_val : 0x%08x\n",reg_val | 16);
				// disable
				//dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~16);
				//printf("written reg_val : 0x%08x\n",reg_val & ~16);

				// enter normal mode for data converter and writer
				reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
				dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 4); 
				printf("written reg_val : 0x%08hx\n",reg_val | 4);

}
int new_file() 
{
				char buf[256];
				time_t currt=time(NULL);
				uint32_t i;

				if (!fToStdout) {
								if (fhout) {
												fclose(fhout);
								}
								/*if (fhmtd) {
								//before to close the file we have to fill DAQ status metadata
								// Average and deviation trigger rates
								double mtd_avg[MTD_TRG], mtd_dev[MTD_TRG];
								if (!mtd_seconds) {
								for (int i=0; i<MTD_TRG; i++)
								mtd_avg[i] = mtd_dev[i] = -1.;
								} 
								else {
								for (int i=0; i<MTD_TRG; i++) {
								mtd_avg[i] = 1. * mtd_rates[i] / mtd_seconds;
								mtd_dev[i] = sqrt(1. * mtd_rates2[i] / mtd_seconds - mtd_avg[i] * mtd_avg[i]);
								}
								}
								for (int i=1; i<MTD_TRG; i++)
								fprintf(fhmtd, "triggerRateAvg%02d=%lf\n", i, mtd_avg[i]);
								for (int i=1; i<MTD_TRG; i++)
								fprintf(fhmtd, "trigggerRateDev%02d=%lf\n", i, mtd_dev[i]);
								for (int i=0; i<MTD_TRG; i++)
								mtd_rates[i] = mtd_rates2[i] = 0;
								//baselines
								double mtd_bl_avg[MTD_BL], mtd_bl_dev[MTD_BL];
								double mtd_cdpf;
								if (!mtd_cbl) {
								for (int i=0; i<MTD_BL; i++)
								mtd_bl_avg[i] = mtd_bl_dev[i] = -1.;
								mtd_cdpf = -1;
								} 
								else {
								for (int i=0; i<MTD_BL; i++) {
								mtd_bl_avg[i] = 1. * mtd_bl[i] / mtd_cbl;
								mtd_bl_dev[i] = sqrt(1. * mtd_bl2[i] / mtd_cbl - mtd_bl_avg[i] * mtd_bl_avg[i]);
								}
								mtd_cdpf = 1. * mtd_cdp / mtd_cbl;
								}
								for (int i=1; i<MTD_BL; i++)
								fprintf(fhmtd, "baselineAvg%02d=%lf\n", i+1, mtd_bl_avg[i]);
								for (int i=1; i<MTD_BL; i++)
								fprintf(fhmtd, "baselineDev%02d=%lf\n", i+1, mtd_bl_dev[i]);
								for (int i=0; i<MTD_BL; i++)
								mtd_bl[i] = mtd_bl2[i] = 0;
								// daq time, pulses and dead time
								fprintf(fhmtd, "daqTime=%d\n", mtd_seconds);
								fprintf(fhmtd, "totalPulses=%ld\n", mtd_cbl);
								fprintf(fhmtd, "totalPulsesLost=%ld\n", mtd_cdp);
								fprintf(fhmtd, "fractionPulsesLost=%le\n", mtd_cdpf);
								//and now, let's close the file
								mtd_seconds = 0;
								mtd_cbl = mtd_cdp = 0;
								fclose(fhmtd);
								}*/
								fileTime=timegm(fileDate);
								fileDate=gmtime(&fileTime); // filling all fields with properly computed values (for new month/year)
								if (falseGPS) {
												snprintf(charCurrentFile,MAXCHRLEN,"%s_nogps_%04d_%02d_%02d_%02dh00.dat",charFile,fileDate->tm_year+1900, fileDate->tm_mon+1,fileDate->tm_mday,fileDate->tm_hour);
												snprintf(charCurrentMetaData,MAXCHRLEN,"%s_nogps_%04d_%02d_%02d_%02dh00.mtd",charFile,fileDate->tm_year+1900, fileDate->tm_mon+1,fileDate->tm_mday,fileDate->tm_hour);
								} 
								else {
												snprintf(charCurrentFile,MAXCHRLEN,"%s_%04d_%02d_%02d_%02dh00.dat",charFile,fileDate->tm_year+1900, fileDate->tm_mon+1,fileDate->tm_mday,fileDate->tm_hour);
												snprintf(charCurrentMetaData,MAXCHRLEN,"%s_%04d_%02d_%02d_%02dh00.mtd",charFile,fileDate->tm_year+1900, fileDate->tm_mon+1,fileDate->tm_mday,fileDate->tm_hour);
								}
								fhout = fopen(charCurrentFile, "ab");
								//fhmtd = fopen(charCurrentMetaData, "w");
								fprintf(stderr,"Opening files %s and %s for data taking\n",charCurrentFile, charCurrentMetaData);
				}
				fprintf(fhout,"# v %d\n", DATAVERSION);
				fprintf(fhout,"# #\n");
				fprintf(fhout,"# # This is a %s raw data file, version %d\n",EXP,DATAVERSION);
				fprintf(fhout,"# # It contains the following data:\n");
				fprintf(fhout,"# #   <N1> <N2>        : line with values of the 2 ADC for a triggered pulse\n");
				//fprintf(fhout,"# #                      it is a subtrigger with the pulse maximum bin if only one such line is found\n");
				//fprintf(fhout,"# #                      it is a trigger with the full pulse if 16 lines are found\n");
				fprintf(fhout,"# #   # t <C> <V>      : end of a trigger\n");
				fprintf(fhout,"# #                      gives the channel trigger (<C>: 3 bit mask) and 40MHZ clock count (<V>) of the trigger time\n");
				fprintf(fhout,"# #   # c <C>          : internal trigger counter\n");
				fprintf(fhout,"# #   # x f <V>        : 40 MHz frequency\n");
				fprintf(fhout,"# #   # x r C1-DD <V>  : raw temperature and pressure sensor value\n");
				fprintf(fhout,"# #   # x r D1 <V>     : raw temperature/pressure value\n");
				fprintf(fhout,"# #   # x r D2 <V>     : raw temperature/pressure value\n");
				fprintf(fhout,"# #   # x h <HH:MM:SS> <DD/MM/YYYY> <S> : GPS time (every new second, last number is seconds since EPOCH)\n");
				fprintf(fhout,"# #   # x s <T> C <P> hPa <A> m : temperature <T>, pressure <P> and altitude (from pressure) <A>\n");
				fprintf(fhout,"# #   # x g <LAT> <LON> <ALT>   : GPS data - latitude, longitude, altitude\n");
				fprintf(fhout,"# #   # x b <B1> <B2> <B3>      : baselines (NOT IMPLEMENTED IN LAGO)\n");
				fprintf(fhout,"# # In case of error, an unfinished line will be finished by # E @@@\n");
				fprintf(fhout,"# # Followed by a line with # E <N> and the error message in human readable format, where <N> is the error code:\n");
				fprintf(fhout,"# #   # E 1 : read timeout of 2 seconds\n");
				fprintf(fhout,"# #   # E 2 : too many buffer reading tries\n");
				fprintf(fhout,"# #   # E 3 : unknown word from FPGA\n");
				fprintf(fhout,"# #\n");
				fprintf(fhout,"# # Current registers setting\n");
				fprintf(fhout,"# #\n");
				// Save settings into file
				fprintf(fhout,"# x c T1 %d\n",gfT1);
				fprintf(fhout,"# x c T2 %d\n",gfT2);
				fprintf(fhout,"# x c T3 %d\n",gfT3);
				/* not used anymore...
					 fprintf(fhout,"# x c ST1 %d\n",gfST1);
					 fprintf(fhout,"# x c ST2 %d\n",gfST2);
					 fprintf(fhout,"# x c ST3 %d\n",gfST3);
				 */
				fprintf(fhout,"# x c HV1 %d\n",gfHV1);
				fprintf(fhout,"# x c HV2 %d\n",gfHV2);
				fprintf(fhout,"# x c HV3 %d\n",gfHV3);
				fprintf(fhout,"# x c GPSTM UTC\n");
				fprintf(fhout,"# #\n");
				gethostname(buf, 256);
				fprintf(fhout,"# # This file was started on %s\n",buf);
				//				fprintf(fhmtd, "daqHost=\"%s\"\n",buf);
				ctime_r(&currt,buf);
				fprintf(fhout,"# # Machine local time was %s",buf);
				strtok(buf, "\n");
				//				fprintf(fhmtd, "machineTime=\"%s\"\n",buf);
				if (falseGPS) fprintf(fhout,"# # WARNING, there is no GPS, using PC time\n");
				fprintf(fhout,"# #\n");
				//				fprintf(fhmtd, "dataFile=\"%s\"\n",charCurrentFile);
				//				fprintf(fhmtd, "metadataFile=\"%s\"\n",charCurrentMetaData);
				//				fprintf(fhmtd, "daqVersion=%d\n",VERSION);
				//				fprintf(fhmtd, "daqUseGPS=%s", (!falseGPS)?"true":"false");
				//				fprintf(fhmtd, "dataVersion=%d\n",DATAVERSION);
				//				for (i=0; i<configs_lines.size(); i++)
				//								fprintf(fhmtd, "%s\n", configs_lines[i].c_str());
				//				fprintf(fhmtd, "version=\"LAGO ACQUA BRC v%dr%d data v%d\"\n",VERSION,REVISION,DATAVERSION);
				fflush(fhout);
				//				fflush(fhmtd);
				return 0;
}

/*int read_buffer(int position)
	{
// print 512 IN1 and IN2 samples if ready, otherwise sleep 1 ms
if((limit > 0 && position > limit) || (limit == 0 && position < 512*1024)) {

offset = limit > 0 ? 0 : 512*1024;
limit = limit > 0 ? 0 : 512*1024;

for(i = 0; i < 512 * 1024; ++i) {
ch[0] = *((int16_t *)(mem_ptr + offset + 4*i + 0));
ch[1] = *((int16_t *)(mem_ptr + offset + 4*i + 2));
//printf("%5d %5d\n", ch[0], ch[1]);
wo = *((uint32_t *)(mem_ptr + offset + 4*i));
switch(wo>>30) {
case 0:
fprintf(fhout,"%5hd %5hd\n", (((ch[0]>>13)<<14) + ((ch[0]>>13)<<15) + ch[0]),(((ch[1]>>13)<<14) +
((ch[1]>>13)<<15) + ch[1]));
//printf("# p %5d\n", wo);
break;
case 1:
fprintf(fhout,"# t %d %d\n", (wo>>27)&0x7, wo&0x7FFFFFF);
break;
case 2:
mtd_pulse_pnt = mtd_pulse_cnt;
mtd_pulse_cnt = (wo&0x3FFFFFFF);
mtd_dp = (mtd_pulse_cnt - mtd_pulse_pnt - 1);
if (mtd_dp > 0 && mtd_pulse_pnt)
mtd_cdp += mtd_dp;
fprintf(fhout,"# c %d\n", mtd_pulse_cnt);
break;
default:
printf("# E @@@\n");
printf("# E 3 - unknown word from FPGA: %d %x\n",wo>>27,wo>>27);
break;
}
}
}
else{
usleep(100);
}

}*/


//#define CIRCSIZE 32768
/*#define CIRCSIZE 65536
	uint8_t circbuf[CIRCSIZE];
	uint32_t bufwrite=0;
	uint32_t bufread=0;
	int bufsync=0;*/
int r[MTD_TRG];

int read_buffer(int position)
{
				uint32_t wo;
				int16_t ch[2];
				uint32_t i, j;

				if (fToStdout)
								fhout=stdout;
				if (fFirstTime) {
								// if no GPS 
								if ((dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET) && 0x00000010)==1) { // get time form PC
												fileTime=time(NULL);
												fileDate=gmtime(&fileTime); // filling all fields
												falseGPS=1;
								} 
								else {
												fileTime=time(NULL);
												fileDate=gmtime(&fileTime);
												//FIXME: fill with actual data
												fileDate->tm_sec=55;
												fileDate->tm_min=55;
												fileDate->tm_hour=10;
												fileDate->tm_mday=29;
												fileDate->tm_mon=8;
												fileDate->tm_year=2018;

												/*fileDate->tm_sec=gpsDate[6];
													fileDate->tm_min=gpsDate[5];
													fileDate->tm_hour=gpsDate[4];
													fileDate->tm_mday=gpsDate[1];
													fileDate->tm_mon=gpsDate[0]-1;
													fileDate->tm_year=((gpsDate[2] << 8) + gpsDate[3])-1900;*/
												fileTime=timegm(fileDate);
												fileDate=gmtime(&fileTime); // filling all fields
								}
								if (fhout != stdout) {
												//FIXME: here read PyT data
												/*for(int8 i=0; i<49; i++) {
													if(flReadChannel(handle, 10, ucAddr[i], 1, &rgbPT[i], &error)) {
													printf("flReadChannel failed\n");
													handler(1);
													}
													}
													ptC1 = (rgbPT[19] << 8) + rgbPT[20];
													ptC2 = (rgbPT[21] << 8) + rgbPT[22];
													ptC3 = (rgbPT[23] << 8) + rgbPT[24];
													ptC4 = (rgbPT[25] << 8) + rgbPT[26];
													ptC5 = (rgbPT[27] << 8) + rgbPT[28];
													ptC6 = (rgbPT[30] << 8) + rgbPT[29];
													ptC7 = (rgbPT[32] << 8) + rgbPT[31];
													ptAA = rgbPT[33];
													ptBB = rgbPT[34];
													ptCC = rgbPT[35];
													ptDD = rgbPT[36];

													gfT1 = ((rgbPT[0] << 8) + rgbPT[1]);
													gfT2 = ((rgbPT[2] << 8) + rgbPT[3]);
													gfT3 = ((rgbPT[4] << 8) + rgbPT[5]);
													gfST1 = ((rgbPT[6] << 8) + rgbPT[7]);
													gfST2 = ((rgbPT[8] << 8) + rgbPT[9]);
													gfST3 = ((rgbPT[10] << 8) + rgbPT[11]);
													gfHV1 = ((rgbPT[12] << 8) + rgbPT[13]);
													gfHV2 = ((rgbPT[14] << 8) + rgbPT[15]);
													gfHV3 = ((rgbPT[16] << 8) + rgbPT[17]);
													gGPSTM = rgbPT[18];*/
												ptC1 =10; 
												ptC2 =10;
												ptC3 =10;
												ptC4 =10;
												ptC5 =10;
												ptC6 =10;
												ptC7 =10;
												ptAA =10;
												ptBB =10;
												ptCC =10;
												ptDD = 10;

												gfT1 = 10;
												gfT2 = 10;
												gfT3 = 10;
												gfST1 =10;
												gfST2 =10;
												gfST3 =10;
												gfHV1 =10;
												gfHV2 =10;
												gfHV3 = 10;
												gGPSTM = 10;
								}
								new_file();
								fFirstTime=0;
				}

				// print 512 IN1 and IN2 samples if ready, otherwise sleep 1 ms
				if((limit > 0 && position > limit) || (limit == 0 && position < 512*1024)) {

								offset = limit > 0 ? 0 : 512*1024;
								limit = limit > 0 ? 0 : 512*1024;

								for(i = 0; i < 512 * 1024; ++i) {
												ch[0] = *((int16_t *)(mem_ptr + offset + 4*i + 0));
												ch[1] = *((int16_t *)(mem_ptr + offset + 4*i + 2));
												//printf("%5d %5d\n", ch[0], ch[1]);
												wo = *((uint32_t *)(mem_ptr + offset + 4*i));
												if (wo>>30==0) {
																//fprintf(fhout,"%d %d %d %d %d %d %d\n", ch1, ch2,
																//ch3,bufread,bufwrite,idReg,idData);
																fprintf(fhout,"%5hd %5hd\n", (((ch[0]>>13)<<14) + ((ch[0]>>13)<<15) + ch[0]),(((ch[1]>>13)<<14) + ((ch[1]>>13)<<15) + ch[1]));
																/*mtd_iBin++;
																	if (mtd_iBin == MTD_BLBIN) {
																	mtd_bl[0] += ch1;
																	mtd_bl2[0] += ch1 * ch1;
																	mtd_bl[1] += ch2;
																	mtd_bl2[1] += ch2 * ch2;
																	mtd_bl[2] += ch3;
																	mtd_bl2[2] += ch3 * ch3;
																	mtd_cbl++;
																	}*/
												} 
												else {
																if (wo>>30==1) {
																				fprintf(fhout,"# t %d %d\n", (wo>>27)&0x7, wo&0x7FFFFFF);
																				/*int trig=(wo>>27)&0x7;
																					r[trig]++;
																					mtd_iBin=0;*/
																} 
																else {
																				if (wo>>30==2) {
																								mtd_pulse_pnt = mtd_pulse_cnt;
																								mtd_pulse_cnt = (wo&0x3FFFFFFF);
																								mtd_dp = (mtd_pulse_cnt - mtd_pulse_pnt - 1);
																								if (mtd_dp > 0 && mtd_pulse_pnt)
																												mtd_cdp += mtd_dp;
																								fprintf(fhout,"# c %ld\n", mtd_pulse_cnt);
																				} 
																				else {
																								switch(wo>>27) {
																												case 0x18:
																																fprintf(fhout,"# x f         %d \n", wo&0x03FFFFFF);
																																break;
																												case 0x19:
																																fprintf(fhout,"# x r D2         %d \n", wo&0x0000FFFF);
																																ptD2=wo&0x0000FFFF;
																																break;
																												case 0x1A:
																																fprintf(fhout,"# x r D1         %d \n", wo&0x0000FFFF);
																																ptD1=wo&0x0000FFFF;
																																//CalculatePressTemp(1);
																																break;
																												case 0x1B:
																																if (falseGPS) {
																																				fileDate->tm_sec++;
																																				if (fileDate->tm_sec==60 && fileDate->tm_min==59) { // new hour
																																								if (!fToStdout)
																																												new_file();
																																				} 
																																				else {
																																								fileTime=timegm(fileDate);
																																								fileDate=gmtime(&fileTime); // filling all fields with properly comupted values (for new month/year)
																																				}
																																} 
																																else {
																																				if ((uint32_t)fileDate->tm_hour!=((wo>>16)&0x000000FF)) {
																																								// new hour of data
																																								if ((uint32_t)fileDate->tm_hour>((wo>>16)&0x000000FF)) { // new day
																																												fileDate->tm_mday++;
																																								}
																																								fileDate->tm_hour=(wo>>16)&0x000000FF;
																																								if (!fToStdout)
																																												new_file();
																																				}
																																				fileDate->tm_hour=(wo>>16)&0x000000FF;
																																				fileDate->tm_min=(wo>>8)&0x000000FF;
																																				fileDate->tm_sec=wo&0x000000FF;
																																}
																																mtd_seconds++;
																																fileTime=timegm(fileDate);
																																fileDate=gmtime(&fileTime); // filling all fields with properly computed values (for new month/year)
																																fprintf(fhout,"# x h   %02d:%02d:%02d %02d/%02d/%04d %d\n",
																																								fileDate->tm_hour, fileDate->tm_min, fileDate->tm_sec,
																																								fileDate->tm_mday, fileDate->tm_mon+1,fileDate->tm_year+1900,
																																								(int)fileTime
																																			 );
																																fprintf(stderr,"# %02d:%02d:%02d %02d/%02d/%04d %d - second %d - rates: %d %d %d (%d - %d - %d) [%d]\r", 
																																								fileDate->tm_hour, fileDate->tm_min, fileDate->tm_sec,
																																								fileDate->tm_mday, fileDate->tm_mon+1, fileDate->tm_year+1900,
																																								(int)fileTime,
																																								mtd_seconds,
																																								r[1], r[2], r[4], r[3], r[5], r[6], r[7]
																																			 );
																																for (j=0; j<MTD_TRG; j++) {
																																				mtd_rates[i] += r[i];
																																				mtd_rates2[i] += r[i] * r[i];
																																				r[i] = 0;
																																}
																																break;
																												case 0x1C: // Longitude, latitude, defined by other bits
																																switch(((wo)>>24) & 0x7) {
																																				case 0:
																																								tmp_gps_lat=((wo & 0xFFFFFF)<<8);
																																								break;
																																				case 1:
																																								gps_lat=((int)(tmp_gps_lat+(wo & 0xFF)))/3600000.;
																																								break;
																																				case 2:
																																								tmp_gps_lon=((wo & 0xFFFFFF)<<8);
																																								break;
																																				case 3:
																																								gps_lon=((int)(tmp_gps_lon+(wo & 0xFF)))/3600000.;
																																								break;
																																				case 4:
																																								tmp_gps_elips=((wo & 0xFFFFFF)<<8);
																																								break;
																																				case 5:
																																								gps_elips=((int)(tmp_gps_elips+(wo & 0xFF)))/100.;
																																								fprintf(fhout,"# x g %.6f %.6f %.2f\n",gps_lat,gps_lon,gps_elips);
																																								break;
																																				default:
																																								break;
																																}
																																break;
																																/*case 0x1F: // note : not used in LAGO, was used in MIDAS... Legacy
																																	bl1 = 2*(((wo)>>18) & 0x1FF);
																																	bl2 = 2*(((wo)>>9) & 0x1FF);
																																	bl3 = 2*(wo & 0x1FF);
																																	break;
																																	case 0x1E: // note : not used in LAGO, was used in MIDAS... Legacy
																																	bl1 += (((wo)>>18) & 0x1FF)/256.;
																																	bl2 += (((wo)>>9) & 0x1FF)/256.;
																																	bl3 += (wo & 0x1FF)/256.;
																																	fprintf(fhout,"# x b %.4f %.4f %.4f\n", bl1, bl2, bl3);
																																	break;*/
																												default:
																																fprintf(fhout,"# E @@@\n");
																																fprintf(fhout,"# E 3 - unknown word from FPGA: %d %x\n",wo>>27,wo>>27);
																																break;
																								}
																				}
																}
												}
								}
				}
				return 1;
}

int main(int argc, char *argv[])
{
				int i, p=0,a,b=40000;
				uint32_t val;
				int returnCode;

				pthread_t t1;
				//FIXME: just for test commented
				if (!parse_param(argc, argv)) {
								show_usage(argv[0]);
								return 1;
				}


				signal(SIGINT, signal_handler);

				//initialize devices. TODO: add error checking 
				mem_init();
				intc_init();    
				cfg_init();    
				sts_init();    
				xadc_init();    

				//TODO: here put something like init_interrupts()

				/*       val = dev_read(cfg_ptr, 0);
								 printf("Initial STATUS Register: 0x%08d\n",val);
				//dev_write(cfg_ptr, CFG_RESET_GRAL_OFFSET, 8); //first reset
				//dev_write(cfg_ptr, CFG_RESET_GRAL_OFFSET, val | RST_PPS_TRG_FIFO_MASK | PPS_EN_MASK); //first reset
				dev_write(cfg_ptr, CFG_RESET_GRAL_OFFSET, val | RST_PPS_TRG_FIFO_MASK); //first reset
				printf("PPS_EN_MASK negado: 0x%08d\n",~PPS_EN_MASK);
				printf("STATUS Register: 0x%08d\n",dev_read(cfg_ptr, 0));

				init_system();
				while(!interrupted) 
				{
				//                printf("IPR Register antes:  0x%08d\n",dev_read(intc_ptr, XIL_AXI_INTC_IPR_OFFSET));
				wait_for_interrupt(int_fd, intc_ptr);
				//                printf("IPR Register después: 0x%08d\n",dev_read(intc_ptr, XIL_AXI_INTC_IPR_OFFSET));
				}*/

				//init_system();

				if(fReadReg) {
								rd_reg_value(n_dev, reg_off);  // Read single register
				}
				else if (fWriteReg) {
								wr_reg_value(n_dev, reg_off, reg_val);  // Write single register
				}
				else if (fSetCfgReg) {
								if (fRegValue) set_voltage(reg_off, atoi(charRegValue)); // For HV
								else wr_reg_value(1,reg_off, atoi(charRegValue));                   // For t1, t2, st1, st2  
				}
				else if (fGetCfgStatus) {
								rd_cfg_status();        // Get registers status
				}
				else if (fGetPT) {
								//			DoGetPandTnFifoSync();     // Get pressure and temperature from sensor
				}
				else if (fGetGPS) {
								//				DoGetGPSnFifoSync();      // Save file with contents of register 
				}
				else if (fToFile || fToStdout) {
								//TODO: get GPS data here
								//	for(i=0; i<7; i++) {
								//					status=flReadChannel(handle, 100, AddrGPSDate[i], 1, &gpsDate[i], &error);
								//					CHECK(10);
								//	}

								//fprintf(stderr,"Cleaning buffers\n");
								//rd_buffer(0,27);
								//rd_buffer(0,28);
								//								fprintf(stderr,"Starting DAQ at %02d:%02d:%02d\n", fileDate->tm_hour, fileDate->tm_min, fileDate->tm_sec);

								limit = 512*1024; //middle of the memory

								while(!interrupted){
												//for(;;) {
												//												alarm(2);   // setting 1 sec timeout
												// read writer position 
												position = dev_read(sts_ptr, STS_STATUS_OFFSET); 

												//rd_buffer();
												read_buffer(position);
												//											alarm(0);   // cancelling 1 sec timeout
								}
								}
								//cleanup:
								//				flFreeFile(buffer);
								//				flClose(handle);
								//				return returnCode;
								//
								//}

								// unmap and close the devices 
								munmap(intc_ptr, dev_size);
								munmap(cfg_ptr, dev_size);
								munmap(sts_ptr, dev_size);
								munmap(xadc_ptr, dev_size);
								munmap(mem_ptr, dev_size);

								close(int_fd);
								close(cfg_fd);
								close(sts_fd);
								close(xadc_fd);

								return 0;
}
