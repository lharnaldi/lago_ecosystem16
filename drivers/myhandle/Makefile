ARCH=arm
CROSS_COMPILE=arm-xilinx-linux-gnueabi-
KER_DIR=../../tmp/linux-xlnx-xilinx-v2016.4
obj-m+=myhandle.o

MAKEARCH = $(MAKE) ARCH=$(ARCH) CROSS_COMPLIE=$(CROSS_COMPILE)

all:
	$(MAKEARCH) -C $(KER_DIR) M=$(PWD) modules
clean:
	$(MAKEARCH) -C $(KER_DIR) M=$(PWD) clean
