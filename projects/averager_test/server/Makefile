#CFLAGS = -O3 -march=armv7-a -mtune=cortex-a9 -mfpu=neon -mfloat-abi=hard -D_GNU_SOURCE
CFLAGS =-O3 -march=armv7-a -mtune=cortex-a9 -mfpu=neon -mfloat-abi=hard -D_GNU_SOURCE

all: avg-test-server lowtest

lowtest: lowtest.c
	arm-linux-gnueabihf-gcc $(CFLAGS) -o $@ $^ -lm -lpthread

avg-test-server: avg-test-server.c
	arm-linux-gnueabihf-gcc $(CFLAGS) -o $@ $^ -lm -lpthread

clean:
	rm -f avg-test-server lowtest 

