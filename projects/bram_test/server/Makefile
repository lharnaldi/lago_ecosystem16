CC=arm-linux-gnueabihf-gcc
CFLAGS =-O3 -march=armv7-a -mtune=cortex-a9 -mfpu=neon -mfloat-abi=hard -lm
#arm-linux-gnueabihf-gcc -static -O3 -march=armv7-a -mtune=cortex-a9 -mfpu=neon -mfloat-abi=hard sdr-receiver-test.c -o sdr-receiver-test -lm -lpthread
all: bram-test-server

sdr-transceiver: bram-test-server.c
	$(CC) $(CFLAGS) -o $@ $^ -lpthread

clean:
	rm -f bram-test-server

