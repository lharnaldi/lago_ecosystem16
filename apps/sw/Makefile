INCLUDES= -I. -I/opt/Xilinx/SDK/2016.2/data/embeddedsw/XilinxProcessorIPLib/drivers/axidma_v8_1/src/ -I/opt/Xilinx/SDK/2015.4/data/embeddedsw/XilinxProcessorIPLib/drivers/gpio_v3_01_a/src/
helloworld: adc.o dac.o dma_passthrough.o
	gcc -o myprogram adc.o dac.o dma_passthrough.o

adc.o: adc.c adc.h
	gcc -c adc.c

dac.o: dac.c dac.h
	gcc -c dac.c

dma_passthrough.o: dma_passthrough.c dma_passthrough.h
	gcc -c dma_passthrough.c $(INCLUDES)
