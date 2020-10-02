#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/mman.h>
 
void *thread_isr(void *p)
{
    char buf[100];
    int fd;
    int a=0;
		char *gpioint = "/dev/gpioint";

    fd=open(gpioint,O_RDONLY);
		if (fd < 1) {
                printf("Invalid GPIO device file:%s.\n", gpioint);
                return -1;
        }

 
    do
    {
        a++;
        read(fd,buf,1);
 
        printf("Interrupt handler\n");
    }while(a<10);
 
    close(fd);
}
 
int main()
{
    int i;
    pthread_t t1;
    puts("start");
    pthread_create(&t1,NULL,thread_isr,NULL);
    for(i=0;i<100;i++) {
      printf("Waiting for an int ...\n");
      usleep(1000000);
    }
    sleep(10);
    return 1;
}

