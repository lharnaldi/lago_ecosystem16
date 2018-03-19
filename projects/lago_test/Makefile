CC=g++
FLAGS=-Wall -O3

####
PROG=lago
EXTRA=nmea_rp.c uart_rp.c gps_rp.c bmp180.c

all: $(PROG)

$(PROG): $(PROG).c $(EXTRA) 
	$(CC) $(FLAGS) -o $(PROG) $(PROG).c $(EXTRA) -lm 

clean:
	rm -f $(PROG)
