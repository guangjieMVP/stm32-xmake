/*
 * @brief :   
 * @date :  2022-02-xx
 * @version : v1.0.0
 * @copyright(c) 2020 : OptoMedic company Co.,Ltd. All rights reserved
 * @Change Logs:   
 * @date         author         notes:  
 */
#include "leds.h"
#include "gpio.h"

void LED0_Ctrl(uint8_t onoff)
{
    if (onoff)
    {
        HAL_GPIO_WritePin(GPIOB, GPIO_PIN_5, GPIO_PIN_RESET);
    }
    else
    {
        HAL_GPIO_WritePin(GPIOB, GPIO_PIN_5, GPIO_PIN_SET);
    }
}

void LED1_Ctrl(uint8_t onoff)
{
    if (onoff)
    {
        HAL_GPIO_WritePin(GPIOE, GPIO_PIN_5, GPIO_PIN_RESET);
    }
    else
    {
        HAL_GPIO_WritePin(GPIOE, GPIO_PIN_5, GPIO_PIN_SET);
    }
}

void LED0_Toggle(void)
{
    HAL_GPIO_TogglePin(GPIOB, GPIO_PIN_5);
}

void LED1_Toggle(void)
{
    HAL_GPIO_TogglePin(GPIOE, GPIO_PIN_5);
}