CC=gcc
FLAGS=-Wall -O3
ARCH=arm
CROSS_COMPILE=arm-xilinx-linux-gnueabi-

####
PROG=lago
EXTRA=uart_rp.c nmea_rp.c gps_rp.c zynq_io.c bmp180.c

all: $(PROG)

$(PROG): $(PROG).c $(EXTRA) 
	$(CC) $(FLAGS) -o $(PROG) $(PROG).c $(EXTRA) -lm -lpthread

clean:
	rm -f $(PROG)
