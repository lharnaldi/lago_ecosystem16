
//////////////////////////////////////////////////////////////////////////////////
//
// Company:        Xilinx
// Engineer:       bwiec
// Create Date:    30 June 2015, 02:37:56 PM
// App Name:       Polled-mode AXI DMA Demonstration
// File Name:      helloworld.c
// Target Devices: Zynq
// Tool Versions:  2015.1
// Description:    Implementation of AXI DMA passthrough
// Dependencies:
//   - xuartps_hw.h - Driver version v3.0
//   - xllfifo.h    - Driver version v4.0
//   - adc.h        - Driver version v1.0
//   - dac.h        - Driver version v1.0
// Revision History:
//   - v1.0
//     * Initial release
//     * Tested on ZC702 and Zedboard
// Additional Comments:
//   - UART baud rate is 115200
//   - In this design, the 'ADC' and 'DAC' devices are simply emulating such
//     hardware (using a GPIO for control). Their purpose is to showcase a
//     middleware driver sitting on top of the dma_passthrough driver. The ADC and
//     DAC drivers will surely need to be re-written for the specific application.
//
//////////////////////////////////////////////////////////////////////////////////
 
// Includes
#include <stdio.h>
#include <stdlib.h>
#include "platform.h"
#include "xuartps_hw.h"
#include "xllfifo.h"
#include "xil_cache.h"
#include "adc.h"
#include "dac.h"

// Defines
#define SAMPLES_PER_FRAME  128
#define DATA_CORRECT       0
#define DATA_INCORRECT    -1

// Function prototypes
void process_data(int samples_per_frame, int* dst, int* src);
int verify_data(XLlFifo* p_axis_fifo_inst, int frm_idx);

// Main entry point
int main()
{
	// Local variables
	int     status;
	int     ii = 0;
	XLlFifo axis_fifo_inst;
	adc_t*  p_adc_inst;
	dac_t*  p_dac_inst;
	int     rcv_buf[SAMPLES_PER_FRAME];
	int     snd_buf[SAMPLES_PER_FRAME];

	// Setup UART and caches
    init_platform();
    xil_printf("\fHello World!\n\r");

    // Initialize AXI Stream to MM FIFO
	XLlFifo_Initialize(&axis_fifo_inst, XPAR_AXI_FIFO_0_BASEADDR);

    // Create ADC object
    p_adc_inst = adc_create
    (
    	XPAR_GPIO_0_DEVICE_ID,
    	XPAR_AXIDMA_0_DEVICE_ID,
    	sizeof(int)
    );
    if (p_adc_inst == NULL)
    {
    	xil_printf("ERROR! Failed to create ADC instance.\n\r");
    	return -1;
    }

    // Create DAC object
    p_dac_inst = dac_create
    (
    	XPAR_GPIO_0_DEVICE_ID,
    	XPAR_AXIDMA_0_DEVICE_ID,
    	sizeof(int)
    );
    if (p_dac_inst == NULL)
    {
    	xil_printf("ERROR! Failed to create DAC instance.\n\r");
    	return -1;
    }

    // Set the desired parameters for the ADC/DAC objects
    adc_set_bytes_per_sample(p_adc_inst, sizeof(int));
    dac_set_bytes_per_sample(p_dac_inst, sizeof(int));
    adc_set_samples_per_frame(p_adc_inst, SAMPLES_PER_FRAME);
    dac_set_samples_per_frame(p_dac_inst, SAMPLES_PER_FRAME);

	// Make sure the buffers are clear before we populate it (generally don't need to do this, but for proving the DMA working, we do it anyway)
	memset(rcv_buf, 0, SAMPLES_PER_FRAME*sizeof(int));
	memset(snd_buf, 0, SAMPLES_PER_FRAME*sizeof(int));
	
	// Enable/initialize and dac
	adc_enable(p_adc_inst);
	dac_enable(p_dac_inst);

	// Process data
	xil_printf("Starting data processing...\n\r");
	for (ii = 0; 1; ii++)
	{

		// Get new frame from ADC
		status = adc_get_frame(p_adc_inst, rcv_buf);
		if (status != ADC_SUCCESS)
		{
			xil_printf("ERROR! Failed to get a new frame of data from the ADC.\n\r");
			return -1;
		}

		// *********************** Insert your code here ***********************
		process_data(SAMPLES_PER_FRAME, snd_buf, rcv_buf);
		// *********************************************************************

		// Send processed data frame out to DAC
		status = dac_send_frame(p_dac_inst, snd_buf);
		if (status != DAC_SUCCESS)
		{
			xil_printf("ERROR! Failed to send the processed data frame out to the DAC.\n\r");
			return -1;
		}

		// ***************************** Remove me *****************************
		status = verify_data(&axis_fifo_inst, ii);
		if (status != DATA_CORRECT)
		{
			xil_printf("ERROR! Data incorrect.\n\r");
			return -1;
		}

		xil_printf("Frame %d completed without errors. Press any key to process the next frame of data.\n\r", ii);
		XUartPs_RecvByte(XPAR_PS7_UART_1_BASEADDR);
		// *********************************************************************

	}

	dac_destroy(p_dac_inst);
	adc_destroy(p_adc_inst);

    return 0;
	
}

void process_data(int samples_per_frame, int* dst, int* src)
{
	// Local variables
	int ii = 0;

	// Do something to the data
	for (ii = 0; ii < samples_per_frame; ii++)
		dst[ii] = src[ii]*2;
		
}

int verify_data(XLlFifo* p_axis_fifo_inst, int frm_idx)
{

	// Local variables
	int       ii    = 0;
	int       ideal = 0;
	int       fifo_frame[SAMPLES_PER_FRAME];
	const int num_bytes = SAMPLES_PER_FRAME*sizeof(int);

	// Make sure the buffer is clear before we populate it
	memset(fifo_frame, 0, num_bytes);

	// Read frame of data from AXIS FIFO
	Xil_DCacheFlushRange((int)fifo_frame, num_bytes);
	XLlFifo_Read(p_axis_fifo_inst, fifo_frame, num_bytes);

	// Check data
	for (ii = 0; ii < SAMPLES_PER_FRAME; ii++)
	{
		ideal = (frm_idx*SAMPLES_PER_FRAME+ii)*2;
		if (fifo_frame[ii] != ideal)
		{
			xil_printf("ERROR! Data mismatch on sample %d of frame %d. Expected %d but received %d.\n\r", ii, frm_idx, ideal, fifo_frame[ii]);
			return DATA_INCORRECT;
		}
	}

	return DATA_CORRECT;
}

