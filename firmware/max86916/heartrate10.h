/****************************************************************************
** Copyright (C) 2020 MikroElektronika d.o.o.
** Contact: https://www.mikroe.com/contact
**
** Permission is hereby granted, free of charge, to any person obtaining a copy
** of this software and associated documentation files (the "Software"), to deal
** in the Software without restriction, including without limitation the rights
** to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
** copies of the Software, and to permit persons to whom the Software is
** furnished to do so, subject to the following conditions:
** The above copyright notice and this permission notice shall be
** included in all copies or substantial portions of the Software.
**
** THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
** EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
** OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
** IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
** DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT
** OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
**  USE OR OTHER DEALINGS IN THE SOFTWARE.
****************************************************************************/



#ifndef __HEARTRATE10_H
#define __HEARTRATE10_H

#include <Arduino.h>
#include <Wire.h>

#define HEARTRATE10_REG_INT_STATUS              0x00
#define HEARTRATE10_REG_INT_ENABLE              0x02
#define HEARTRATE10_REG_FIFO_WR_PTR             0x04
#define HEARTRATE10_REG_FIFO_OVF_CNT            0x05
#define HEARTRATE10_REG_FIFO_RD_PTR             0x06
#define HEARTRATE10_REG_FIFO_DATA               0x07
#define HEARTRATE10_REG_FIFO_CFG                0x08
#define HEARTRATE10_REG_MODE_CFG1               0x09
#define HEARTRATE10_REG_MODE_CFG2               0x0A
#define HEARTRATE10_REG_LED1_PA                 0x0C
#define HEARTRATE10_REG_LED2_PA                 0x0D
#define HEARTRATE10_REG_LED3_PA                 0x0E
#define HEARTRATE10_REG_LED4_PA                 0x0F
#define HEARTRATE10_REG_LED_RANGE               0x11
#define HEARTRATE10_REG_PILOT_PA                0x12
#define HEARTRATE10_REG_LED_SEQ1                0x13
#define HEARTRATE10_REG_LED_SEQ2                0x14
#define HEARTRATE10_REG_DAC1_CROSSTALK_CODE     0x26
#define HEARTRATE10_REG_DAC2_CROSSTALK_CODE     0x27
#define HEARTRATE10_REG_DAC3_CROSSTALK_CODE     0x28
#define HEARTRATE10_REG_DAC4_CROSSTALK_CODE     0x29
#define HEARTRATE10_REG_PROX_INT_THRESHOLD      0x30
#define HEARTRATE10_REG_LED_COMPARATOR_EN       0x31
#define HEARTRATE10_REG_LED_COMPARATOR_STATUS   0x32
#define HEARTRATE10_REG_REV_ID                  0xFE
#define HEARTRATE10_REG_PART_ID                 0xFF

#define HEARTRATE10_PART_ID                     0x2B

#define HEARTRATE10_SET_DEV_ADDR                0x57
#define HEARTRATE10_SET_DEV_ADDR_W              0xAE
#define HEARTRATE10_SET_DEV_ADDR_R              0xAF




#define ERR_NONE 0         // No error
#define ERR_WRITE -1       // Error during writing
#define ERR_READ -2        // Error during reading


typedef struct
{
    // Input pins
    uint32_t  int_pin;  /**< Interrupt pin. */

    // I2C slave address
    uint8_t slave_address;  /**< Device slave address (used for I2C driver). */

} heartrate10_t;



typedef enum
{
   HEARTRATE10_OK = 0,
   HEARTRATE10_ERROR = -1

} heartrate10_return_value_t;

heartrate10_t* heartrate10_init ( int pin_interrupt );

err_t heartrate10_default_cfg ( heartrate10_t *ctx);

err_t heartrate10_generic_write ( heartrate10_t *ctx, uint8_t reg, uint8_t tx_data );


err_t heartrate10_generic_read ( heartrate10_t *ctx, uint8_t reg, uint8_t *rx_data );


uint8_t heartrate10_get_int_pin ( heartrate10_t *ctx );


void heartrate10_reset ( heartrate10_t *ctx );


err_t heartrate10_fifo_read ( heartrate10_t *ctx, uint8_t *rx_buf, uint8_t rx_len );


uint32_t heartrate10_read_fifo_sample ( heartrate10_t *ctx );


err_t heartrate10_read_complete_fifo_data ( heartrate10_t *ctx, uint32_t *led1, uint32_t *led2, uint32_t *led3, uint32_t *led4 );

#endif // HEARTRATE10_H

