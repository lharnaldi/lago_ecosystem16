#ifndef _GPS_RP_H_
#define _GPS_RP_H_

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#include "nmea_rp.h"
#include "uart_rp.h"

typedef struct location {
    double times;
    double date;
    double latitude;
    double longitude;
    double speed;
    double altitude;
    double course;
    double satellites;
} loc_t;

void gps_init(void);
void gps_on(void);
void gps_location(loc_t *);
void gps_off(void);
int  gps_print_data(void);

#endif
