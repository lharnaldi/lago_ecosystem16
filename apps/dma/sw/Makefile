IDIR =../../../tmp/dma_loopback.fsbl/zynq_fsbl_bsp/ps7_cortexa9_0/include
CC=arm-linux-gnueabi-gcc
CFLAGS=-I$(IDIR)

ODIR=obj
LDIR =../../../tmp/dma_loopback.fsbl/zynq_fsbl_bsp/ps7_cortexa9_0/lib

LIBS=-lm

_DEPS = adc.h dac.h dma_passthrough.h 
DEPS = $(patsubst %,$(IDIR)/%,$(_DEPS))

_OBJ = adc.o dac.o dma_passthrough.o 
OBJ = $(patsubst %,$(ODIR)/%,$(_OBJ))


$(ODIR)/%.o: %.c $(DEPS)
	$(CC) -c -o $@ $< $(CFLAGS) -I../../../tmp/dma_loopback.fsbl/zynq_fsbl_bsp/ps7_cortexa9_0/libsrc/axidma_v9_2/src

helloworld: $(OBJ)
	gcc -o $@ $^ $(CFLAGS) $(LIBS) -I../../../tmp/dma_loopback.fsbl/zynq_fsbl_bsp/ps7_cortexa9_0/libsrc/axidma_v9_2/src

.PHONY: clean

clean:
	rm -f $(ODIR)/*.o *~ core $(INCDIR)/*~ 
