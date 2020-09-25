CC=gcc
CFLAGS =-Wall -O3 

all: adc-test-client_lnx

sdr-transceiver: adc-test-client_lnx.c
	$(CC) $(CFLAGS) -o $@ $^ -lm -lpthread

clean:
	rm -f adc-test-client_lnx

