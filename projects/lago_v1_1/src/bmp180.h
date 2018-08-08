#ifndef __BMP180__
#define __BMP180__

#include <string.h> 
#include <stdlib.h> 
#include <fcntl.h> 
#include <linux/i2c-dev.h> 
#include <math.h> 
#include<unistd.h>
#include<inttypes.h>

#define BMP180_PRE_OSS0 0 // ultra low power
#define BMP180_PRE_OSS1 1 // standard
#define BMP180_PRE_OSS2 2 // high resolution
#define BMP180_PRE_OSS3 3 // ultra high resoultion

/* AC register */
#define BMP180_REG_AC1_H 0xAA
#define BMP180_REG_AC2_H 0xAC
#define BMP180_REG_AC3_H 0xAE
#define BMP180_REG_AC4_H 0xB0
#define BMP180_REG_AC5_H 0xB2
#define BMP180_REG_AC6_H 0xB4

/* B1 register */
#define BMP180_REG_B1_H 0xB6

/* B2 register */
#define BMP180_REG_B2_H 0xB8

/* MB register */
#define BMP180_REG_MB_H 0xBA

/* MC register */
#define BMP180_REG_MC_H 0xBC

/* MD register */
#define BMP180_REG_MD_H 0xBE

/* AC register */
#define BMP180_CTRL 0xF4

/* Temperature register */
#define BMP180_REG_TMP 0xF6

/* Pressure register */
#define BMP180_REG_PRE 0xF6

/* Temperature read command */
#define BMP180_TMP_READ_CMD 0x2E

/* Waiting time in us for reading temperature values */
#define BMP180_TMP_READ_WAIT_US 5000

/* Pressure oversampling modes */
#define BMP180_PRE_OSS0 0 // ultra low power
#define BMP180_PRE_OSS1 1 // standard
#define BMP180_PRE_OSS2 2 // high resolution
#define BMP180_PRE_OSS3 3 // ultra high resoultion

/* Pressure read commands */
#define BMP180_PRE_OSS0_CMD 0x34
#define BMP180_PRE_OSS1_CMD 0x74
#define BMP180_PRE_OSS2_CMD 0xB4
#define BMP180_PRE_OSS3_CMD 0xF4

/* Waiting times in us for reading pressure values */
#define BMP180_PRE_OSS0_WAIT_US 5000
#define BMP180_PRE_OSS1_WAIT_US 8000
#define BMP180_PRE_OSS2_WAIT_US 14000
#define BMP180_PRE_OSS3_WAIT_US 26000

/* Average sea-level pressure in hPa */
#define BMP180_SEA_LEVEL 1013.25

/* Define debug function. */
//#define __BMP180_DEBUG__
#ifdef __BMP180_DEBUG__
#define DEBUG(...)  printf(__VA_ARGS__)
#else
#define DEBUG(...)
#endif

/* Shortcut to cast void pointer to a bmp180_t pointer */
#define TO_BMP(x) (bmp180_t*) x

/* Basic structure for the bmp180 sensor */
typedef struct {
				/* file descriptor */
				int file;
				/* i2c device address */
				int address;
				/* BMP180 oversampling mode */
				int oss;
				/* i2c device file path */
				char *i2c_device;
				/* Eprom values */
				int32_t ac1;
				int32_t ac2;
				int32_t ac3;
				int32_t ac4;
				int32_t ac5;
				int32_t ac6;
				int32_t b1;
				int32_t b2;
				int32_t mb;
				int32_t mc;
				int32_t md;
} bmp180_t;


/* Lookup table for BMP180 register addresses */
extern int32_t bmp180_register_table[11][2];

typedef struct {
				/* Eprom values */
				int ac1;
				int ac2;
				int ac3;
				int ac4;
				int ac5;
				int ac6;
				int b1;
				int b2;
				int mb;
				int mc;
				int md;
} bmp180_eprom_t;

/* Prototypes for helper functions */
void bmp180_read_eprom(void *_bmp);
void *bmp180_init(int address, const char* i2c_device_filepath);
void bmp180_close(void *_bmp);
void bmp180_set_oss(void *_bmp, int oss);
float bmp180_pressure(void *_bmp);
float bmp180_temperature(void *_bmp);
float bmp180_altitude(void *_bmp);
void bmp180_dump_eprom(void *_bmp, bmp180_eprom_t *eprom);

#endif
