/*
 * @brief :
 * @date :  2022-02-xx
 * @version : v1.0.0
 * @copyright(c) 2020 : OptoMedic company Co.,Ltd. All rights reserved
 * @Change Logs:
 * @date         author         notes:
 */
#include "stm32f1xx_hal.h"
#include "usart.h"
#include "stdarg.h"

#if 0
int _write(int fd, char *buf, int size)
{
    for (int i = 0; i < size; i++)
    {
        while ((USART1->SR & 0X40) == 0); /* wait finised */
        USART1->DR = (uint8_t)buf[i]; /* send data */
    }
    return size;
}
#endif

int8_t usart1Write(char *buf, int size)
{
    for (int i = 0; i < size; i++)
    {
        while ((USART1->SR & 0X40) == 0); /* wait finised */
        USART1->DR = (uint8_t)buf[i]; /* send data */
    }
    return 0;
}

void myprintf(const char *format, ...)
{
    char  str[256] = {0};
    va_list   v_args;

    va_start(v_args, format);
   (void)vsnprintf((char       *)&str[0],
                   (size_t      ) sizeof(str),
                   (char const *) format,
                                  v_args);
    va_end(v_args);

    usart1Write((char *)str, strlen(str));
}

