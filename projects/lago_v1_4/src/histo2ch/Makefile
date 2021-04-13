CC=arm-linux-gnueabihf-gcc
CFLAGS =-O3 -march=armv7-a -mtune=cortex-a9 -mfpu=neon -mfloat-abi=hard -lm
#arm-linux-gnueabihf-gcc -static -O3 -march=armv7-a -mtune=cortex-a9 -mfpu=neon -mfloat-abi=hard sdr-receiver-test.c -o sdr-receiver-test -lm -lpthread
all: histo-test-ch1 histo-test-2ch

histo-test-2ch: histo-test-2ch.c
	$(CC) $(CFLAGS) -o $@ $^ -lpthread

histo-test-ch1: histo-test-ch1.c
	$(CC) $(CFLAGS) -o $@ $^ -lpthread

clean:
	rm -f histo-test-ch1 histo-test-2ch

