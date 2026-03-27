/*
* alu_test.c allows for interfacing with our alu running on the fpga.
* This used Vitis to run code on the bare metal arm core.
* 
* This program communicates with the arm core through uart, then
* the core gives the inputs to the alu. The core then receives the
* inputs and send it back to the PC over uart.
*/
#include <stdio.h>
#include <xparameters.h>
#include "platform.h"
#include "xil_printf.h"
#include "xgpiops.h"


int main()
{
    //intitializes core and fpga setup
    init_platform();
    
    //gpio init
    XGpioPs gpio; 
    XGpioPs_Config *config_ptr;
    config_ptr = XGpioPs_LookupConfig(XPAR_XGPIOPS_0_BASEADDR);
    XGpioPs_CfgInitialize(&gpio, config_ptr, config_ptr->BaseAddr);

    //sets pin dirtections
    //input
    XGpioPs_SetDirection(&gpio, 3, 0x00000000);

    //output
    XGpioPs_SetDirection(&gpio, 4, 0xFFFFFFFF);
    XGpioPs_SetOutputEnable(&gpio, 4, 0xFFFFFFFF); 
    XGpioPs_SetDirection(&gpio, 5, 0xFFFFFFFF);
    XGpioPs_SetOutputEnable(&gpio, 5, 0xFFFFFFFF);

    
    //test values
    u32 in_0 = 0x00000005 << 1;
    u32 in_1 = 0x00000007;
    u8 alu_opcode = 0b011001;
    
    //adjust for pin setup bc i messed up the vivado connection by 1
    u32 bank_4 = (in_0 & 0x00FFFFFF) | (in_1 << 25);
    u32 bank_5 = ((in_1 >> 8) & 0x00FFFFFF) | (alu_opcode << 25);
    
    //sends to alu
    XGpioPs_Write(&gpio, 4, bank_4);
    XGpioPs_Write(&gpio, 5, bank_5); 

    //gets fro m arm core
    u32 alu_output = XGpioPs_Read(&gpio, 3);

    //output
    printf("ALU Output: %d\n\r", alu_output);
    print("Successfully ran ALU test");

    //cleans fpga
    cleanup_platform();
    return 0;
}
