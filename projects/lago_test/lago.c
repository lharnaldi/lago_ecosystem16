#include <stdio.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <math.h>
#include <sys/time.h>
#include <fstream>
#include <iostream>
#include <vector>

#ifdef FUTURE
#include <unordered_map>
#endif

#include "defs.h"
#include "extras.h"

using namespace std;

/* ------------------------------------------------------------ */
/*  Global Variables          */
/* ------------------------------------------------------------ */
int fGetReg, fGetRegSet, fGetPT, fGetGPS, fPutReg, fPutRegSet,
  fToFile, fToStdout, fFile, fCount, fByte, fData, 
  fFirstTime=true, fScanJTAG, fUsbPower=true, fXsvfFile,
  fshowversion;

char scAction[MAXCHRLEN], scRegister[MAXCHRLEN], scReg[MAXCHRLEN],
  scDvc[MAXCHRLEN] = "Nexys2", scFile[MAXCHRLEN], scCurrentFile[MAXCHRLEN],
  scCount[MAXCHRLEN], scByte[MAXCHRLEN], scData[MAXCHRLEN], scCurrentMetaData[MAXCHRLEN];

uint32_t      hif = 0;
FLStatus     status;
uint8_t        *buffer = NULL;
const char  *dataFile = NULL;
const char   *vp = "1443:0020";
const char  *ivp = "1443:0005";
const char  *jtagPort = "D0234";
const char  *xsvfFile = NULL;
const char  *fromFile = NULL;
const char  *error = NULL;

FILE        *fhin = NULL;
FILE         *fhout = NULL;
FILE         *fhmtd = NULL;
struct FLContext  *handle = NULL;

extern long Tab_BasicAltitude[80];

void *cfg, *sts, *ram;

#ifdef FUTURE
unordered_map<string, string> hConfigs;
#endif

//*****************************************************
// Pressure, temperature and other constants
//****************************************************
extern uint32_t  ptC1, ptC2, ptC3, ptC4, ptC5, ptC6, ptC7, ptD1, ptD2;
extern uint8_t   ptAA, ptBB, ptCC, ptDD;
uint8_t   gpsDate[7];
double  bl1=0,bl2=0,bl3=0;
int     tmp_gps_lat,tmp_gps_lon,tmp_gps_elips;
double  gps_lat,gps_lon,gps_elips;
uint32_t  gfT1,gfT2,gfT3,gfST1,gfST2,gfST3,gfHV1,gfHV2,gfHV3,gGPSTM;


//****************************************************
// Time globals for filenames
//****************************************************
time_t    fileTime;
struct tm  *fileDate;
int        falseGPS=false;

//****************************************************
// Metadata
//****************************************************
// Metadata calculations, dataversion v5 need them
// average rates and deviation per trigger condition
// average baseline and deviation per channel
// using long int as max_rate ~ 50 kHz * 3600 s = 1.8x10^7 ~ 2^(20.5)
// and is even worst for baseline
#define MTD_TRG		8
#define MTD_BL		3
#define MTD_BLBIN	1
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
// and finally, a vector of strings to handle configs file. I'm also including a hash table
// for future implementations. For now, we just dump the lago-configs file
vector <string> configs_lines;

void handler(int signo);

int interrupted = 0;

void signal_handler(int sig) {
  interrupted = 1;
}

int init_mem() {
  char *name = "/dev/mem";
  int mfd;

  if((mfd = open(name, O_RDWR)) < 0)
  {
    perror("open");
    return 1;
  }

  cfg = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, mfd, 0x40000000);
  sts = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, mfd, 0x40001000);
  ram = mmap(NULL, 1024*sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, mfd, 0x1E000000);

  return 0;

}

int main(int argc, char *argv[]) {

  //  New code
  int returnCode;
  FLStatus status;
  bool flag;
  bool isNeroCapable;
  uint32_t numDevices, scanChain[16], i;
  int position, limit, offset;
  
  //  end new code
  
  uint8_t  AddrGPSDate[7] = {51, 52, 53, 54, 55, 56, 57};
  uint8_t    AddrID[2] = {115, 116};
  uint8_t    rgbChkVer;
  struct sigaction act;
  sigset_t mask;
  
  // ALARM setting in case of issue
  sigemptyset(&mask);
  sigaddset(&mask, SIGALRM);
  act.sa_handler = handler;
  act.sa_flags = 0;
  sigemptyset(&act.sa_mask);
  sigaction(SIGALRM, &act, NULL);


  if (!parse_param(argc, argv)) {
    show_usage(argv[0]);
    return 1;
  }
  /* Reading lago-configs file */
  fprintf(stderr,"Reading configs... ");
  ifstream filecfg;
  filecfg.open("lago-configs");
  if (!filecfg) {
    fprintf(stderr,"\n\n\tFailed to open lago-configs.\n\tPlease run ./lago-configs.pl before to continue\n\n");
    exit(1);
  }
  string line;
#ifdef FUTURE
  string key, value;
  string delimiter="=";
#endif
  while (getline(filecfg, line)) {
    if (line.empty())
      continue;
    if (line[0] == '#')
      continue;
    configs_lines.push_back(line);
#ifdef FUTURE
  //this block defines an unordered map (hash table) containing the configs pair as defined 
  //in the lago-configs file. 
    key = line.substr(0,line.find(delimiter));
    value = line.substr(line.find(delimiter)+1);
    hConfigs.insert(make_pair(key,value));
#endif
  }
  fprintf(stderr,"done. \n");
  // initializing mtd variables
  for (int i=0; i<MTD_TRG;i++) 
    mtd_rates[i]=mtd_rates2[i]=0;
  for (int i=0; i<MTD_BL; i++)
    mtd_bl[i]=mtd_bl2[i]=0;

  if(init_mem() != 0) {
    perror("Error mapping memory\n");
    return 1;
  }

  if(fGetReg) {
    DoGetRegSync();          /* Get single byte from register */
  }
  
  else if (fPutReg) {
  				DoPutRegSync();          /* Send single byte to register */
  }
  
  else if (fPutRegSet) {
  				DoPutRegSetSync();        /* Send two bytes to consecutive registers */
  }
  
  else if (fGetRegSet) {
  				DoGetRegSetSync();        /* Get registers status */
  }
  
  else if (fGetPT) {
  				DoGetPandTnFifoSync();      /*   Get pressure and temperature
  																				 from HP03 sensor*/
  }
  
  else if (fGetGPS) {
  				DoGetGPSnFifoSync();      /* Save file with contents of register */
  }
  
  else if (fToFile || fToStdout) {
  				for(i=0; i<7; i++) {
  								status=flReadChannel(handle, 100, AddrGPSDate[i], 1, &gpsDate[i], &error);
  								CHECK(10);
  				}
  				//Probes
  				/*    for(i=0; i<4; i++) {
  							if(flReadChannel(handle, 10, DCountAddr[i], 1, &DCountR[i], &error)) {
  							printf("flReadChannel failed\n");
  							error_exit();
  							}
  							printf("RrDataCountA = %d\n", DCountR[0]);
  							printf("WrDataCountA = %d\n", DCountR[1]);
  							printf("RrDataCountB = %d\n", DCountR[2]);
  							printf("WrDataCountB = %d\n", DCountR[3]);
  
  							}
  				 */   // End of probe
  
  				fprintf(stderr,"Cleaning buffers\n");
  				read_buffer(0,27);
  				//read_buffer(0,28);
  				fprintf(stderr,"Starting DAQ at %02d:%02d:%02d\n", fileDate->tm_hour, fileDate->tm_min, fileDate->tm_sec);
  				for(;;) {
  								alarm(2);   // setting 1 sec timeout
  								read_buffer();
  								alarm(0);   // cancelling 1 sec timeout
  				}
  }
  returnCode = 0;

cleanup:
				flFreeFile(buffer);
				flClose(handle);
				return returnCode;

}


//void DoGetRegSync() {
//
//  uint8_t  idReg, idData;
//  char *szStop;
//  
//  idReg = (uint8_t) strtol(scRegister, &szStop, 10);
//  
//  if(flReadChannel(handle, 100, idReg, 1, &idData, &error)) {
//  				printf("flReadChannel failed\n");
//  				error_exit();
//  }
//  printf("Complete. Received data %d\n", idData);
//  
//  return;
//}


uint32_t reg_write(uint32_t *reg_base, int offset, uint32_t value) { 
	*((volatile uint32_t *)(reg_base + offset)) = value; 
} 

uint32_t reg_read(uint32_t *reg_base, int offset) { 
	return *((volatile uint32_t *)(reg_base + offset)); 
} 

//void DoPutRegSync() {
//
//				uint8_t  idReg, idData;
//				char *  szStop;
//
//				idReg = (uint8_t) strtol(scRegister, &szStop, 10);
//				idData = (uint8_t) strtol(scByte, &szStop, 10);
//
//				if(flWriteChannel(handle, 100, idReg, 1, &idData, &error)) {
//								printf("flWriteChannel failed\n");
//								return;
//				}
//
//				printf("Complete. Register set.\n");
//
//				return;
//}


//void DoPutRegSetSync() {
//
//				long    dt;
//				uint8_t    idReg, idRegSig, dmsb, dlsb;
//				char    *szStop;
//
//				idReg    = (uint8_t) strtol(scRegister, &szStop, 10);
//				idRegSig = idReg + 1;
//				dt       = strtol(scData, &szStop, 10);
//				dmsb     = dt/256;
//				dlsb     = dt%256;
//
//				if(flWriteChannel(handle, 100, idReg, 1, &dmsb, &error)) {
//								printf("flWriteChannel failed\n");
//								return;
//				}
//				if(flWriteChannel(handle, 100, idRegSig, 1, &dlsb, &error)) {
//								printf("flWriteChannel failed\n");
//								return;
//				}
//
//				printf("Stream to registers complete!\n");
//				return;
//}


void DoGetRegSetSync() {

				uint8_t    ucAddr[25] = {1, 2, 3, 4, 5, 6, 7, 8, 9, \
								10, 11, 12, 13, 14, 15, 16,\
												17, 18, 19, 20, 21, 22, 23,\
												24, 25
				}, rgbStf[BLOCKSIZE];

				for(int8 i=0; i<25; i++) {
								if(flReadChannel(handle, 10, ucAddr[i], 1, &rgbStf[i], &error)) {
												printf("flWriteChannel failed\n");
												error_exit();
								}
				}
				printf("#Trigger Level Ch1 = %d\n", (rgbStf[0]* 256 + rgbStf[1]));
				printf("#Trigger Level Ch2 = %d\n", (rgbStf[2]* 256 + rgbStf[3]));
				printf("#Trigger Level Ch3 = %d\n", (rgbStf[4]* 256 + rgbStf[5]));
				//printf("#Subtrigger Ch1    = %d\n", (rgbStf[6]* 256 + rgbStf[7]));
				//printf("#Subtrigger Ch2    = %d\n", (rgbStf[8]* 256 + rgbStf[9]));
				//printf("#Subtrigger Ch3    = %d\n", (rgbStf[10]* 256 + rgbStf[11]));
				/*  printf("#Base Line 1       = %d\n", (rgbStf[12]* 256 + rgbStf[13]));
						printf("#Base Line 2       = %d\n", (rgbStf[14]* 256 + rgbStf[15]));
						printf("#Base Line 3       = %d\n", (rgbStf[16]* 256 + rgbStf[17]));*/
				printf("#High Voltage 1    = %d\n", (rgbStf[18]* 256 + rgbStf[19]));
				printf("#High Voltage 2    = %d\n", (rgbStf[20]* 256 + rgbStf[21]));
				printf("#High Voltage 3    = %d\n", (rgbStf[22]* 256 + rgbStf[23]));
				if (rgbStf[24] == 0) {
								printf("#GPS Time Mode     = UTC\n");
				} else {
								printf("#GPS Time Mode     = GPS\n");
				}
				printf("\n");
				printf("Status from registers complete!\n");
				return;
}


int NewFile() {
  if (!fToStdout) {
    if (fhout) {
     fclose(fhout);
}
if (fhmtd) {
//before to close the file we have to fill DAQ status metadata
// Average and deviation trigger rates
double mtd_avg[MTD_TRG], mtd_dev[MTD_TRG];
if (!mtd_seconds) {
				for (int i=0; i<MTD_TRG; i++)
								mtd_avg[i] = mtd_dev[i] = -1.;
} else {
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
} else {
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
}
fileTime=timegm(fileDate);
fileDate=gmtime(&fileTime); // filling all fields with properly computed values (for new month/year)
if (falseGPS) {
				snprintf(scCurrentFile,MAXCHRLEN,"%s_nogps_%04d_%02d_%02d_%02dh00.dat",scFile,fileDate->tm_year+1900, fileDate->tm_mon+1,fileDate->tm_mday,fileDate->tm_hour);
				snprintf(scCurrentMetaData,MAXCHRLEN,"%s_nogps_%04d_%02d_%02d_%02dh00.mtd",scFile,fileDate->tm_year+1900, fileDate->tm_mon+1,fileDate->tm_mday,fileDate->tm_hour);
} else {
				snprintf(scCurrentFile,MAXCHRLEN,"%s_%04d_%02d_%02d_%02dh00.dat",scFile,fileDate->tm_year+1900, fileDate->tm_mon+1,fileDate->tm_mday,fileDate->tm_hour);
				snprintf(scCurrentMetaData,MAXCHRLEN,"%s_%04d_%02d_%02d_%02dh00.mtd",scFile,fileDate->tm_year+1900, fileDate->tm_mon+1,fileDate->tm_mday,fileDate->tm_hour);
}
fhout = fopen(scCurrentFile, "ab");
fhmtd = fopen(scCurrentMetaData, "w");
fprintf(stderr,"Opening files %s and %s for data taking\n",scCurrentFile, scCurrentMetaData);
}
fprintf(fhout,"# v %d\n", DATAVERSION);
fprintf(fhout,"# #\n");
fprintf(fhout,"# # This is a %s raw data file, version %d\n",EXP,DATAVERSION);
fprintf(fhout,"# # It contains the following data:\n");
fprintf(fhout,"# #   <N1> <N2> <N3>   : line with values of the 3 ADC for a triggered pulse\n");
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
if (gGPSTM == 0) {
				fprintf(fhout,"# x c GPSTM UTC\n");
} else {
				fprintf(fhout,"# x c GPSTM GPS\n");
}
fprintf(fhout,"# #\n");
char buf[256];
time_t currt=time(NULL);
gethostname(buf, 256);
fprintf(fhout,"# # This file was started on %s\n",buf);
fprintf(fhmtd, "daqHost=\"%s\"\n",buf);
ctime_r(&currt,buf);
fprintf(fhout,"# # Machine local time was %s",buf);
strtok(buf, "\n");
fprintf(fhmtd, "machineTime=\"%s\"\n",buf);
if (falseGPS) fprintf(fhout,"# # WARNING, there is no GPS, using PC time\n");
fprintf(fhout,"# #\n");
fprintf(fhmtd, "dataFile=\"%s\"\n",scCurrentFile);
fprintf(fhmtd, "metadataFile=\"%s\"\n",scCurrentMetaData);
fprintf(fhmtd, "daqVersion=%d\n",VERSION);
fprintf(fhmtd, "daqUseGPS=%s", (!falseGPS)?"true":"false");
fprintf(fhmtd, "dataVersion=%d\n",DATAVERSION);
for (unsigned int i=0; i<configs_lines.size(); i++)
				fprintf(fhmtd, "%s\n", configs_lines[i].c_str());
fprintf(fhmtd, "version=\"LAGO ACQUA BRC v%dr%d data v%d\"\n",VERSION,REVISION,DATAVERSION);
fflush(fhout);
fflush(fhmtd);
return 0;
}

//#define CIRCSIZE 32768
#define CIRCSIZE 65536
uint8_t circbuf[CIRCSIZE];
uint32_t bufwrite=0;
uint32_t bufread=0;
int bufsync=0;
int r[MTD_TRG];

int read_buffer(int wr, int clean) {

long    cb = 0;
uint8_t   idReg, idData, rgbPT[49];
uint32_t  ch1, ch2, ch3, wo;
uint8_t   ucAddr[49] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10,        // Trigger and HV info
				11, 12, 19, 20, 21, 22, 23, 24, 25,   // Trigger and HV info
				29, 30, 31, 32, 33, 34, 35, 36, 37,   // P and T constants
				38, 39, 40, 41, 42, 43, 44, 45, 46,   // P and T constants
				62, 63, 64, 65, 66, 67, 68, 69, 70,   // GPS data
				71, 72, 73};                          // GPS data       

if (!clean) {
	status=flReadChannel(handle, 10, 26, 1, &idData, &error);   // estatus buffers
	if ((idData & 128) == 128) {
					idReg = 27;
					cb = 16384;
	} else {
					return 0;
	}
} else {
	idReg=clean;
	cb = 32768;
	for (int i=0; i<MTD_TRG; i++)
					r[i] = 0;
}

if (fToStdout) 
				fhout=stdout;
if (fFirstTime) {
				// if no GPS
	if (((gpsDate[2] << 8) + gpsDate[3])==0) { // get time form PC
	  fileTime=time(NULL);
	  fileDate=gmtime(&fileTime); // filling all fields
	  falseGPS=true;
	} else {
		fileTime=time(NULL);
		fileDate=gmtime(&fileTime);
		fileDate->tm_sec=gpsDate[6];
		fileDate->tm_min=gpsDate[5];
		fileDate->tm_hour=gpsDate[4];
		fileDate->tm_mday=gpsDate[1];
		fileDate->tm_mon=gpsDate[0]-1;
		fileDate->tm_year=((gpsDate[2] << 8) + gpsDate[3])-1900;
		fileTime=timegm(fileDate);
		fileDate=gmtime(&fileTime); // filling all fields
	}
	if (fhout != stdout) {
		for(int8 i=0; i<49; i++) {
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
		gGPSTM = rgbPT[18];
	}
	NewFile();
	fFirstTime=false;
}

if(flReadChannel(handle, 100, idReg, cb, circbuf+(bufwrite%CIRCSIZE), &error)) {
	printf("flReadChannel failed\n");
	handler(1);
}
bufwrite+=cb;

if (!wr) bufread=bufwrite;

if (!bufsync) {
	int ok=0;
	while(bufread<bufwrite-4 && !bufsync) {
	if (circbuf[bufread%CIRCSIZE]==0xff) ok++;
	else ok=0;
	bufread++;
	if (ok==4) {
	bufsync=1;
	}
	}
}
//if (bufwrite-bufread>16380) bufread+=4;
//if (bufwrite-bufread>32768) {
//bufread+=4;
//printf("\nError el lectura\n");
//}
if (bufread>2*CIRCSIZE) {
	bufread-=CIRCSIZE;
	bufwrite-=CIRCSIZE;
}

while(bufread<bufwrite-4) {
	wo = ((circbuf[bufread%CIRCSIZE])<<24) + ((circbuf[(bufread+1)%CIRCSIZE])<<16) + (circbuf[(bufread+2)%CIRCSIZE]<<8) + (circbuf[(bufread+3)%CIRCSIZE]);
	bufread+=4;
	ch1 = (((wo)>>20) & 0x3FF);
	ch2 = (((wo)>>10) & 0x3FF);
	ch3 = (wo & 0x3FF);

	if (wo>>30==0) {
		//fprintf(fhout,"%d %d %d %d %d %d %d\n", ch1, ch2, ch3,bufread,bufwrite,idReg,idData);
		fprintf(fhout,"%d %d %d\n", ch1, ch2, ch3);
		mtd_iBin++;
		if (mtd_iBin == MTD_BLBIN) {
			mtd_bl[0] += ch1;
			mtd_bl2[0] += ch1 * ch1;
			mtd_bl[1] += ch2;
			mtd_bl2[1] += ch2 * ch2;
			mtd_bl[2] += ch3;
			mtd_bl2[2] += ch3 * ch3;
			mtd_cbl++;
		}
	} else {
      if (wo>>30==1) {
				fprintf(fhout,"# t %d %d\n", (wo>>27)&0x7, wo&0x7FFFFFF);
				int trig=(wo>>27)&0x7;
				r[trig]++;
				mtd_iBin=0;
			} else {
				if (wo>>30==2) {
					mtd_pulse_pnt =	mtd_pulse_cnt;
					mtd_pulse_cnt = (wo&0x3FFFFFFF);
					mtd_dp = (mtd_pulse_cnt - mtd_pulse_pnt - 1);
					if (mtd_dp > 0 && mtd_pulse_pnt)
									mtd_cdp += mtd_dp;
					fprintf(fhout,"# c %ld\n", mtd_pulse_cnt);
				} else {
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
							CalculatePressTemp(1);
							break;
						case 0x1B:
							if (falseGPS) {
								fileDate->tm_sec++;
								if (fileDate->tm_sec==60 && fileDate->tm_min==59) { // new hour
									if (!fToStdout) 
									NewFile();
								} else {
									fileTime=timegm(fileDate);
									fileDate=gmtime(&fileTime); // filling all fields with properly comupted values (for new month/year)
								}
							} else {
									if ((uint32_t)fileDate->tm_hour!=((wo>>16)&0x000000FF)) {
										// new hour of data
										if ((uint32_t)fileDate->tm_hour>((wo>>16)&0x000000FF)) { // new day
														fileDate->tm_mday++;
										}
										fileDate->tm_hour=(wo>>16)&0x000000FF;
										if (!fToStdout) 
											NewFile();
									}
									fileDate->tm_hour=(wo>>16)&0x000000FF;
									fileDate->tm_min=(wo>>8)&0x000000FF;
									fileDate->tm_sec=wo&0x000000FF;
							}
							mtd_seconds++;
							fileTime=timegm(fileDate);
							fileDate=gmtime(&fileTime); // filling all fields with properly comupted values (for new month/year)
							fprintf(fhout,"# x h   %02d:%02d:%02d %02d/%02d/%04d %d\n", fileDate->tm_hour, fileDate->tm_min, fileDate->tm_sec, 
							                                                            fileDate->tm_mday, fileDate->tm_mon+1,fileDate->tm_year+1900, 
							                                                            (int)fileTime);

							fprintf(stderr,"# %02d:%02d:%02d %02d/%02d/%04d %d - second %d - rates: %d %d %d (%d - %d - %d) [%d]\r", 
															fileDate->tm_hour, fileDate->tm_min, fileDate->tm_sec, 
															fileDate->tm_mday, fileDate->tm_mon+1, fileDate->tm_year+1900, 
															(int)fileTime,
															mtd_seconds, 
															r[1], r[2], r[4], r[3], r[5], r[6], r[7]
										 );
							for (int i=0; i<MTD_TRG; i++) {
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
						case 0x1F: // note : not used in LAGO, was used in MIDAS... Legacy
										bl1 = 2*(((wo)>>18) & 0x1FF);
										bl2 = 2*(((wo)>>9) & 0x1FF);
										bl3 = 2*(wo & 0x1FF);
										break;
						case 0x1E: // note : not used in LAGO, was used in MIDAS... Legacy
										bl1 += (((wo)>>18) & 0x1FF)/256.;
										bl2 += (((wo)>>9) & 0x1FF)/256.;
										bl3 += (wo & 0x1FF)/256.;
										fprintf(fhout,"# x b %.4f %.4f %.4f\n", bl1, bl2, bl3);
										break;
						default:
										fprintf(fhout,"# E @@@\n");
										fprintf(fhout,"# E 3 - unknown word from FPGA: %d %x\n",wo>>27,wo>>27);
										break;
					}
				}
					}
	}
}
return 1;
}


int parse_param(int argc, char *argv[]) {

  int    iszArg;
  
  /* Initialize default flag values */
  fGetReg    = false;
  fPutReg    = false;
  fGetRegSet = false;
  fPutRegSet = false;
  fToFile    = false;
  fToStdout  = false;
  fGetPT     = false;
  fGetGPS    = false;
  fFile      = false;
  fCount     = false;
  fByte      = false;
  fData      = false;
  fXsvfFile  = false;
  fScanJTAG  = false;
  
  /* Ensure sufficient paramaters. Need at least program name and
   ** action flag
   */
  if (argc < 2) {
    return false;
  }
  
  /* The first parameter is the action to perform. Copy the
   ** first parameter into the action string.
   */
  StrcpyS(scAction, MAXCHRLEN, argv[1]);
  
  if(strcmp(scAction, "-r") == 0) {
    fGetReg = true;
  } else if( strcmp(scAction, "-p") == 0) {
    fPutReg = true;
  } else if( strcmp(scAction, "-a") == 0) {
    fGetRegSet = true;
    return true;
  } else if( strcmp(scAction, "-v") == 0) {
    fshowversion = true;
    return false;
  } else if( strcmp(scAction, "-s") == 0) {
    fPutRegSet = true;
  } else if( strcmp(scAction, "-f") == 0) {
    fToFile = true;
  } else if( strcmp(scAction, "-o") == 0) {
    fToStdout = true;
    return true;
  } else if( strcmp(scAction, "-t") == 0) {
    fGetPT = true;
    return true;
  } else if( strcmp(scAction, "-g") == 0) {
    fGetGPS = true;
    return true;
  } else if( strcmp(scAction, "-x") == 0) {
    fXsvfFile = true;
  } else if( strcmp(scAction, "-j") == 0) {
    fScanJTAG = true;
    return true;
  } else { // unrecognized action
    return false;
  }
  
  /* Second paramater is target register on device. Copy second
   ** paramater to the register string */
  
  if (fPutRegSet) {
    StrcpyS(scReg, MAXCHRLEN, argv[2]);
    /*Registers for Triggers*/
    if(strcmp(scReg, "t1") == 0) {
      scRegister[0] = '1'; /* registers 1 and 2 are for trigger 1*/
    } else if(strcmp(scReg, "t2") == 0) {
      scRegister[0] = '3'; /* registers 3 and 4 are for trigger 2*/
    } else if(strcmp(scReg, "t3") == 0) {
      scRegister[0] = '5'; /* registers 5 and 6 are for trigger 3*/
    }
    /*Registers for Subtrigger*/
    else if(strcmp(scReg, "st1") == 0) {
    				scRegister[0] = '7'; /* registers 7 and 8 are for scaler 1*/
    } else if(strcmp(scReg, "st2") == 0) {
    				scRegister[0] = '9'; /* registers 9 and 10 are for scaler 2a*/
    } else if(strcmp(scReg, "st3") == 0) {
    				scRegister[0] = '1'; /* registers 11 and 12 are for scaler 3a*/
    				scRegister[1] = '1';
    }
    /*Registers for High Voltage*/
    else if(strcmp(scReg, "hv1") == 0) {
    				scRegister[0] = '1'; /* registers 13 and 14 are for DAC 4 aka hv1*/
    				scRegister[1] = '3';
    } else if(strcmp(scReg, "hv2") == 0) {
    				scRegister[0] = '1'; /* registers 15 and 16 are for PWM 1*/
    				scRegister[1] = '5';
    } else if(strcmp(scReg, "hv3") == 0) {
    				scRegister[0] = '1'; /* registers 17 and 18 are for PWM 2*/
    				scRegister[1] = '7';
    } else if(strcmp(scReg, "tm") == 0) {
    				scRegister[0] = '1'; /* register 19 are for Time Mode*/
    				scRegister[1] = '9';
    }
    /*Unrecognized */
    else { // unrecognized register to set
    				return false;
    }
    //scCount[0] = '4';
    //fCount = true;
    StrcpyS(scData, 16, argv[3]);
    if((strncmp(scReg, "hv",2) == 0)) {
    				if (atoi(scData)>4000) {
    								printf ("Error: maximum voltage 4000\n");
    								exit(1);
    				}
  }
  fData = true;
  } else if(fToFile) {
  				if(argv[2] != NULL) {
  								StrcpyS(scFile, MAXFILENAMELEN, argv[2]);
  								fFile = true;
  				} else {
  								return false;
  				}
  } else if(fXsvfFile) {
  				if(argv[2] != NULL) {
  								StrcpyS(scFile, 127, argv[2]); 
  				} else {
  								return false;
  				}
  } else {
  				StrcpyS(scRegister, MAXCHRLEN, argv[2]);
  
  				/* Parse the command line parameters.
  				 */
  				iszArg = 3;
  				while(iszArg < argc) {
  
  								/* Check for the -f parameter used to specify the
  								 ** input/output file name.
  								 */
  								if (strcmp(argv[iszArg], "-f") == 0) {
  												iszArg += 1;
  												if (iszArg >= argc) {
  																return false;
  												}
  												StrcpyS(scFile, 16, argv[iszArg++]);
  												fFile = true;
  								}
  
  								/* Check for the -c parameter used to specify the
  								 ** number of bytes to read/write from file.
  								 */
  								else if (strcmp(argv[iszArg], "-c") == 0) {
  												iszArg += 1;
  												if (iszArg >= argc) {
  																return false;
  												}
  												StrcpyS(scCount, 16, argv[iszArg++]);
  												fCount = true;
  								}
  
  								/* Check for the -b paramater used to specify the
  								 ** value of a single data byte to be written to the register
  								 */
  								else if (strcmp(argv[iszArg], "-b") == 0) {
  												iszArg += 1;
  												if (iszArg >= argc) {
  																return false;
  												}
  												StrcpyS(scByte, 16, argv[iszArg++]);
  												fByte = true;
  								}
  
  								/* Not a recognized parameter
  								 */
  								else {
  												return false;
  								}
  				} // End while
  
  				/* Input combination validity checks
  				 */
  				if( fPutReg && !fByte ) {
  								printf("Error: No byte value provided\n");
  								return false;
  				}
  				if( (fToFile ) && !fFile ) {
  								printf("Error: No filename provided\n");
  								return false;
  				}
  
  				return true;
  }
  return true;
}


void show_usage(char *progname) {
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
    printf("\t-x\t\t\t\tSpecify .xsvf file to load into FPGA\n");
    //  printf("\t-r\t\t\t\tGet a single register value\n");
    //  printf("\t-p\t\t\t\tPut a value into a single register\n");
    printf("\t-a\t\t\t\tGet all registers status\n");
    printf("\t-s\t\t\t\tSet registers\n");
    printf("\t-f\t\t\t\tStart DAQ and save data to file\n");
    printf("\t-o\t\t\t\tStart DAQ and send data to stdout\n");
    printf("\t-g\t\t\t\tGet GPS data\n");
    printf("\t-t\t\t\t\tGet Pressure and Temperature data\n");
    printf("\t-v\t\t\t\tShow DAQ version\n");
    
    
    printf("\n\tRegisters:\n");
    printf("\tt1, t2, t3\t\t\tSpecify triggers 1, 2 and 3\n");
    //printf("\tst1, st2, st3\t\t\tSpecify subtriggers 1, 2 and 3\n");
    printf("\thv1, hv2, hv3\t\t\tSpecify high voltages ...\n");
    printf("\ttm\t\t\t\tSpecify Time Mode for GPS Receiver (0 - UTC, 1 - GPS)\n");
    
    printf("\n\tOptions:\n");
    printf("\t-f <filename>\t\t\tSpecify file name\n");
    printf("\t-c <# bytes>\t\t\tNumber of bytes to read/write\n");
    printf("\t-b <byte>\t\t\tValue to load into register\n");
    
    printf("\n\n");
  }
}

void error_exit() {
  if( hif != 0 ) {
    flClose(handle);
  }
  
  if( fhin != NULL ) {
    fclose(fhin);
  }
  
  if( fhout != NULL ) {
  	fclose(fhout);
  }
  
  exit(1);
  }

void StrcpyS(char *szDst, size_t cchDst, const char *szSrc) {

#if defined (WIN32)

				strcpy_s(szDst, cchDst, szSrc);

#else

				if ( 0 < cchDst ) {

								strncpy(szDst, szSrc, cchDst - 1);
								szDst[cchDst - 1] = '\0';
				}

#endif
}


void handler(int ) {
				// Got a sigalarm, everything is bad, bailing out
				fprintf(fhout,"# E @@@\n");
				fprintf(fhout,"# E 1 - Spend 2 seconds without answer from USB at %ld, resetting\n",fileTime);
				exit(1); // not closing anything on purpose
}

/************************************************************************/
