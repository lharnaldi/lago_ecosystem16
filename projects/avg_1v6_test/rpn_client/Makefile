CC=gcc
CFLAGS =-Wall -O3

all: adc-test-client_lnx test-signal-continuity

adc-test-client_lnx: adc-test-client_lnx.c
	$(CC) $(CFLAGS) -o $@ $^ -lm -lpthread

test-signal-continuity: test-signal-continuity.c
	$(CC) $(CFLAGS) -o $@ $^ -lm -lpthread

clean:
	rm -f adc-test-client_lnx test-signal-continuity

