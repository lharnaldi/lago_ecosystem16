CC=gcc
CFLAGS =-Wall -O3

all: sdr-receiver-client-le16 bram-test-client

sdr-receiver-client-le16: sdr-receiver-client-le16.c
	$(CC) $(CFLAGS) -o $@ $^ -lm -lpthread

bram-test-client: bram-test-client.c
	$(CC) $(CFLAGS) -o $@ $^ -lm -lpthread

clean:
	rm -f sdr-receiver-client-le16 bram-test-client

