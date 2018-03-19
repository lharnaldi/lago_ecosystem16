//Programa que accedera a las posiciones de memoria virtual mapeadas
//para mapearlas posteriormente en DDR
//Despues de esto extraeremos la informacion de dichas posiciones
//para imprimirla por pantalla o almacenarla en base de datos
//o mostrar resultados en algun tipo de aplicacion grafica (Labview o algun
//applet)
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <fcntl.h>
#include <ctype.h>
#include <termios.h>
#include <sys/types.h>
#include <sys/mman.h>

void FATAL (void){
				printf("No se ejecutó correctamente. Revisar\n");
}

#define MAP_SIZE 4096UL
#define MAP_MASK (MAP_SIZE-1)
#define BASE_ADDR 0x1000000
#define TX_BUFFER (BASE_ADDR + 0x001000)
#define RX_BUFFER (BASE_ADDR + 0x003000)
#define AXI_DMA_BASE_ADDR 0x40410000
#define MM2S_DMACR (AXI_DMA_BASE_ADDR + 0x00)  //CR = Control Register
#define MM2S_DMASR (AXI_DMA_BASE_ADDR + 0x04)  //SR = Status Register
#define MM2S_SA (AXI_DMA_BASE_ADDR + 0x18)     //SA = Start Address
#define MM2S_LENGHT (AXI_DMA_BASE_ADDR + 0x28) //Longitud
#define S2MM_DMACR (AXI_DMA_BASE_ADDR + 0x30)  //CR = Control Register
#define S2MM_DMASR (AXI_DMA_BASE_ADDR + 0x34)  //SR = Status Register
#define S2MM_DA (AXI_DMA_BASE_ADDR + 0x48)     //DA = Destination Adress
#define S2MM_LENGHT (AXI_DMA_BASE_ADDR + 0x58) //Longitud

int main(int argc, char * argv []){
				int fd;
				void *map_base, *virt_addr, *map_base_thread,
						 *virt_addr_thread;
				//unsigned long read_result, writeval;
				//off_t target;
				// int access_type
				fd = open("/dev/uio1", O_RDWR | O_SYNC); //Abrimos toda la memoria fisica del Xilinx
				printf("%d",fd);
				if((fd = open("/dev/uio1",O_RDWR | O_SYNC)) == -1 ){
								FATAL();
				}
				printf ("/dev/uio1 opened successfully.\n");
				fflush (stdout);
				//Inicializamos el DMA
				initialize_axi_dma();
				//Cargamos s2mm y mm2s para transferencia
				load_s2mm();
				load_mm2s();
				//Escribimos el dato
				//write_samples();
				read_samples();
				close(fd);
				return 0;
}

void write_samples (void){
				int i = 0, k = 0;
				int fd;
				off_t sample_addr;
				unsigned char * buffer;
				unsigned char * myData;
				void *map_base;
				FILE *file;
				file = fopen("datos.txt","w");
				buffer = malloc (256*1024);
				for(i=0;i<65536*4;i++)
				{
								*(buffer + i) = *(myData + i);
								(file,*(myData + i));
				}
				fclose(file);
				map_base = mmap(NULL, 256*1024, PROT_READ | PROT_WRITE,MAP_SHARED,fd,TX_BUFFER);
				memcpy (map_base,buffer,256*1024);
				// if(file == NULL){
				// printf("Error al abrir archivo\n");
				// }
				// else {
				// fprintf(file,)
				// }
				if (munmap (map_base,MAP_SIZE) == -1){
								FATAL();
				}
				free (buffer);
}

void read_samples (void){
				int i = 0, k = 0;
				int fd;
				void *map_base;
				off_t sample_addr;
				unsigned char * buffer;
				unsigned char * myData_out;
				unsigned long read_result=0;
				buffer = malloc (256*1024);
				map_base = mmap(NULL, 256*1024, PROT_READ | PROT_WRITE,
												MAP_SHARED,fd,RX_BUFFER);
				memcpy (buffer , map_base, 256*1024);
				for (i=0;i<65536*4;i++){
								*(myData_out+i) = *(buffer+i);
				}
				if(munmap(map_base, MAP_SIZE) == -1){
								FATAL();
				}
				free (buffer);
}
void initialize_axi_dma(void){
				off_t sample_addr;
				unsigned long read_result = 0;
				void *map_base;
				int fd;
				unsigned long virt_addr = 0;
				//MM2S_DMASR
				sample_addr = MM2S_DMASR;
				map_base = mmap(0,MAP_SIZE, PROT_READ | PROT_WRITE,
												MAP_SHARED, fd, sample_addr & ~MAP_MASK);
				if (map_base == (void *)-1){
								FATAL();
				}
				virt_addr = *(unsigned long *)map_base + (sample_addr & MAP_MASK);
				*((unsigned long *) virt_addr) |= 0x10001;
				read_result = *((unsigned long *) virt_addr);
				printf("MM2S_DMASR set to: %lx\n",read_result);
				//MM2S_DMACR
				sample_addr = MM2S_DMACR;
				map_base = mmap(0,MAP_SIZE, PROT_READ | PROT_WRITE,
												MAP_SHARED, fd, sample_addr & ~MAP_MASK);
				printf("%lx",map_base);
				if (map_base == (void *) -1){
								FATAL();
				}

				virt_addr = *(unsigned long *)map_base + (sample_addr & MAP_MASK);
				*((unsigned long *) virt_addr) |= 0x10001;
				read_result = *((unsigned long *) virt_addr);
				printf("MM2S_DMACR set to: %lx\n",read_result);
				//MM2S_DMASR
				sample_addr = MM2S_DMASR;
				map_base = mmap(0,MAP_SIZE, PROT_READ | PROT_WRITE,
												MAP_SHARED, fd, sample_addr & ~MAP_MASK);
				if (map_base == (void *)-1){
								FATAL();
				}
				virt_addr = *(unsigned long *) map_base + (sample_addr & MAP_MASK);
				*((unsigned long *) virt_addr) |= 0x10001;
				read_result = *((unsigned long *) virt_addr);
				printf("MM2S_DMASR set to: %lx\n",read_result);
				if(munmap(map_base,MAP_SIZE)== -1) {
								FATAL();
				}
				//S2MM_DMACR
				sample_addr = S2MM_DMACR;
				map_base = mmap (0,MAP_SIZE, PROT_READ | PROT_WRITE,
												MAP_SHARED,fd, sample_addr & ~MAP_MASK);
				if(map_base == (void* ) -1){
								FATAL();
				}
				virt_addr = map_base +(sample_addr & MAP_MASK);
				*((unsigned long*)virt_addr) |= 0x10001;
				read_result = *((unsigned long*)virt_addr);
				printf("S2MM_DMACR set to: %lx\n",read_result);
				if(munmap(map_base,MAP_SIZE) == -1) {
								FATAL();
				}
				//S2MM_DMASR
				sample_addr = S2MM_DMASR;
				map_base = mmap (0,MAP_SIZE, PROT_READ | PROT_WRITE,
												MAP_SHARED,fd, sample_addr & ~MAP_MASK);
				if(map_base == (void* ) -1){
								FATAL();
				}
				virt_addr = *(unsigned long *) map_base +(sample_addr & MAP_MASK);
				*((unsigned long*)virt_addr) |= 0x10001;
				read_result = *((unsigned long*)virt_addr);
				printf("S2MM_DMASR set to: %lx\n",read_result);
				if(munmap(map_base,MAP_SIZE) == -1){
								FATAL();
				}
}
void load_mm2s (void) {
				off_t sample_addr;
				unsigned long read_result = 0;
				void *map_base;
				unsigned long virt_addr = 0;
				int fd;
				//MM2_SA
				sample_addr = MM2S_SA;
				map_base = mmap(0,MAP_SIZE,PROT_READ | PROT_WRITE,
												MAP_SHARED,fd, sample_addr & ~MAP_MASK);
				if(map_base == (void*)-1){
								FATAL();
				}
				virt_addr = *(unsigned long *) map_base + (sample_addr & MAP_MASK);
				*((unsigned long*) virt_addr)= TX_BUFFER;
				read_result = *((unsigned long*) virt_addr);
				printf("MM2S_DA set to: %lx\n",read_result);
				if(munmap (map_base,MAP_SIZE) == -1){
								FATAL();
				}
				//MM2S_LENGHT
				sample_addr = MM2S_LENGHT;
				map_base = mmap(0,MAP_SIZE,PROT_READ | PROT_WRITE,
												MAP_SHARED,fd, sample_addr & ~MAP_MASK);
				if(map_base == (void*)-1){
								FATAL();
				}
				virt_addr = *(unsigned long *) map_base + (sample_addr & MAP_MASK);
				*((unsigned long*) virt_addr)= 0x40000;
				read_result = *((unsigned long*) virt_addr);
				printf("MM2S_LENGHT set to: %lx\n",read_result);
				if(munmap (map_base,MAP_SIZE) == -1) {
								FATAL();
				}
}

void load_s2mm (void){
				off_t sample_addr;
				unsigned long read_result = 0;
				unsigned long virt_addr = 0;
				int fd;
				void *map_base;
				//S2MM_DA
				sample_addr = S2MM_DA;
				map_base = mmap(0, MAP_SIZE, PROT_READ | PROT_WRITE,
												MAP_SHARED, fd, sample_addr & ~MAP_MASK);
				if(map_base == (void*) - 1){
								FATAL();
				}
				virt_addr = *(unsigned long *) map_base + (sample_addr & MAP_MASK);
				*((unsigned long*) virt_addr) = RX_BUFFER;
				read_result = *((unsigned long*)virt_addr);
				printf("S2MM_DA set to: %lx\n",read_result);
				if(munmap(map_base,MAP_SIZE) == -1) {
								FATAL();
				}
				//S2MM_LENGHT
				sample_addr = S2MM_LENGHT;
				map_base = mmap(0,MAP_SIZE,PROT_READ | PROT_WRITE,
												MAP_SHARED, fd, sample_addr & ~MAP_MASK);
				if(map_base == (void*)-1){
								FATAL();
				}
				virt_addr = *(unsigned long *) map_base + (sample_addr & MAP_MASK);
				*((unsigned long*) virt_addr)= 0x40000;
				read_result = *((unsigned long*) virt_addr);
				printf("S2MM_LENGHT set to: %lx\n",read_result);
				if(munmap (map_base,MAP_SIZE) == -1){
								FATAL();
				}
}

