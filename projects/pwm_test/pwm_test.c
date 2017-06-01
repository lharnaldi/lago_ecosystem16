//#include <stdio.h>
//#include <stdlib.h>
//#include <unistd.h>
//#include <string.h>
//#include <errno.h>
//#include <signal.h>
//#include <fcntl.h>
//#include <ctype.h>
//#include <termios.h>
//#include <sys/types.h>
//#include <sys/mman.h>
//
//void FATAL (void){
//        printf("No se ejecutó correctamente. Revisar\n");
//}
//
//#define MAP_SIZE 4096UL
//#define MAP_MASK (MAP_SIZE-1)
//#define BASE_ADDR 0x1000000
//#define TX_BUFFER (BASE_ADDR + 0x001000)
//#define RX_BUFFER (BASE_ADDR + 0x003000)
//#define AXI_DMA_BASE_ADDR 0x40001000
//#define TEMPERATURE (AXI_DMA_BASE_ADDR + 0x00)  
//#define VCCINT (AXI_DMA_BASE_ADDR + 0x01)  
//#define VCCAUX (AXI_DMA_BASE_ADDR + 0x02)
//#define VP_VN (AXI_DMA_BASE_ADDR + 0x03) 
//#define S2MM_DMACR (AXI_DMA_BASE_ADDR + 0x30)  //CR = Control Register
//#define S2MM_DMASR (AXI_DMA_BASE_ADDR + 0x34)  //SR = Status Register
//#define S2MM_DA (AXI_DMA_BASE_ADDR + 0x48)     //DA = Destination Adress
//#define S2MM_LENGHT (AXI_DMA_BASE_ADDR + 0x58) //Longitud

//int main(int argc, char * argv []){
//        int fd;
//        void *map_base, *virt_addr, *map_base_thread,
//             *virt_addr_thread;
//        //unsigned long read_result, writeval;
//        //off_t target;
//        // int access_type
//        fd = open("/dev/uio1", O_RDWR | O_SYNC); //Abrimos toda la memoria
//fisica del Xilinx
//        printf("%d",fd);
//        if((fd = open("/dev/uio1",O_RDWR | O_SYNC)) == -1 ){
//                FATAL();
//        }
//        printf ("/dev/uio1 opened successfully.\n");
//        fflush (stdout);
//        //Inicializamos el DMA
//        initialize_axi_dma();

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>

#define VERSION "0.1"
int main(int argc, char *argv[])
{
  FILE *fd=NULL;
  int mfd, i;
  uint32_t wo;
  int16_t ch[2];
  void *cfg, *ram;
  char *name = "/dev/mem";
  int32_t mtd_dp = 0, mtd_cdp = 0, mtd_pulse_cnt = 0, mtd_pulse_pnt = 0;

//  printf("%d\n",argc);

//  if (argc<2) {
//    printf("%s version %s\n",argv[0],VERSION);
//    printf("Syntax: %s [filename] [trig lvl](in ADC value) [n points]\n  ex: %s data.dat 300\n",argv[0],argv[0]);
//    exit(EXIT_FAILURE);
//  }
//
//  if ((fd = fopen(argv[1], "ab")) == NULL){
//    printf("Error al abrir el archivo de destino!\n");
//    exit(EXIT_FAILURE);//1
//  }

  if((mfd = open(name, O_RDWR)) < 0)
  {
    perror("open");
    return 1;
  }

  cfg = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, mfd,0x40001000);
  ram = mmap(NULL, 1024*sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, mfd, 0x1E000000);

  // print IN1 and IN2 samples
  for(i = 0; i < 64; ++i)
  {
    ch[0] = *((int16_t *)(cfg + i));
    //ch[1] = *((int16_t *)(ram + 4*i + 2));
    printf("%5d \n", (ch[0]>>4));
  }


  munmap(cfg, sysconf(_SC_PAGESIZE));
  munmap(ram, sysconf(_SC_PAGESIZE));

  return 0;
}
