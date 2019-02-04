#
## nothing should be modified here
#
CC=arm-linux-gnueabihf-gcc
FLAGS=-Wall -O3

####
PROG=trigger_test
#EXTRA=extras.cpp gps.cpp pressure.cpp
EXTRA=

all: $(PROG)

$(PROG): $(PROG).cc $(EXTRA) 
	  $(CC) $(FLAGS) -o $(PROG) $(PROG).cc $(EXTRA) 

clean:
	   rm -f $(PROG)
