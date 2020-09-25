#CFLAGS = -O3 -march=armv7-a -mtune=cortex-a9 -mfpu=neon -mfloat-abi=hard -D_GNU_SOURCE
CFLAGS =-static -O3 -march=armv7-a -mtune=cortex-a9 -mfpu=neon -mfloat-abi=hard -D_GNU_SOURCE

all: adc-test-server gen

adc-test-server: adc-test-server.c
	arm-linux-gnueabihf-gcc $(CFLAGS) -o $@ $^ -lm -lpthread

gen: gen.c
	arm-linux-gnueabihf-gcc $(CFLAGS) -o $@ $^ -lm -lpthread

clean:
	rm -f adc-test-server gen

