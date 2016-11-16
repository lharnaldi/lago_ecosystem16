int FParseParamSync(int cszArg, char * rgszArg[]) {

	int    iszArg;

	/* Initialize default flag values */
	fGetReg    = false;
	fPutReg    = false;
	fGetRegSet = false;
	fPutRegSet = false;
	fToFile    = false;
	fToStdout  = false;
	fGetPT     = false;
	fGetGPS    = false;
	fFile      = false;
	fCount     = false;
	fByte      = false;
	fData      = false;
	fXsvfFile  = false;
	fScanJTAG  = false;

	/* Ensure sufficient paramaters. Need at least program name and
	 ** action flag
	 */
	if (cszArg < 2) {
		return false;
	}

	/* The first parameter is the action to perform. Copy the
	 ** first parameter into the action string.
	 */
	StrcpyS(scAction, MAXCHRLEN, rgszArg[1]);

	if(strcmp(scAction, "-r") == 0) {
		fGetReg = true;
	} else if( strcmp(scAction, "-p") == 0) {
		fPutReg = true;
	} else if( strcmp(scAction, "-a") == 0) {
		fGetRegSet = true;
		return true;
	} else if( strcmp(scAction, "-v") == 0) {
		fShowVersion = true;
		return false;
	} else if( strcmp(scAction, "-s") == 0) {
		fPutRegSet = true;
	} else if( strcmp(scAction, "-f") == 0) {
		fToFile = true;
	} else if( strcmp(scAction, "-o") == 0) {
		fToStdout = true;
		return true;
	} else if( strcmp(scAction, "-t") == 0) {
		fGetPT = true;
		return true;
	} else if( strcmp(scAction, "-g") == 0) {
		fGetGPS = true;
		return true;
	} else if( strcmp(scAction, "-x") == 0) {
		fXsvfFile = true;
	} else if( strcmp(scAction, "-j") == 0) {
		fScanJTAG = true;
		return true;
	} else { // unrecognized action
		return false;
	}

	/* Second paramater is target register on device. Copy second
	 ** paramater to the register string */

	if (fPutRegSet) {
		StrcpyS(scReg, MAXCHRLEN, rgszArg[2]);
		/*Registers for Triggers*/
		if(strcmp(scReg, "t1") == 0) {
			scRegister[0] = '1'; /* registers 1 and 2 are for trigger 1*/
		} else if(strcmp(scReg, "t2") == 0) {
			scRegister[0] = '3'; /* registers 3 and 4 are for trigger 2*/
		} else if(strcmp(scReg, "t3") == 0) {
			scRegister[0] = '5'; /* registers 5 and 6 are for trigger 3*/
		}
		/*Registers for Subtrigger*/
		else if(strcmp(scReg, "st1") == 0) {
			scRegister[0] = '7'; /* registers 7 and 8 are for scaler 1*/
		} else if(strcmp(scReg, "st2") == 0) {
			scRegister[0] = '9'; /* registers 9 and 10 are for scaler 2a*/
		} else if(strcmp(scReg, "st3") == 0) {
			scRegister[0] = '1'; /* registers 11 and 12 are for scaler 3a*/
			scRegister[1] = '1';
		}
		/*Registers for High Voltage*/
		else if(strcmp(scReg, "hv1") == 0) {
			scRegister[0] = '1'; /* registers 13 and 14 are for DAC 4 aka hv1*/
			scRegister[1] = '3';
		} else if(strcmp(scReg, "hv2") == 0) {
			scRegister[0] = '1'; /* registers 15 and 16 are for PWM 1*/
			scRegister[1] = '5';
		} else if(strcmp(scReg, "hv3") == 0) {
			scRegister[0] = '1'; /* registers 17 and 18 are for PWM 2*/
			scRegister[1] = '7';
		} else if(strcmp(scReg, "tm") == 0) {
			scRegister[0] = '1'; /* register 19 are for Time Mode*/
			scRegister[1] = '9';
		}
		/*Unrecognized */
		else { // unrecognized register to set
			return false;
		}
		//scCount[0] = '4';
		//fCount = true;
		StrcpyS(scData, 16, rgszArg[3]);
		if((strncmp(scReg, "hv",2) == 0)) {
			if (atoi(scData)>4000) {
				printf ("Error: maximum voltage 4000\n");
				exit(1);
			}
		}
		fData = true;
	} else if(fToFile) {
		if(rgszArg[2] != NULL) {
			StrcpyS(scFile, MAXFILENAMELEN, rgszArg[2]);
			fFile = true;
		} else {
			return false;
		}
	} else if(fXsvfFile) {
		if(rgszArg[2] != NULL) {
			StrcpyS(scFile, 127, rgszArg[2]);
		} else {
			return false;
		}
	} else {
		StrcpyS(scRegister, MAXCHRLEN, rgszArg[2]);

		/* Parse the command line parameters.
		 */
		iszArg = 3;
		while(iszArg < cszArg) {

			/* Check for the -f parameter used to specify the
			 ** input/output file name.
			 */
			if (strcmp(rgszArg[iszArg], "-f") == 0) {
				iszArg += 1;
				if (iszArg >= cszArg) {
					return false;
				}
				StrcpyS(scFile, 16, rgszArg[iszArg++]);
				fFile = true;
			}
			/* Check for the -c parameter used to specify the
			 ** number of bytes to read/write from file.
			 */
			else if (strcmp(rgszArg[iszArg], "-c") == 0) {
				iszArg += 1;
				if (iszArg >= cszArg) {
					return false;
				}
				StrcpyS(scCount, 16, rgszArg[iszArg++]);
				fCount = true;
			}

			/* Check for the -b paramater used to specify the
			 ** value of a single data byte to be written to the register
			 */
			else if (strcmp(rgszArg[iszArg], "-b") == 0) {
				iszArg += 1;
				if (iszArg >= cszArg) {
					return false;
				}
				StrcpyS(scByte, 16, rgszArg[iszArg++]);
				fByte = true;
			}

			/* Not a recognized parameter
			 */
			else {
				return false;
			}
		} // End while

		/* Input combination validity checks
		 */
		if( fPutReg && !fByte ) {
			printf("Error: No byte value provided\n");
			return false;
		}
		if( (fToFile ) && !fFile ) {
			printf("Error: No filename provided\n");
			return false;
		}

		return true;
	}
	return true;
}

void show_usage(char *szProgName) {
	if (fShowVersion) {
		printf("LAGO ACQUA BRC v%dr%d data v%d\n",VERSION,REVISION,DATAVERSION);
	} else {
		printf("\n\tThe LAGO ACQUA suite\n");
		printf("\tData acquisition system for the LAGO BRC electronic\n");
		printf("\t(c) 2012-Today, The LAGO Project, http://lagoproject.org\n");
		printf("\t(c) 2012, LabDPR, http://labdpr.cab.cnea.gov.ar\n");
		printf("\n\tThe LAGO Project, lago@lagoproject.org\n");
		printf("\n\tDPR Lab. 2012\n");
		printf("\tH. Arnaldi, lharnaldi@gmail.com - H. Asorey, asoreyh@gmail.com\n");
		printf("\t%s v%dr%d comms soft\n\n",EXP,VERSION,REVISION);
		printf("Usage: %s <action> <register> <value> [options]\n", szProgName);

		printf("\n\tActions:\n");
		printf("\t-x\t\t\t\tSpecify .xsvf file to load into FPGA\n");
		//  printf("\t-r\t\t\t\tGet a single register value\n");
		//  printf("\t-p\t\t\t\tPut a value into a single register\n");
		printf("\t-a\t\t\t\tGet all registers status\n");
		printf("\t-s\t\t\t\tSet registers\n");
		printf("\t-f\t\t\t\tStart DAQ and save data to file\n");
		printf("\t-o\t\t\t\tStart DAQ and send data to stdout\n");
		printf("\t-g\t\t\t\tGet GPS data\n");
		printf("\t-t\t\t\t\tGet Pressure and Temperature data\n");
		printf("\t-v\t\t\t\tShow DAQ version\n");


		printf("\n\tRegisters:\n");
		printf("\tt1, t2, t3\t\t\tSpecify triggers 1, 2 and 3\n");
		//printf("\tst1, st2, st3\t\t\tSpecify subtriggers 1, 2 and 3\n");
		printf("\thv1, hv2, hv3\t\t\tSpecify high voltages ...\n");
		printf("\ttm\t\t\t\tSpecify Time Mode for GPS Receiver (0 - UTC, 1 - GPS)\n");

		printf("\n\tOptions:\n");
		printf("\t-f <filename>\t\t\tSpecify file name\n");
		printf("\t-c <# bytes>\t\t\tNumber of bytes to read/write\n");
		printf("\t-b <byte>\t\t\tValue to load into register\n");

		printf("\n\n");
	}
}

