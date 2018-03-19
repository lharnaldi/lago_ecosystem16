#ifndef _UART_RP_H_
#define _UART_RP_H_

#include <inttypes.h>

//Default name for UART port in E2 expansion conector
#ifndef PORTNAME
#define PORTNAME "/dev/ttyPS1"
#endif

int rp_UartInit(void);
void rp_UartConfig(void);
int rp_UartPrintln(const char *, int);
int rp_UartReadln(char *, int);
void rp_UartClose(void);

#endif
