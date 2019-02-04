#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>

int main()
{
  int fd, i;
  uint32_t wo;
  int16_t ch[2];
  void *cfg, *ram;
  char *name = "/dev/mem";
  int32_t mtd_dp = 0, mtd_cdp = 0, mtd_pulse_cnt = 0, mtd_pulse_pnt = 0;

  if((fd = open(name, O_RDWR)) < 0)
  {
    perror("open");
    return 1;
  }

  cfg = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40000000);
  ram = mmap(NULL, 1024*sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x1E000000);

  // set trigger_lvl_a
  *((uint32_t *)(cfg + 8)) = 300;

  // set trigger_lvl_b
  *((uint32_t *)(cfg + 10)) = 8190;

  // set subtrigger_lvl_a
  *((uint32_t *)(cfg + 12)) = 8190;

  // set subtrigger_lvl_b
  *((uint32_t *)(cfg + 14)) = 8190;

  // reset writer
  *((uint32_t *)(cfg + 0)) &= ~4;
  *((uint32_t *)(cfg + 0)) |= 4;

  // reset fifo 
  *((uint32_t *)(cfg + 0)) &= ~1;
  *((uint32_t *)(cfg + 0)) |= 1;

  // wait 1 second
  sleep(1);

  // enter reset mode for tlast_gen
  *((uint32_t *)(cfg + 0)) &= ~2;

  // set number of samples
  *((uint32_t *)(cfg + 4)) = 1024 * 1024 - 1;

  // enter normal mode
  *((uint32_t *)(cfg + 0)) |= 2;

  // wait 1 second
  sleep(1);

  // print IN1 and IN2 samples
//  for(i = 0; i < 1024 * 1024; ++i)
//  {
//    ch[0] = *((int16_t *)(ram + 4*i + 0));
//    ch[1] = *((int16_t *)(ram + 4*i + 2));
//    printf("%5d %5d\n", ch[0], ch[1]);
//  }

  for(i = 0; i < 1024 * 1024; ++i)
  {
    ch[0] = *((int16_t *)(ram + 4*i + 0));
    ch[1] = *((int16_t *)(ram + 4*i + 2));
    wo = *((uint32_t *)(ram + 4*i));
    switch(wo>>30){
     case 0: 
      printf("%5hd %5hd\n", (((ch[0]>>13)<<14) + ((ch[0]>>13)<<15) + ch[0]), (((ch[1]>>13)<<14) + ((ch[1]>>13)<<15) + ch[1]));
      //printf("# p %5d\n", wo);
      break;
     case 1:
      printf("# t %d %d\n", (wo>>27)&0x7, wo&0x7FFFFFF);
      break;
     case 2:
      mtd_pulse_pnt = mtd_pulse_cnt;
      mtd_pulse_cnt = (wo&0x3FFFFFFF);
      mtd_dp = (mtd_pulse_cnt - mtd_pulse_pnt - 1);
      if (mtd_dp > 0 && mtd_pulse_pnt)
        mtd_cdp += mtd_dp;
      printf("# c %d\n", mtd_pulse_cnt);
      break;
     default:
      printf("# E @@@\n");
      printf("# E 3 - unknown word from FPGA: %d %x\n",wo>>27,wo>>27);
      break;
     } 
     } 
          
//    if (wo>>30==0) {
//      printf("%5d %5d\n", ch[0]&0x3FFF, ch[1]&0x3FFF);
//      //printf("# p %5d %5d\n", ch[0], ch[1]);
//    }else{
//      if (wo>>30==1) {
//        printf("# t %d %d\n", (wo>>27)&0x7, wo&0x7FFFFFF);
//        }else{ 
//          if (wo>>30==2) {
//            printf("# c %ld\n", mtd_pulse_cnt);
//            } 
//      printf("# p %5d\n", wo);
//else {
//          switch(wo>>27) {
//            case 0x18:
//              printf("# x f         %d \n", wo&0x03FFFFFF);
//              break;
//            case 0x19:
//              printf("# x r D2         %d \n", wo&0x0000FFFF);
//              break;
//            case 0x1A:
//              printf("# x r D1         %d \n", wo&0x0000FFFF);
//              break;
//            case 0x1B:
//              break;
//            case 0x1C: // Longitude, latitude, defined by other bits
//              printf("# E latitude\n");
//              break;
//            case 0x1F: // note : not used in LAGO, was used in MIDAS... Legacy
//              printf("# E midas\n");
//              printf("%5d %5d\n", ch[0], ch[1]);
//              break;
//            case 0x1E: // note : not used in LAGO, was used in MIDAS... Legacy
//              printf("# E midas2\n");
//              break;
//            default:
//              printf("# E @@@\n");
//              printf("# E 3 - unknown word from FPGA: %d %x\n",wo>>27,wo>>27);
//              break;
//          }
//        }
//      }
//      }
//  }

  munmap(cfg, sysconf(_SC_PAGESIZE));
  munmap(ram, sysconf(_SC_PAGESIZE));

  return 0;
}
