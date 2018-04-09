#ifndef _NMEA_RP_H_
#define _NMEA_RP_H_

#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <string.h>
#include <math.h>

#define _EMPTY 0x00
#define NMEA_GPRMC 0x01
#define NMEA_GPRMC_STR "$GPRMC"
#define NMEA_GPGGA 0x02
#define NMEA_GPGGA_STR "$GPGGA"
#define NMEA_UNKNOWN 0x00
#define _COMPLETED 0x03

#define NMEA_CHECKSUM_ERR 0x80
#define NMEA_MESSAGE_ERR 0xC0

typedef struct gpgga {
    double times;
    double latitude;
    char lat;
    double longitude;
    char lon;
    uint8_t quality;
    uint8_t satellites;
    double altitude;
} gpgga_t;

typedef struct gprmc {
    double times;
    double latitude;
    char lat;
    double longitude;
    char lon;
    double speed;
    double course;
    double date;
} gprmc_t;

uint8_t rp_NmeaGetMessageType(const char *);
void rp_NmeaParseGpgga(char *, gpgga_t *);
void rp_NmeaParseGprmc(char *, gprmc_t *);

#endif

