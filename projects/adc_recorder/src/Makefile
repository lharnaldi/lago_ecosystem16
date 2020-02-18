CC=gcc
FLAGS=-Wall -O3
ARCH=arm
CROSS_COMPILE=arm-xilinx-linux-gnueabi-

####
PROG=counter_test
EXTRA=

all: $(PROG)

$(PROG): $(PROG).c $(EXTRA) 
	$(CC) $(FLAGS) -o $(PROG) $(PROG).c $(EXTRA) -lm -lpthread

clean:
	rm -f $(PROG)
