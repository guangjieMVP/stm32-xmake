/*
 * @brief :   
 * @date :  2022-02-xx
 * @version : v1.0.0
 * @copyright(c) 2020 : OptoMedic company Co.,Ltd. All rights reserved
 * @Change Logs:   
 * @date         author         notes:  
 */
#ifndef __LEDS_H__
#define __LEDS_H__

typedef unsigned char uint8_t;

void LED0_Ctrl(uint8_t onoff);
void LED1_Ctrl(uint8_t onoff);
void LED0_Toggle(void);
void LED1_Toggle(void);

#endif /* __LED_H__ */