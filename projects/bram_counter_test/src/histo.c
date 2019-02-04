#include "histo.h"

//Globals
int interrupted = 0;
int n_dev;
uint32_t reg_off;
int32_t reg_val;
//double r_val;
int limit;
int current;

int fReadReg, fGetCfgStatus, fGetGPS, fGetXADC, fInitSystem, fWriteReg, 
		fSetCfgReg, fToFile, fToStdout, fFile, fCount, fByte, fRegValue, fData, 
		fFirstTime=1,	fshowversion;

char charAction[MAXCHRLEN], scRegister[MAXCHRLEN], charReg[MAXCHRLEN],
		 charFile[MAXCHRLEN], charCurrentFile[MAXCHRLEN], charCount[MAXCHRLEN],
		 scByte[MAXCHRLEN], charRegValue[MAXCHRLEN], charCurrentMetaData[MAXCHRLEN];

//FILE        *fhin = NULL;
FILE         *fhout = NULL;
FILE         *fhmtd = NULL;
struct FLContext  *handle = NULL;

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
int position;
int main(int argc, char *argv[])
{
				int rc;
				//PT device
				float t, p, alt;

				//Check the arguments
				if (!parse_param(argc, argv)) {
								show_usage(argv[0]);
								return 1;
				}

				//initialize devices. TODO: add error checking 
				mem_init();
//				intc_init();    
				cfg_init();    
//				sts_init();    
//				xadc_init();

				//Check if it is the first time we access the PL
				//This is for initial configuration
				//default is MASTER mode, using false PPS
				if (dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET) == 0) //first time access
				{
								printf("Initializing registers...\n");
								init_system();
								//FIXME: here i should initialise my thread for working with false PPS
								rc = pthread_create(&not_gps,NULL,thread_isr_not_gps,NULL);
								if (rc != EXIT_SUCCESS) {
												perror("pthread_create :: error \n");
												exit(EXIT_FAILURE);
								}

								enable_interrupt();
				}

				//Ckeck if we should use GPS data or PC data
				/*				if (((dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET)>>4) & 0x1) == 0) //ok, we should use GPS data
									{
									rc = pthread_create(&actual_gps,NULL,thread_isr,NULL);
									if (rc != EXIT_SUCCESS) {
									perror("pthread_create :: error \n");
									exit(EXIT_FAILURE);
									}

									enable_interrupt();
									}*/

				signal(SIGINT, signal_handler);

				if(fReadReg) {
								rd_reg_value(n_dev, reg_off);  // Read single register
				}
				else if (fWriteReg) {
								wr_reg_value(n_dev, reg_off, reg_val);  // Write single register
				}
				else if (fSetCfgReg) {
								else wr_reg_value(1,reg_off, atoi(charRegValue));        // For t1, t2, st1, st2  
				}
				else if (fGetCfgStatus) {
								rd_cfg_status();        // Get registers status
				}
				else if (fGetGPS) { 
								if (((dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET)>>4) & 0x1) == 1) { // No GPS is present
												printf("No GPS device is present or enabled!!!\n");
								}
								else{
												gps_print_data();     // Print GPS data to stdout 
								}		
				}
				else if (fInitSystem) {
								printf("Initializing registers...\n");
								init_system();
				}
				else if (fToFile || fToStdout) {

								limit = 1024*1024*8; // whole memory
								current = -4; // new readout system, hack due to using +4 for readout
								// enter normal mode for tlast_gen
								reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
								dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 2);
								// enter normal mode for pps_gen, fifo and trigger modules
								reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
								dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 1);
								// enter normal mode for data converter and writer
								reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
								dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 4);

								//FIXME: here we should enable interrupts 
								while(!interrupted){
												wait_for_interrupt(intc_fd, intc_ptr);
												read_buffer(position, bmp);
												// alarm(0);   // cancelling 1 sec timeout
								}
								// reset pps_gen, fifo and trigger modules
								reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
								dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~1);
								/* reset data converter and writer */
								reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
								dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~4);
								// enter reset mode for tlast_gen
								reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
								dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~2);

				}

				// unmap and close the devices 
				//munmap(intc_ptr, sysconf(_SC_PAGESIZE));
				munmap(cfg_ptr, sysconf(_SC_PAGESIZE));
				//munmap(sts_ptr, sysconf(_SC_PAGESIZE));
				//munmap(xadc_ptr, sysconf(_SC_PAGESIZE));
				munmap(mem_ptr, sysconf(_SC_PAGESIZE));

				//close(intc_fd);
				close(cfg_fd);
				//close(sts_fd);
				//close(xadc_fd);

				return 0;

}

void signal_handler(int sig)
{
				interrupted = 1;
}

//int wait_for_interrupt(int fd_int, void *dev_ptr) 
//{
//				uint32_t value;
//				uint32_t info = 1; /* unmask */
//
//				ssize_t nb = write(fd_int, &info, sizeof(info));
//				if (nb != (ssize_t)sizeof(info)) {
//								perror("write");
//								close(fd_int);
//								exit(EXIT_FAILURE);
//				}
//
//				// block (timeout for poll) on the file waiting for an interrupt 
//				struct pollfd fds = 
//				{
//								.fd = fd_int,
//								.events = POLLIN,
//				};
//
//				int ret = poll(&fds, 1, 1000);
//				//printf("ret is : %d\n", ret);
//				if (ret >= 1) {
//								nb = read(fd_int, &info, sizeof(info));
//								if (nb == (ssize_t)sizeof(info)) {
//												/* Do something in response to the interrupt. */
//												value = dev_read(dev_ptr, XIL_AXI_INTC_IPR_OFFSET);
//												if ((value & 0x00000001) != 0) {
//																dev_write(dev_ptr, XIL_AXI_INTC_IAR_OFFSET, 1);
//																// read writer position 
//																position = dev_read(sts_ptr, STS_STATUS_OFFSET);
//
//												}
//								} else {
//												perror("poll()");
//												close(fd_int);
//												exit(EXIT_FAILURE);
//								}
//								}
//					return ret;
//}

/*void *thread_isr(void *p) 
{
				int32_t g_tim, g_dat, g_lat, g_lon, g_alt, g_sat;
				//initialize GPS connection
				gps_init();
				while(1)
								if (wait_for_interrupt(intc_fd, intc_ptr)){
												//get GPS data
												gps_location(&g_data);
												//write GPS data into registers
												//FIXME: see how and where to write pressure and temperature data
												// convert float to int32_t to write to FPGA
												g_tim = (int32_t)(g_data.times); 
												g_dat = (int32_t)(g_data.date); 
												g_lat = (int32_t)(g_data.latitude * 65536);
												g_lon = (int32_t)(g_data.longitude * 65536);
												g_alt = (int32_t)(g_data.altitude * 65536);
												g_sat = (int32_t)(g_data.satellites); 

												dev_write(cfg_ptr,CFG_TIME_OFFSET, g_tim);
												dev_write(cfg_ptr,CFG_DATE_OFFSET, g_dat);
												dev_write(cfg_ptr,CFG_LATITUDE_OFFSET, g_lat);
												dev_write(cfg_ptr,CFG_LONGITUDE_OFFSET, g_lon);
												dev_write(cfg_ptr,CFG_ALTITUDE_OFFSET, g_alt);
												dev_write(cfg_ptr,CFG_SATELLITE_OFFSET, g_sat);
												//printf("%lf %lf\n", gps_data.latitude, gps_data.longitude);
								}
}*/

/*void *thread_isr_not_gps(void *p) 
{
				//int32_t g_tim, g_dat, g_lat, g_lon, g_alt, g_sat;
				while(1)
								if (wait_for_interrupt(intc_fd, intc_ptr)){
												//write GPS data into registers
												//FIXME: see how and where to write pressure and temperature data
												// convert float to int32_t to write to FPGA
												//  g_tim = (int32_t)(g_data.times); 
												//	g_dat = (int32_t)(g_data.date); 
												//	g_lat = (int32_t)(g_data.latitude * 65536);
												//	g_lon = (int32_t)(g_data.longitude * 65536);
												//	g_alt = (int32_t)(g_data.altitude * 65536);
												//	g_sat = (int32_t)(g_data.satellites); 

												//	dev_write(cfg_ptr,CFG_TIME_OFFSET, g_tim);
												//	dev_write(cfg_ptr,CFG_DATE_OFFSET, g_dat);
												//	dev_write(cfg_ptr,CFG_LATITUDE_OFFSET, g_lat);
												//	dev_write(cfg_ptr,CFG_LONGITUDE_OFFSET, g_lon);
												//	dev_write(cfg_ptr,CFG_ALTITUDE_OFFSET, g_alt);
												//	dev_write(cfg_ptr,CFG_SATELLITE_OFFSET, g_sat);
												// 
												//printf("%lf %lf\n", gps_data.latitude, gps_data.longitude);
}
}*/

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
								printf("\n\tDPR Lab. 2018\n");
								printf("\tH. Arnaldi, lharnaldi@gmail.com\n");
								printf("\tX. Bertou, bertou@gmail.com\n");
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
								printf("\t-i\t\t\t\tInitialise registers to default values\n");
								printf("\t-x\t\t\t\tRead the voltage in the XADC channels\n");
								printf("\t-v\t\t\t\tShow DAQ version\n");

								printf("\n\tRegisters:\n");
								printf("\tt1, t2\t\t\t\tSpecify triggers 1 and 2\n");
								printf("\tsc1, sc2\t\t\tSpecify scaling factor 1 and 2\n");
								//printf("\tst1, st2, st3\t\t\tSpecify subtriggers 1, 2 and
								//3\n");
								printf("\thv1, hv2\t\t\tSpecify high voltages\n");
								printf("\tov1, ov2, ov3, ov4\t\tSpecify output voltages\n");
								//printf("\tiv1, iv2, iv3, iv4\t\t\tRead input voltages\n");

								printf("\n\tOptions:\n");
								printf("\t-f <filename>\t\t\tSpecify file name\n");
								//printf("\t-c <# bytes>\t\t\tNumber of bytes to read/write\n");
								//printf("\t-b <byte>\t\t\tValue to load into register\n");

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
				fGetGPS    = 0;
				fFile      = 0;
				fCount     = 0;
				fByte      = 0;
				fData      = 0;
				fRegValue  = 0;
				fGetXADC   = 0;

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
				else if( strcmp(charAction, "-g") == 0) {
								fGetGPS = 1;
								return 1;
				} 
				else if( strcmp(charAction, "-i") == 0) {
								fInitSystem = 1;
								return 1;
				} 
				else if( strcmp(charAction, "-x") == 0) {
								fGetXADC = 1;
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
								if (fWriteReg) reg_val = strtoul(argv[4],NULL,16);
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
								// Registers for output voltages
								else if(strcmp(charReg, "ov1") == 0) {
												reg_off = CFG_HV1_OFFSET;
								} 
								else if(strcmp(charReg, "ov2") == 0) {
												reg_off = CFG_HV2_OFFSET;
								} 
								else if(strcmp(charReg, "ov3") == 0) {
												reg_off = CFG_HV3_OFFSET;
								} 
								else if(strcmp(charReg, "ov4") == 0) {
												reg_off = CFG_HV4_OFFSET;
								} 
								// Registers for scalers
								else if(strcmp(charReg, "sc1") == 0) {
												reg_off = CFG_TR_SCAL_A_OFFSET;
								} 
								else if(strcmp(charReg, "sc2") == 0) {
												reg_off = CFG_TR_SCAL_B_OFFSET;
								} 
								// Unrecognized
								else { // unrecognized register to set
												return 0;
								}
								//charCount[0] = '4';
								//fCount = 1;
								StrcpyS(charRegValue, 16, argv[3]);
								if((strncmp(charReg, "hv", 2) == 0) || (strncmp(charReg, "ov", 2) == 0)) {
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

int new_file() 
{
				char buf[256];
				time_t currt=time(NULL);
				//uint32_t i;

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
								//fprintf(stderr,"Opening files %s and %s for data taking\n",charCurrentFile, charCurrentMetaData);
								fprintf(stderr,"Opening file %s at %02dh%02d for data taking\n",charCurrentFile,fileDate->tm_hour,fileDate->tm_min);
				}
				fprintf(fhout,"# v %d\n", DATAVERSION);
				fprintf(fhout,"# #\n");
				fprintf(fhout,"# # This is a %s raw data file, version %d\n",EXP,DATAVERSION);
				fprintf(fhout,"# # It contains the following data:\n");
				fprintf(fhout,"# #   <N1> <N2>        : line with values of the 2 ADC for a triggered pulse\n");
				//fprintf(fhout,"# #                      it is a subtrigger with the pulse maximum bin if only one such line is found\n");
				//fprintf(fhout,"# #                      it is a trigger with the full pulse if 16 lines are found\n");
				fprintf(fhout,"# #   # t <C> <V>      : end of a trigger\n");
				fprintf(fhout,"# #                      gives the channel trigger (<C>: 3 bit mask) and 125 MHz clock count (<V>) of the trigger time\n");
				fprintf(fhout,"# #   # c <C>          : internal trigger counter\n");
				fprintf(fhout,"# #   # x f <V>        : 125 MHz frequency\n");
				fprintf(fhout,"# #   # x t <V>        : temperature value\n");
				fprintf(fhout,"# #   # x p <V>        : pressure value\n");
				fprintf(fhout,"# #   # x r1 <V>       : pulse rate at channel 1\n");
				fprintf(fhout,"# #   # x r2 <V>       : pulse rate at channel 2\n");
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
				fprintf(fhout,"# x c T1 %d\n",dev_read(cfg_ptr, CFG_TRLVL_1_OFFSET));
				fprintf(fhout,"# x c T2 %d\n",dev_read(cfg_ptr, CFG_TRLVL_2_OFFSET));
				{
								//float a = 0.0382061, b = 4.11435;  // For gain = 1.45
								float a = 0.0882006, b = 7.73516;  // For gain = 3.2
								fprintf(fhout,"# x c HV1 %.1f mV\n",a*dev_read(cfg_ptr, CFG_HV1_OFFSET)+b);
								fprintf(fhout,"# x c HV2 %.1f mV\n",a*dev_read(cfg_ptr, CFG_HV2_OFFSET)+b);
				}
				fprintf(fhout,"# x c SC1 %d\n",dev_read(cfg_ptr, CFG_TR_SCAL_A_OFFSET));
				fprintf(fhout,"# x c SC2 %d\n",dev_read(cfg_ptr, CFG_TR_SCAL_B_OFFSET));
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

int r[MTD_TRG];

int read_buffer(int pos, void *bmp)
{
				uint32_t wo;
				int16_t ch[2];
				//uint32_t i, j;
				uint32_t i;
				//int offset;
				int trig;
				//int32_t v_temp;
				int readinit=0;
				int readend=limit;

				if (fToStdout)
								fhout=stdout;
				if (fFirstTime) {
								// if no GPS 
								if (((dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET)>>4) & 0x1) == 1) { // get time form PC
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

												fileTime=timegm(fileDate);
												fileDate=gmtime(&fileTime); // filling all fields
								}
								if (fhout != stdout) {
												//FIXME: here read PyT data

								}
								new_file();
								fFirstTime=0;
				}

				// pos is the number of 8 bytes word written. I need the memory
				// location... Therefore, pos=pos*8
				pos=pos*8;

				//printf("%d %d %d\n",current,pos,limit);
				//fprintf(fhout,"# XB %d %d %d\n", current,pos,limit);
				// print 512 IN1 and IN2 samples if ready, otherwise sleep 1 ms
				// compare current writing location (pos) with previous (limit)
				// if current<pos, then read from current to pos and adjust current
				// if current>pos, then read from current to end of buffer and set current to 0 at the end
				if (current==limit-4) current=-4; // hack, because I do +4 next to read from next position
				if (current<pos+4) {
								readinit=current+4;
								readend=pos;
				} else if (current>pos) {
								readinit=current+4;
								readend=limit; // note: don't read after limit
				}
				if(current!=pos) {

								//printf("# # # # NEW BUFFER %d %d \n", pos, limit);
								//offset = limit > 0 ? 0 : 4096*1024;
								//limit = limit > 0 ? 0 : 512*1024;

								for(i = readinit; i < readend; i+=4) {
												ch[0] = *((int16_t *)(mem_ptr + i + 0));
												ch[1] = *((int16_t *)(mem_ptr + i + 2));
												//printf("%5d %5d\n", ch[0], ch[1]);
												wo = *((uint32_t *)(mem_ptr + i));
												if (wo>>30==0) {
																fprintf(fhout,"%5hd %5hd\n", (((ch[0]>>13)<<14) + ((ch[0]>>13)<<15) + ch[0]),(((ch[1]>>13)<<14) + ((ch[1]>>13)<<15) + ch[1]));
																mtd_iBin++;
																if (mtd_iBin == MTD_BLBIN) {
																				mtd_bl[0] += ch[0];
																				mtd_bl2[0] += ch[0] * ch[0];
																				mtd_bl[1] += ch[1];
																				mtd_bl2[1] += ch[1] * ch[1];
																				mtd_cbl++;
																}
												} 
												else {
																if (wo>>30==1) { //get trigger status and counter between PPS
																				fprintf(fhout,"# t %d %d\n", (wo>>27)&0x7, wo&0x7FFFFFF);
																				trig=(wo>>27)&0x7;
																				r[trig]++;
																				mtd_iBin=0;
																} 
																else {
																				if (wo>>30==2) {//get counter status
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
																																fprintf(fhout,"# x f %d \n", wo&0x07FFFFFF);//PPS counter
																																break;
																												case 0x19:
																																fprintf(fhout,"# x t %.1f \n", bmp180_temperature(bmp));
																																break;
																												case 0x1A:
																																fprintf(fhout,"# x p %.2f \n", (bmp180_pressure(bmp)/100.));
																																break;
																												case 0x1B:
																																if(falseGPS) {
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
																																fprintf(fhout,"# x h   %02d:%02d:%02d %02d/%02d/%04d %d %d\n",
																																								fileDate->tm_hour, fileDate->tm_min, fileDate->tm_sec,
																																								fileDate->tm_mday, fileDate->tm_mon+1,fileDate->tm_year+1900,
																																								(int)fileTime,wo&0x03FFFFFF
																																			 );
																																fprintf(fhout,"# p %u %.1f %.1f\n",hack++,get_temp_AD592(XADC_AI0_OFFSET),get_temp_AD592(XADC_AI1_OFFSET));
																																if (hack%60==0) printf("\n");
																																printf("rates %5d %5d, PPS %u        \r",r1,r2,hack);
																																fflush(stdout);
																																/*fprintf(stderr,"# %02d:%02d:%02d %02d/%02d/%04d %d - second %d - rates: %d %d %d (%d - %d - %d) [%d]\r", 
																																	fileDate->tm_hour, fileDate->tm_min, fileDate->tm_sec,
																																	fileDate->tm_mday, fileDate->tm_mon+1, fileDate->tm_year+1900,
																																	(int)fileTime,
																																	mtd_seconds,
																																	r[1], r[2], r[4], r[3], r[5], r[6], r[7]
																																	);*/
																																//for (j=0; j<MTD_TRG; j++) {
																																//				mtd_rates[i] += r[i];
																																//				mtd_rates2[i] += r[i] * r[i];
																																//				r[i] = 0;
																																//}
																																break;
																																//FIXME: see if can add the FPGA interface in this stage
																												case 0x1C: // Longitude, latitude, defined by other bits
																																switch(((wo)>>24) & 0x7) {
																																				case 0:
																																								gps_lat=((int32_t)(wo&0xFFFFFF)<<8>>8)/65536.0;
																																								//gps_lat=v_temp/65536.0;
																																								break;
																																				case 1:
																																								gps_lon=((int32_t)(wo&0xFFFFFF)<<8>>8)/65536.0;
																																								//gps_lat=v_temp/65536.0;
																																								break;
																																				case 2:
																																								gps_alt=((int32_t)(wo&0xFFFFFF)<<8>>8)/65536.0;
																																								//gps_lat=v_temp/65536.0;
																																								//fprintf(fhout,"# x g %.6f %.6f %.2f\n",gps_lat,gps_lon,gps_alt);
																																								fprintf(fhout,"# x g %.6f %.6f %.2f\n",g_data.latitude,g_data.longitude,g_data.altitude);
																																								//tmp_gps_lon=((wo & 0xFFFFFF)<<8);
																																								break;
																																								/*case 3: FIXME: here is the date data
																																								// Not used here
																																								//gps_lon=((int)(tmp_gps_lon+(wo & 0xFF)))/3600000.;
																																								break;
																																								case 4:
																																								//tmp_gps_elips=((wo & 0xFFFFFF)<<8);
																																								break;
																																								case 5:
																																								//gps_elips=((int)(tmp_gps_elips+(wo & 0xFF)))/100.;
																																								//fprintf(fhout,"# x g %.6f %.6f %.2f\n",gps_lat,gps_lon,gps_elips);
																																								break;*/
																																				default:
																																								break;
																																}
																																break;
																												case 0x1D: //rate ch1 counter
																																fprintf(fhout,"# r1 %d \n", (int32_t)wo&0x00FFFFFF);
																																r1= (int32_t)wo&0x00FFFFFF;
																																break;
																												case 0x1E: //rate ch2 counter
																																fprintf(fhout,"# r2 %d \n", (int32_t)wo&0x00FFFFFF);
																																r2= (int32_t)wo&0x00FFFFFF;
																																break;
																												default:
																																fprintf(fhout,"# E @@@\n");
																																fprintf(fhout,"# E 3 - unknown word from FPGA: %d %x\n",wo>>27,wo>>27);
																																break;
																							}
																				}
																}
												}
												current=i;
							}
				}
				return 1;
}

