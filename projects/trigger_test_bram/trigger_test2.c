#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/mman.h>

#define VERSION "0.1"

int interrupted = 0;

void signal_handler(int sig)
{
  interrupted = 1;
}

int main(int argc, char *argv[])
{
  FILE *fd=NULL;
  int mfd, i;
  uint32_t wo;
  int16_t ch[2];
  int position, limit, offset;
//  volatile uint32_t *slcr;
  void *cfg, *sts, *ram;
  char *name = "/dev/mem";
  int32_t mtd_dp = 0, mtd_cdp = 0, mtd_pulse_cnt = 0, mtd_pulse_pnt = 0;

  printf("%d\n",argc);

  if (argc<2) {
    printf("%s version %s\n",argv[0],VERSION);
    printf("Syntax: %s [filename] [trig lvl](in ADC value) [n points]\n  ex: %s data.dat 300\n",argv[0],argv[0]);
    exit(EXIT_FAILURE);
  }

  if ((fd = fopen(argv[1], "ab")) == NULL){
    printf("Error al abrir el archivo de destino!\n");
    exit(EXIT_FAILURE);//1
  }

  if((mfd = open(name, O_RDWR)) < 0)
  {
    perror("open");
    return 1;
  }

//  slcr = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0xF8000000);
  cfg = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, mfd, 0x40000000);
  sts = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, mfd, 0x40001000);
  ram = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, mfd, 0x40002000);

  /* set FPGA clock to 143 MHz */
//  slcr[2] = 0xDF0D;
//  slcr[92] = (slcr[92] & ~0x03F03F30) | 0x00100700;

  signal(SIGINT, signal_handler);

  limit = 512;

  // set trigger_lvl_a
  *((uint32_t *)(cfg + 8)) = atoi(argv[2]);

  // set trigger_lvl_b
  *((uint32_t *)(cfg + 10)) = 8190;

  // set subtrigger_lvl_a
  *((uint32_t *)(cfg + 12)) = 8190;

  // set subtrigger_lvl_b
  *((uint32_t *)(cfg + 14)) = 8190;

  // reset pps_gen
  *((uint32_t *)(cfg + 0)) &= ~2;
  *((uint32_t *)(cfg + 0)) |= 2;

  /* reset fifos and writer */
  *((uint32_t *)(cfg + 0)) &= ~1;
  *((uint32_t *)(cfg + 0)) |= 1;

  while(!interrupted)
  {
    /* read writer position */
    position = *((uint32_t *)(sts + 0));

    /* print 512 IN1 and IN2 samples if ready, otherwise sleep 1 ms */
    if((limit > 0 && position > limit) || (limit == 0 && position < 512))
    {
      offset = limit > 0 ? 0 : 2048;
      //limit = limit > 0 ? 0 : 512;
      limit = limit > 0 ? position : position - 512;

      //for(i = 0; i < 512; ++i)
      for(i = 0; i < limit; ++i)
      {
        ch[0] = *((int16_t *)(ram + offset + 4*i + 0));
        ch[1] = *((int16_t *)(ram + offset + 4*i + 2));
        //printf("%5d %5d\n", ch[0], ch[1]);
        wo = *((uint32_t *)(ram + 4*i));
        switch(wo>>30){
         case 0:
          fprintf(fd,"%5hd %5hd\n", (((ch[0]>>13)<<14) + ((ch[0]>>13)<<15) + ch[0]),(((ch[1]>>13)<<14) + ((ch[1]>>13)<<15) + ch[1]));
          //printf("# p %5d\n", wo);
          break;
         case 1:
          fprintf(fd,"# t %d %d\n", (wo>>27)&0x7, wo&0x7FFFFFF);
          break;
         case 2:
          mtd_pulse_pnt = mtd_pulse_cnt;
          mtd_pulse_cnt = (wo&0x3FFFFFFF);
          mtd_dp = (mtd_pulse_cnt - mtd_pulse_pnt - 1);
          if (mtd_dp > 0 && mtd_pulse_pnt)
            mtd_cdp += mtd_dp;
          fprintf(fd,"# c %d\n", mtd_pulse_cnt);
    fprintf(fd,"# PPPP:    %d\n",position);
    fprintf(fd,"# LLLL:    %d\n",limit);
          break;
         default:
          printf("# E @@@\n");
          printf("# E 3 - unknown word from FPGA: %d %x\n",wo>>27,wo>>27);
          break;
         }
      }
    }
//    else
//    {
//      printf("#####\n");
//      usleep(10);
//    }
  }

  offset = limit > 0 ? 0 : 2048;
  limit = limit > 0 ? position : position - 512;

  /* print last IN1 and IN2 samples */
  for(i = 0; i < limit; ++i)
  {
    ch[0] = *((int16_t *)(ram + 4*i + 0));
    ch[1] = *((int16_t *)(ram + 4*i + 2));
    printf("%5d %5d\n", ch[0], ch[1]);
  }

  munmap(cfg, sysconf(_SC_PAGESIZE));
  munmap(sts, sysconf(_SC_PAGESIZE));
  munmap(ram, sysconf(_SC_PAGESIZE));

  return 0;
}

