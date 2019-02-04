#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>

#define VERSION "0.1"
int main(int argc, char *argv[])
{
  int mfd, i;
  uint32_t wo;
  int16_t ch[2];
  void *cfg, *ram;
  char *name = "/dev/mem";
  int32_t mtd_dp = 0, mtd_cdp = 0, mtd_pulse_cnt = 0, mtd_pulse_pnt = 0;

  printf("%d\n",argc);

  if (argc<1) {
    printf("%s version %s\n",argv[0],VERSION);
    printf("The clock freq. is 143MHz and the PWM signal freq. is 1.06 Hz (T aprox. 0.93s)\n");
    printf("Syntax: %s [pwm value](from 0 to 2**27-1)\n  ex: %s 10000 \n", argv[0]);
    printf("for ~ 70 us PWM signal in state '1' and the rest in state \n");
    printf("'0' up to ~0.94s)\n");
    exit(EXIT_FAILURE);
  }

  if((mfd = open(name, O_RDWR)) < 0)
  {
    perror("open");
    return 1;
  }

  cfg = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, mfd, 0x40000000);

  // reset pwm_gen
  *((uint32_t *)(cfg + 0)) &= ~1;
  *((uint32_t *)(cfg + 0)) |= 1;


  // set trigger_lvl_a
  *((uint32_t *)(cfg + 4)) = atoi(argv[1]);
  *((uint32_t *)(cfg + 4)) = atoi(argv[1]);
  *((uint32_t *)(cfg + 4)) = atoi(argv[1]);
  *((uint32_t *)(cfg + 4)) = atoi(argv[1]);


  // print IN1 and IN2 samples
//  for(i = 0; i < 64; ++i)
//  {
//    ch[0] = *((int16_t *)(cfg + i));
//    //ch[1] = *((int16_t *)(ram + 4*i + 2));
//    printf("%5d \n", (ch[0]>>4));
//  }


  munmap(cfg, sysconf(_SC_PAGESIZE));

  return 0;
}
