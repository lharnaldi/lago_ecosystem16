CC=gcc
CFLAGS =-Wall -O3

all: sdr-receiver-client-le16 sdr-receiver-client-le32f

sdr-receiver-client-le16: sdr-receiver-client-le16.c
	$(CC) $(CFLAGS) -o $@ $^ -lm -lpthread

sdr-receiver-client-le32f: sdr-receiver-client-le32f.c
	$(CC) $(CFLAGS) -o $@ $^ -lm -lpthread

clean:
	rm -f sdr-receiver-client-le16 sdr-receiver-client-le32f

