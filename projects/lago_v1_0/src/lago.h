#ifndef _MAIN_H_
#define _MAIN_H_

#include <poll.h>
#include <signal.h>
#include <string.h>
#include <time.h>
//#include <fstream>
//#include <iostream>
//#include <vector>

#define _GNU_SOURCE
#include <pthread.h>

#include "zynq_io.h"
#include "gps_rp.h"
#include "bmp180.h"
#include "globaldefs.h"

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

int  main(int argc, char *argv[]);
void signal_handler(int sig);
int  wait_for_interrupt(int fd_int, void *dev_ptr);
void *thread_isr_not_gps(void *p);
void *thread_isr(void *p);  
void show_usage(char *progname);
void StrcpyS(char *szDst, size_t cchDst, const char *szSrc); 
int  parse_param(int argc, char *argv[]);  
int  new_file(void);
int  read_buffer(int position, void *bmp);

#endif
