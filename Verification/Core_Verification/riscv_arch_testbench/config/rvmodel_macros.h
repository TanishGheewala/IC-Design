/*
* ACT4 macros for the IC-Design RV32I core
*/

#ifndef _IC_DESIGN_RVMODEL_MACROS_H
#define _IC_DESIGN_RVMODEL_MACROS_H

#define TEST_STATUS_ADDR 0x000FF000

#define RVMODEL_DATA_SECTION
#define RVMODEL_BOOT
#define RVMODEL_BOOT_TO_MMODE

#define RVMODEL_HALT_PASS \
  li t0, 1;               \
  li t1, TEST_STATUS_ADDR;\
  sw t0, 0(t1);           \
  j .;

#define RVMODEL_HALT_FAIL \
  li t0, 3;               \
  li t1, TEST_STATUS_ADDR;\
  sw t0, 0(t1);           \
  j .;

#define RVMODEL_IO_INIT(_R1, _R2, _R3)
#define RVMODEL_IO_WRITE_STR(_R1, _R2, _R3, _STR_PTR)

// Privileged interrupt tests are disabled, but ACT4 requires these definitions.
#define RVMODEL_INTERRUPT_LATENCY 10
#define RVMODEL_TIMER_INT_SOON_DELAY 100

#define RVMODEL_SET_MEXT_INT(_R1, _R2)
#define RVMODEL_CLR_MEXT_INT(_R1, _R2)
#define RVMODEL_SET_MSW_INT(_R1, _R2)
#define RVMODEL_CLR_MSW_INT(_R1, _R2)

#define RVMODEL_SET_SEXT_INT(_R1, _R2)
#define RVMODEL_CLR_SEXT_INT(_R1, _R2)
#define RVMODEL_SET_SSW_INT(_R1, _R2)
#define RVMODEL_CLR_SSW_INT(_R1, _R2)

#endif