#include "xparameters.h"
#include "xuartps.h"

int main() {
    XUartPs u0, u1;
    XUartPs_Config *c0 = XUartPs_LookupConfig(XPAR_XUARTPS_0_BASEADDR);
    XUartPs_Config *c1 = XUartPs_LookupConfig(XPAR_XUARTPS_1_BASEADDR);

    XUartPs_CfgInitialize(&u0, c0, c0->BaseAddress);
    XUartPs_CfgInitialize(&u1, c1, c1->BaseAddress);
    XUartPs_SetBaudRate(&u0, 9600);
    XUartPs_SetBaudRate(&u1, 9600);

    while (1) {
        if (XUartPs_IsReceiveData(c0->BaseAddress)) {
            u8 b = XUartPs_ReadReg(c0->BaseAddress, XUARTPS_FIFO_OFFSET);
            XUartPs_WriteReg(c1->BaseAddress, XUARTPS_FIFO_OFFSET, b);
        }
        if (XUartPs_IsReceiveData(c1->BaseAddress)) {
            u8 b = XUartPs_ReadReg(c1->BaseAddress, XUARTPS_FIFO_OFFSET);
            XUartPs_WriteReg(c0->BaseAddress, XUARTPS_FIFO_OFFSET, b);
        }
    }
}