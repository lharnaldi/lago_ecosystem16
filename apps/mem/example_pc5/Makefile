APP = pc5

#CROSS=arm-linux-
CROSS=arm-xilinx-linux-gnueabi-
ARCH=arm

LIBS = 

INCLUDE = .

CC = $(CROSS)gcc

CFLAGS = -DLINUX -mcpu=arm920t -mtune=arm920t -msoft-float -O2
LDFLAGS = -Wl -lc

SRC := $(APP).c
OBJ := $(APP).o

.c.o:
	$(CC) $(CFLAGS) -I$(INCLUDE) -c -o $@ $<

all: $(APP)

$(APP):	$(OBJ)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS) $(LIBS)
	$(CROSS)strip $@

clean:
	rm -f *.o *.gdb $(APP)
