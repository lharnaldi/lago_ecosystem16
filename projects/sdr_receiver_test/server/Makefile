CC=arm-linux-gnueabihf-gcc
CFLAGS =-O3 -march=armv7-a -mtune=cortex-a9 -mfpu=neon -mfloat-abi=hard -lm
#arm-linux-gnueabihf-gcc -static -O3 -march=armv7-a -mtune=cortex-a9 -mfpu=neon -mfloat-abi=hard sdr-receiver-test.c -o sdr-receiver-test -lm -lpthread
all: sdr-receiver-test

sdr-transceiver: sdr-receiver-test.c
	$(CC) $(CFLAGS) -o $@ $^ -lpthread

clean:
	rm -f sdr-receiver-test

