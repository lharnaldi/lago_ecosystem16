#include "gps_rp.h"

static double gps_deg_dec(double deg_point)
{
  double ddeg;
  double sec = modf(deg_point, &ddeg)*60;
  int deg = (int)(ddeg/100);
  int min = (int)(deg_point-(deg*100));

  double absdlat = round(deg * 1000000.);
  double absmlat = round(min * 1000000.);
  double absslat = round(sec * 1000000.);

  return round(absdlat + (absmlat/60) + (absslat/3600)) /1000000;
}

// Convert lat and lon to decimals (from deg)
static void gps_convert_deg_to_dec(double *latitude, char ns,  double *longitude, char we)
{
  double lat = (ns == 'N') ? *latitude : -1 * (*latitude);
  double lon = (we == 'E') ? *longitude : -1 * (*longitude);

  *latitude = gps_deg_dec(lat);
  *longitude = gps_deg_dec(lon);
}

void gps_init(void) 
{
  rp_UartInit();
  rp_UartConfig();
}

void gps_on(void) 
{
}

// Compute the GPS location using decimal scale
void gps_location(loc_t *coord) 
{
  uint8_t status = _EMPTY;
  while(status != _COMPLETED) {
    gpgga_t gpgga;
    gprmc_t gprmc;
    char buffer[256];

    rp_UartReadln(buffer, 256);
    switch (rp_NmeaGetMessageType(buffer)) {
      case NMEA_GPGGA:
        rp_NmeaParseGpgga(buffer, &gpgga);

        gps_convert_deg_to_dec(&(gpgga.latitude), gpgga.lat, &(gpgga.longitude), gpgga.lon);

        coord->times = gpgga.times;
        coord->latitude = gpgga.latitude;
        coord->longitude = gpgga.longitude;
        coord->altitude = gpgga.altitude;
        coord->satellites = gpgga.satellites;

        status |= NMEA_GPGGA;
        break;
      case NMEA_GPRMC:
        rp_NmeaParseGprmc(buffer, &gprmc);

        coord->speed = gprmc.speed;
        coord->course = gprmc.course;
        coord->date = gprmc.date;

        status |= NMEA_GPRMC;
        break;
    }
  }
}

void gps_off(void) 
{
  //Write off
  rp_UartClose();
}

int gps_print_data()
{
        //FIXME: see if this is necessary here
        gps_init();

        loc_t data;

        gps_location(&data);

        printf("Time      : %06d\n",(uint32_t)data.times);
        printf("Date      : %06d\n",(uint32_t)data.date);
        printf("Latitude  : %lf\n", data.latitude);
        printf("Longitude : %lf\n", data.longitude);
        printf("Altitude  : %.1lf\n", data.altitude);
        printf("Satellites: %d\n", (uint32_t)data.satellites);

        return 0;
}
