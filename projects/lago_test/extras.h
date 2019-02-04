/************************************************************************/
/*                                    									*/
/*  lago.h									               				*/
/*                                    									*/
/************************************************************************/
/*  Author: Horacio Arnaldi                      						*/
/*  e-mail: lharnaldi@gmail.com                     					*/
/*                                   									*/
/************************************************************************/
/*  Module Description:                         						*/
/*    To transfer data to and from a Digilent Nexys2 board      		*/
/*                                    									*/
/************************************************************************/
/*

Copyright 2012 - Lab DPR (CAB-CNEA). All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

   1. Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY LAB DPR ''AS IS'' AND ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
NO EVENT SHALL LAB DPR OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are
those of the authors and should not be interpreted as representing
official policies, either expressed or implied, of Lab DPR.

*/
/************************************************************************/

#ifndef LAGO_H
#define LAGO_H

#define FAIL(failCode) \
	returnCode = failCode; \
	goto cleanup

#define GET_ARG(argName, var, failCode)					\
	argv++; \
	argc--; \
	if ( !argc ) { requires(prog, argName); FAIL(failCode); }	\
	var = *argv

/* ------------------------------------------------------------ */
/*  Forward Declarations   						                */
/* ------------------------------------------------------------ */

int  FParseParamSync(int cszArg, char * rgszArg[]);
void ShowUsageSync(char * sz);
void ErrorExitSync();

void DoPutRegSync();
void DoGetRegSync();
void DoPutRegSetSync();
void DoGetRegSetSync();
int  DoReadBufferSync(int wr=1, int clean=0);
void DoGetGPSnFifoSync();
void DoGetPandTnFifoSync();
void CalculatePressTemp(int run=0);
long CalculateAltitude(float Press);
long Get2_x(unsigned char i);

void StrcpyS( char* szDst, size_t cchDst, const char* szSrc );

void suggest(const char *prog);
void requires(const char *prog, const char *arg);
void requirespar(const char *prog, const char *arg);
void requiresval(const char *prog, const char *arg);
void missing(const char *prog, const char *arg);
void missingval(const char *prog);
void invalid(const char *prog, char arg);
void unexpected(const char *prog, const char *arg);
void usage(const char *prog);

#endif
