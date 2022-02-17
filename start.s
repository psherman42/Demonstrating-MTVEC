################################################
## START.S
## 
## 2020-04-02 pds    initial cut
## 2021-11-24 pds    add read_csr and write_csr
##

.equ GPIO_BASE, 0x10012000
.equ GPIO_OUT_VAL, 0x0C

.equ DEMO_BIT, 0x200              # bit 9, or any other output line available GPIO on the hardware

.equ CSR_MSTATUS_MPP,  0x00001800  # [12:11]  machine prev priv mode
.equ CSR_MSTATUS_SPP,  0x00000100  # [8]  supervisor prev prev mode
.equ CSR_MSTATUS_MPIE, 0x00000080  # [7]  machine prev int enable
.equ CSR_MSTATUS_SPIE, 0x00000020  # [5]  supervisor prev int enable
.equ CSR_MSTATUS_MIE,  0x00000008  # [3]  machine int enable
.equ CSR_MSTATUS_SIE,  0x00000002  # [1]  supervisor int enable

.equ CSR_MIE_MEIE,     0x00000800  # [11]  machine external int enable
.equ CSR_MIE_SEIE,     0x00000200  # [9]  supervisor external int enable
.equ CSR_MIE_MTIE,     0x00000080  # [7]  machine timer int enable
.equ CSR_MIE_STIE,     0x00000020  # [5]  supervisor int enable
.equ CSR_MIE_MSIE,     0x00000008  # [3]  machine software int enable
.equ CSR_MIE_SSIE,     0x00000002  # [1]  supervisor software int enable

.equ CSR_MIP_MEIE,     0x00000800  # [11]  machine external int pending
.equ CSR_MIP_SEIE,     0x00000200  # [9]  supervisor external int pending
.equ CSR_MIP_MTIE,     0x00000080  # [7]  machine timer int pending
.equ CSR_MIP_STIE,     0x00000020  # [5]  supervisor int pending
.equ CSR_MIP_MSIE,     0x00000008  # [3]  machine software int pending
.equ CSR_MIP_SSIE,     0x00000002  # [1]  supervisor software int pending

.equ CSR_MCAUSE_EC,    0x0000003F # 0x3ff ???  # [9:0] exception code

###############################################
##
## entry point main reset vector
##

.section .text

.globl _start
_start:
  lui a1, 0x80004  # top of ram
  addi sp, a1, -4

  csrrci x0, mstatus, (CSR_MSTATUS_MIE | CSR_MSTATUS_SIE)  # disable interrupts

  addi t0, zero, %lo(CSR_MIE_MEIE | CSR_MIE_MTIE | CSR_MIE_MSIE)
  csrrc zero, mie, t0

  # BUG FIX: must explicitly clear pending bits
  addi t0, zero, %lo(CSR_MIP_MEIE | CSR_MIP_MTIE | CSR_MIP_MSIE)
  csrrc zero, mip, t0

  # set trap handler
  lui t0, %hi(trap_handler) 
  addi t0, t0, %lo(trap_handler)
  andi t0, t0, 0xFFFFFFFC  # mtvec.BASE [1:0] 0=direct, 1=vector
  csrrw x0, mtvec, t0

  jal main
  j .

###############################################
##
## trap handler
##

.equ CLINT_BASE, 0x02000000
.equ CLINT_MSIP,     (CLINT_BASE + 0x0000)
.equ CLINT_MTIMECMP, (CLINT_BASE + 0x4000)
.equ CLINT_MTIME,    (CLINT_BASE + 0xbff8)

.balign 8  # required 64-bit alignment for mtvec in vectored (non-direct) mode
trap_handler:
  # decode trap source
  csrr t0, mcause             # read trap cause
  bgez t0, trap_exception     # branch if not an interrupt
  #
trap_interrupt:
  andi t0, t0, CSR_MCAUSE_EC  # isolate exception code
  addi t1, zero, 16
  bge t0, t1, trap_unkn
  slli t0, t0, 1           # put on two byte boundary
  la t1, int_vec_tab       # interrupt (asynchronous) source
  add t0, t0, t1
  jr t0
trap_exception:
  addi t1, zero, 16
  bge t0, t1, trap_unkn
  slli t0, t0, 1           # put on two byte boundary
  la t1, excep_vec_tab     # exception (synchronous) source
  add t0, t0, t1
  jr t0
trap_unkn:
  # single marker pulse
  lui t0, %hi(GPIO_BASE)
  lw t1, GPIO_OUT_VAL(t0)
  xori t1, t1, DEMO_BIT
  sw t1, GPIO_OUT_VAL(t0)
  j .                      # unknown cause - loop forever, for now

.balign 2
int_vec_tab:
  j int_software_u_mode  # source id 0
  j int_software_s_mode  # source id 1
  j int_software_h_mode  # source id 2
  j int_software_m_mode  # source id 3 (middle async prio)
  j int_timer_u_mode     # source id 4
  j int_timer_s_mode     # source id 5
  j int_timer_h_mode     # source id 6
  j int_timer_m_mode     # source id 7 (lowest async prio)
  j int_external_u_mode  # source id 8
  j int_external_s_mode  # source id 9
  j int_external_h_mode  # source id 10
  j int_external_m_mode  # source id 11 (highest async prio)
  j int_reserved12       # source id 12
  j int_reserved13       # source id 13
  j int_reserved14       # source id 14
  j int_reserved15       # source id 15

.balign 2
excep_vec_tab:
  j ex_instr_address_misaligned  # source id 0
  j ex_instr_access_fault        # source id 1
  j ex_illegal_instr             # source id 2
  j ex_breakpoint                # source id 3
  j ex_load_address_misaligned   # source id 4
  j ex_load_access_fault         # source id 5
  j ex_store_address_misaligned  # source id 6
  j ex_store_access_fault        # source id 7
  j ex_env_call_from_u_mode      # source id 8
  j ex_env_call_from_s_mode      # source id 9
  j ex_env_call_from_h_mode      # source id 10
  j ex_env_call_from_m_mode      # source id 11
  j ex_instr_page_fault          # source id 12
  j ex_load_page_fault           # source id 13
  j ex_reserved14                # source id 14
  j ex_store_page_fault          # source id 15

ex_instr_address_misaligned:
  mret

ex_instr_access_fault:
  mret

ex_illegal_instr:
  mret

ex_breakpoint:
  mret

ex_load_address_misaligned:
  mret

ex_load_access_fault:
  mret

ex_store_address_misaligned:
  mret

ex_store_access_fault:
  mret

ex_env_call_from_u_mode:
  mret

ex_env_call_from_s_mode:
  mret

ex_env_call_from_h_mode:
  mret

ex_env_call_from_m_mode:
  lui t0, %hi(GPIO_BASE)
  lw t1, GPIO_OUT_VAL(t0)
  xori t1, t1, DEMO_BIT
  sw t1, GPIO_OUT_VAL(t0)
  xori t1, t1, DEMO_BIT
  sw t1, GPIO_OUT_VAL(t0)
  mret

ex_instr_page_fault:
  mret

ex_load_page_fault:
  mret

ex_reserved14:
  mret

ex_store_page_fault:
  mret

##
## reserved/undefined interrupt (asynchronous) sources
##

.balign 4
int_reserved12:
  mret

.balign 4
int_reserved13:
  mret

.balign 4
int_reserved14:
  mret

.balign 4
int_reserved15:
  mret

##
## timer interrupt (asynchronous) source
##

.balign 4
int_timer_m_mode:
  #
  # ... timer handler code goes here ...
  #
  lui t0, %hi(GPIO_BASE)
  lw t1, GPIO_OUT_VAL(t0)
  xori t1, t1, DEMO_BIT
  sw t1, GPIO_OUT_VAL(t0)
  #
  lui t0, %hi(CLINT_MTIMECMP)
  addi t0, t0, %lo(CLINT_MTIMECMP)
  lw t1, 0(t0)        # load lower 32 bits of comparator
  lw t2, 4(t0)        # load upper 32 bits of comparator
  addi t3, t1, 1180   # increment lower bits by (11.7959*ms + 0.020183) cycles
  sltu t1, t3, t2     # generate carry-out
  add t2, t2, t1      # increment upper bits
  sw t2, 4(t0)        # store upper 32 bits
  sw t3, 0(t0)        # store lower 32 bits
  #
  addi t0, zero, %lo(CSR_MIP_MTIE)   # clear timer interrupt pending
  csrrc zero, mip, t0
  mret

.balign 4
int_timer_u_mode:
  j int_timer_m_mode

.balign 4
int_timer_s_mode:
  j int_timer_m_mode

.balign 4
int_timer_h_mode:
  j int_timer_m_mode

##
## software interrupt (asynchronous) source
##

.balign 4
int_software_m_mode:
  #
  # ... software handler code goes here ...
  #
  lui t0, %hi(GPIO_BASE)
  lw t1, GPIO_OUT_VAL(t0)
  xori t1, t1, DEMO_BIT
  sw t1, GPIO_OUT_VAL(t0)
  #
  lui t0, %hi(CLINT_MSIP)
  addi t0, t0, %lo(CLINT_MSIP)
  sw zero, 0(t0)
  #
  addi t0, zero, %lo(CSR_MIP_MSIE)   # clear software interrupt pending
  csrrc zero, mip, t0
  mret

.balign 4
int_software_u_mode:
  j int_software_m_mode

.balign 4
int_software_s_mode:
  j int_software_m_mode

.balign 4
int_software_h_mode:
  j int_software_m_mode

##
## external interrupt (asynchronous) source
##

.equ PLIC_BASE, 0x0C000000
.equ PLIC_PRIO,  (PLIC_BASE + 0x0)     # 4 * CLAIM number
.equ PLIC_PEND,  (PLIC_BASE + 0x1000)  # 64-bit value
.equ PLIC_ENA,   (PLIC_BASE + 0x2000)  # 64-bit value
.equ PLIC_THR,   (PLIC_BASE + 0x200000)
.equ PLIC_CLAIM, (PLIC_BASE + 0x200004)
.equ PLIC_MAX_NUM_SOURCES, 52          # FE310-G002

.balign 4  # required 64-bit alignment for mtvec
int_external_m_mode:
  lui t0, %hi(PLIC_CLAIM)    # read external interrupt source
  addi t0, t0, %lo(PLIC_CLAIM)
  lw t1, 0(t0)               # act of reading clears pending bit
  sw t1, 0(t0)               # signal claim complete
  addi t2, zero, PLIC_MAX_NUM_SOURCES
  bge t1, t2, int_external_unkn
  slli t1, t1, 1           # put on two byte boundary
  la t0, plic_vec_tab
  add t0, t0, t1
  jr t0
int_external_unkn:
  # triple marker pulse
  lui t0, %hi(GPIO_BASE)
  lw t1, GPIO_OUT_VAL(t0)
  xori t1, t1, DEMO_BIT
  sw t1, GPIO_OUT_VAL(t0)
  xori t1, t1, DEMO_BIT
  sw t1, GPIO_OUT_VAL(t0)
  xori t1, t1, DEMO_BIT
  sw t1, GPIO_OUT_VAL(t0)
  j .                      # loop forever, for now

.balign 4
int_external_u_mode:
  j int_external_m_mode

.balign 4
int_external_s_mode:
  j int_external_m_mode

.balign 4
int_external_h_mode:
  j int_external_m_mode

.balign 2
plic_vec_tab:
  j plic_nada    # source id 0
  j plic_aon_wdt # source id 1
  j plic_aon_rtc # source id 2
  j plic_uart0   # source id 3
  j plic_uart1   # source id 4
  j plic_qspi0   # source id 5
  j plic_spi1    # source id 6
  j plic_spi2    # source id 7
  j plic_gpio0   # source id 8
  j plic_gpio1   # source id 9
  j plic_gpio2   # source id 10
  j plic_gpio3   # source id 11
  j plic_gpio4   # source id 12
  j plic_gpio5   # source id 13
  j plic_gpio6   # source id 14
  j plic_gpio7   # source id 15
  j plic_gpio8   # source id 16
  j plic_gpio9   # source id 17
  j plic_gpio10  # source id 18
  j plic_gpio11  # source id 19
  j plic_gpio12  # source id 20
  j plic_gpio13  # source id 21
  j plic_gpio14  # source id 22
  j plic_gpio15  # source id 23
  j plic_gpio16  # source id 24
  j plic_gpio17  # source id 25
  j plic_gpio18  # source id 26
  j plic_gpio19  # source id 27
  j plic_gpio20  # source id 28
  j plic_gpio21  # source id 29
  j plic_gpio22  # source id 30
  j plic_gpio23  # source id 31
  j plic_gpio24  # source id 32
  j plic_gpio25  # source id 33
  j plic_gpio26  # source id 34
  j plic_gpio27  # source id 35
  j plic_gpio28  # source id 36
  j plic_gpio29  # source id 37
  j plic_gpio30  # source id 38
  j plic_gpio31  # source id 39
  j plic_pwm0_0  # source id 40
  j plic_pwm0_1  # source id 41
  j plic_pwm0_2  # source id 42
  j plic_pwm0_3  # source id 43
  j plic_pwm1_0  # source id 44
  j plic_pwm1_1  # source id 45
  j plic_pwm1_2  # source id 46
  j plic_pwm1_3  # source id 47
  j plic_pwm2_0  # source id 48
  j plic_pwm2_1  # source id 49
  j plic_pwm2_2  # source id 50
  j plic_pwm2_3  # source id 51
  j plic_i2c     # source id 52

plic_nada:
  mret

plic_aon_wdt:
  mret

plic_aon_rtc:
  mret

plic_uart0:
  mret

plic_uart1:
  mret

plic_qspi0:
  mret

plic_spi1:
  mret

plic_spi2:
  mret

plic_gpio0:
  mret

plic_gpio1:
  mret

plic_gpio2:
  mret

plic_gpio3:
  mret

plic_gpio4:
  mret

plic_gpio5:
  mret

plic_gpio6:
  mret

plic_gpio7:
  mret

plic_gpio8:
  mret

plic_gpio9:
  mret

plic_gpio10:
  mret

plic_gpio11:
  mret

plic_gpio12:
  mret

plic_gpio13:
  mret

plic_gpio14:
  mret

plic_gpio15:
  mret

plic_gpio16:
  mret

plic_gpio17:
  mret

plic_gpio18:
  mret

plic_gpio19:
  mret

plic_gpio20:
  mret

plic_gpio21:
  mret

plic_gpio22:
  mret

plic_gpio23:
  mret

plic_gpio24:
  mret

plic_gpio25:
  mret

plic_gpio26:
  mret

plic_gpio27:
  mret

plic_gpio28:
  mret

plic_gpio29:
  mret

plic_gpio30:
  mret

plic_gpio31:
  mret

plic_pwm0_0:
  mret

plic_pwm0_1:
  mret

plic_pwm0_2:
  mret

plic_pwm0_3:
  mret

plic_pwm1_0:  # plic source id 44
  lui t0, %hi(GPIO_BASE)
  lw t1, GPIO_OUT_VAL(t0)
  xori t1, t1, DEMO_BIT
  sw t1, GPIO_OUT_VAL(t0)
  #
  mret

plic_pwm1_1:  # plic source id 45
  lui t0, %hi(GPIO_BASE)
  lw t1, GPIO_OUT_VAL(t0)
  xori t1, t1,DEMO_BIT
  sw t1, GPIO_OUT_VAL(t0)
  #
  mret

plic_pwm1_2:
  mret

plic_pwm1_3:
  mret

plic_pwm2_0:  # plic source id 48
  lui t0, %hi(GPIO_BASE)
  lw t1, GPIO_OUT_VAL(t0)
  xori t1, t1, DEMO_BIT
  sw t1, GPIO_OUT_VAL(t0)
  #
  mret

plic_pwm2_1:  # plic source id 49
  lui t0, %hi(GPIO_BASE)
  lw t1, GPIO_OUT_VAL(t0)
  xori t1, t1, DEMO_BIT
  sw t1, GPIO_OUT_VAL(t0)
  #
  mret

plic_pwm2_2:
  mret

plic_pwm2_3:
  mret

plic_i2c:
  mret

###############################################
##
## user mode utility functions
##

#.section .text

#
# void disable_interrupts (void);
#

.globl disable_interrupts
.balign 4
disable_interrupts:
  csrrci zero, mstatus, (CSR_MSTATUS_MIE | CSR_MSTATUS_SIE)   # disable interrupts
  #
  addi t0, zero, %lo(CSR_MIE_MEIE | CSR_MIE_MTIE | CSR_MIE_MSIE)  # disable interrupt sources
  csrrc zero, mie, t0
  #
  jalr zero, 0(ra)

#
# void enable_external_interrupt (uint8_t plic_source_id);
#
#  a0 - plic_source_id: 1=aon_wdt, 2=aon_rtc, 3-4=uart, 5-7=spi, 8-39=gpio, 40-51=pwm, ..., 52=i2c
#

.globl enable_external_interrupt
.balign 4
enable_external_interrupt:
  # at reset aon_wdt,aon_rtc plic pending bits are set for some reason
  # BUG FIX: ip always set at power-up because wdogcmp0, wdogcount,
  # rtccmp0, rtccountlo, rtccounthi all reset to zero.
  # suggest cmp values reset to all-bits-high
  # to prevent immediate trigger of ip
  lui t0, %hi(PLIC_PEND)
  addi t0, t0, %lo(PLIC_PEND)
  sw zero, 0(t0)  # 1 .. 31
  sw zero, 4(t0)  # 32 .. 52

  lui t0, %hi(PLIC_ENA)
  addi t0, t0, %lo(PLIC_ENA)
  sw zero, 0(t0)  # 1 .. 31
  sw zero, 4(t0)  # 32 .. 52

  lui t0, %hi(PLIC_PRIO)
  addi t0, t0, %lo(PLIC_PRIO)
  slli t1, a0, 2  # 4 * plic_source_id
  add t0, t0, t1
  addi t1, zero, 7
  sw t1, 0(t0)

  lui t0, %hi(PLIC_ENA)
  addi t0, t0, %lo(PLIC_ENA)
  addi t1, zero, 32
  bge a0, t1, ex2
ex1:
  addi t2, zero, 1
  sll t2, t2, a0
  sw t2, 0(t0)  # 1 .. 31
  j ex_epi
ex2:
  remu t3, a0, t1
  addi t2, zero, 1
  sll t2, t2, t3
  sw t2, 4(t0)  # 32 .. 52
ex_epi:
  #
  addi t0, zero, %lo(CSR_MIP_MEIE)   # clear external interrupt pending bit
  csrrc zero, mip, t0
  #
  addi t0, zero, %lo(CSR_MIE_MEIE)   # enable external interrupt sources
  csrrs zero, mie, t0
  #
  csrrsi zero, mstatus, (CSR_MSTATUS_MIE)   # enable interrupts
  #
  jalr zero, 0(ra)

#
# void disable_external_interrupt (void);
#

.globl disable_external_interrupt
.balign 4
disable_external_interrupt:
  addi t0, zero, %lo(CSR_MIE_MEIE)   # disable external interrupt source
  csrrc zero, mie, t0
  #
  jalr zero, 0(ra)

#
# void enable_timer_interrupt (uint16 ms);
#

.globl enable_timer_interrupt
.balign 4
enable_timer_interrupt:
  lui t0, %hi(CLINT_MTIMECMP)
  addi t0, t0, %lo(CLINT_MTIMECMP)
  #addi t1, zero, 1180   # initialize lower bits by (11.7959*ms + 0.020183) cycles
  add t1, zero, a0      # initialize lower bits by (11.7959*a0_ms + 0.020183) cycles
  sw zero, 4(t0)        # store upper 32 bits
  sw t1, 0(t0)          # store lower 32 bits
  lui t0, %hi(CLINT_MTIME)
  addi t0, t0, %lo(CLINT_MTIME)
  sw zero, 4(t0)        # store upper 32 bits
  sw zero, 0(t0)        # store lower 32 bits
  #
  addi t0, zero, %lo(CSR_MIP_MTIE)   # clear timer interrupt pending bit
  csrrc zero, mip, t0
  #
  addi t0, zero, %lo(CSR_MIE_MTIE)   # enable timer interrupt source
  csrrs zero, mie, t0
  #
  csrrsi zero, mstatus, (CSR_MSTATUS_MIE)   # enable interrupts
  #
  jalr zero, 0(ra)

#
# void disable_timer_interrupt (void);
#

.globl disable_timer_interrupt
.balign 4
disable_timer_interrupt:
  addi t0, zero, %lo(CSR_MIE_MTIE)   # disable timer interrupt source
  csrrc zero, mie, t0
  #
  jalr zero, 0(ra)

#
# void enable_software_interrupt (void);
#

.globl enable_software_interrupt
.balign 4
enable_software_interrupt:
  addi t0, zero, %lo(CSR_MIP_MSIE)   # clear software interrupt pending bit
  csrrc zero, mip, t0
  #
  addi t0, zero, %lo(CSR_MIE_MSIE)   # enable software interrupt source
  csrrs zero, mie, t0
  #
  csrrsi zero, mstatus, (CSR_MSTATUS_MIE)   # enable interrupts
  #
  jalr zero, 0(ra)

#
# void disable_software_interrupt (void);
#

.globl disable_software_interrupt
.balign 4
disable_software_interrupt:
  addi t0, zero, %lo(CSR_MIE_MSIE)   # disable software interrupt source
  csrrc zero, mie, t0
  #
  jalr zero, 0(ra)

#
# void trigger_software_interrupt (void);
#

.globl trigger_software_interrupt
.balign 4
trigger_software_interrupt:
  lui t0, %hi(CLINT_MSIP)
  addi t0, t0, %lo(CLINT_MSIP)
  addi t1, zero, 0x1
  sw t1, 0(t0)
  #
  jalr zero, 0(ra)
