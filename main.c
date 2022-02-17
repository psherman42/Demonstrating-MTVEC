#include <stdint.h>

void disable_interrupts (void);  // lives in start.s
void enable_external_interrupt (uint8_t plic_source_id);  // lives in start.s
void disable_external_interrupt (void);  // lives in start.s
void enable_timer_interrupt (uint16_t ms);  // lives in start.s
void disable_timer_interrupt (void);  // lives in start.s
void enable_software_interrupt (void);  // lives in start.s
void disable_software_interrupt (void);  // lives in start.s
void trigger_software_interrupt (void);  // lives in start.s

void main (void)
{
  enable_external_interrupt( 48 );  //45=pwm1_1 49=pwm2_1  1=aon_wdt, 2=aon_rtc, 3-4=uart, 5-7=spi, 8-39=gpio, 40-51=pwm, ..., 52=i2c
  //enable_software_interrupt();

  while (1)
  {
  }
}
