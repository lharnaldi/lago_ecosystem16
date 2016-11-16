ARCH := arm
KER_DIR := /home/arnaldi/work/mercurialrepos/lharnaldi/lago_ecosystem/tmp/linux-xlnx-xilinx-v2016.2/
obj-m += blink.o
all:
	make ARCH=$(ARCH) -C $(KER_DIR) M=$(PWD) modules
clean: 
	make ARCH=$(ARCH) -C $(KER_DIR) M=$(PWD) clean

#MAKEARCH := $(MAKE) ARCH=$(ARCH) CROSS_COMPLIE=$(CROSS_COMPILE)
#all:
#make -C /proj/dsv_xhd/yashug/Zynq_Kernel/linux-xlnx M=$(PWD) modules
#clean:
#$(MAKEARCH) -C /proj/dsv_xhd/yashug/Zynq_Kernel/linux-xlnx M=$(PWD) clean

