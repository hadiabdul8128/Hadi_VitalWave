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


#include "heartrate10.h"

heartrate10_t* heartrate10_init ( int pin_interrupt ) 
{
    
    heartrate10_t *ctx;
    ctx = (heartrate10_t*) malloc(sizeof(heartrate10_t));
    ctx->int_pin = pin_interrupt;
    ctx->slave_address = HEARTRATE10_SET_DEV_ADDR; 
    pinMode(pin_interrupt, INPUT);
    return ctx;
}

err_t heartrate10_default_cfg ( heartrate10_t *ctx) 
{
    //Shutdown device
    heartrate10_generic_write( ctx, HEARTRATE10_REG_MODE_CFG1, 0x80 );
    delay(1000);
    //Reset device
    heartrate10_reset( ctx );
    //Part ID
    uint8_t id_data = 0;
    heartrate10_generic_read( ctx, HEARTRATE10_REG_PART_ID, &id_data );
    if ( HEARTRATE10_PART_ID != id_data )
    {
        return HEARTRATE10_ERROR;
    }
    //Set flex led mode
    heartrate10_generic_write( ctx, HEARTRATE10_REG_MODE_CFG1, 0x03 );
    //Set scale range, sample per second and led pulse widths
    // heartrate10_generic_write( ctx, HEARTRATE10_REG_MODE_CFG2, 0x64 );

    //Set pulse width to 220 us
    heartrate10_generic_write( ctx, HEARTRATE10_REG_MODE_CFG2, 0x6E ); //0x64

    //Set led sequences [ IR, RED, GREEN, BLUE ]
    heartrate10_generic_write( ctx, HEARTRATE10_REG_LED_SEQ1, 0x21 );//RED-IR
    heartrate10_generic_write( ctx, HEARTRATE10_REG_LED_SEQ2, 0x43 );//BLUE-GREEN
    //Set led range
    heartrate10_generic_write( ctx, HEARTRATE10_REG_LED_RANGE, 0x00 );
    //Set led power
    heartrate10_generic_write( ctx, HEARTRATE10_REG_LED1_PA, 0xFF );//IR FF
    heartrate10_generic_write( ctx, HEARTRATE10_REG_LED2_PA, 0xFF );//RED FF
    heartrate10_generic_write( ctx, HEARTRATE10_REG_LED3_PA, 0xFF );//GREEN FF
    heartrate10_generic_write( ctx, HEARTRATE10_REG_LED4_PA, 0xFF );//BLUE FF
    //Enable fifo overflow
    heartrate10_generic_write( ctx, HEARTRATE10_REG_FIFO_CFG, 0x10 );
    //Enable Int on data ready
    heartrate10_generic_write( ctx, HEARTRATE10_REG_INT_ENABLE, 0x40 );

    return HEARTRATE10_OK;
}

err_t heartrate10_generic_write(heartrate10_t *ctx, uint8_t reg, uint8_t tx_data) 
{
    // Start I2C transmission to the device at ctx->i2c_address
    Wire.beginTransmission(ctx->slave_address);
    // Wire.beginTransmission(MAX86916_WRITE_ADDR);

    // Write the register address
    if (Wire.write(reg) != 1) { 
        // If failed to write the register address, return ERR_WRITE
        return ERR_WRITE;
    }

    // Write the data
    if (Wire.write(tx_data) != 1) { 
        // If failed to write the data, return ERR_WRITE
        return ERR_WRITE;
    }

    // End the transmission and check for errors
    if (Wire.endTransmission() != 0) {
        // If there is an error ending the transmission, return ERR_WRITE
        return ERR_WRITE;
    }

    // If everything is successful, return ERR_NONE
    return ERR_NONE;
}

err_t i2c_master_write_then_read(heartrate10_t *ctx, uint8_t *write_data_buf, size_t len_write_data, uint8_t *read_data_buf, size_t len_read_data) {
    // Begin transmission to the I2C device
    Wire.beginTransmission(ctx->slave_address);
    // Wire.beginTransmission(MAX86916_WRITE_ADDR);

    // Write data to the I2C device
    for (size_t i = 0; i < len_write_data; i++) {
        Wire.write(write_data_buf[i]);
    }

    // End the transmission
    err_t write_status = Wire.endTransmission();
    if (write_status != 0) {
        return ERR_WRITE;  // Return error code if writing fails
    }

    // Request to read len_read_data bytes from the I2C device
    Wire.requestFrom(ctx->slave_address, len_read_data);
    // Wire.requestFrom(MAX86916_READ_ADDR, len_read_data);

    // Check if the requested number of bytes is available
    if (Wire.available() < len_read_data) {
        return ERR_READ;  // Return error code if not enough bytes are available
    }

    // Read data into the read_data_buf
    for (size_t i = 0; i < len_read_data; i++) {
        read_data_buf[i] = Wire.read();
    }

    // If everything is successful, return ERR_NONE
    return ERR_NONE;
}


err_t heartrate10_generic_read ( heartrate10_t *ctx, uint8_t reg, uint8_t *rx_data ) 
{
    return i2c_master_write_then_read(ctx, &reg, 1, rx_data, 1 );
}

uint8_t heartrate10_get_int_pin ( heartrate10_t *ctx )
{
    return digitalRead( ctx->int_pin );
}

void heartrate10_reset ( heartrate10_t *ctx )
{
    heartrate10_generic_write( ctx, HEARTRATE10_REG_MODE_CFG1, 0x40 );
    uint8_t reg_data;
    do {
        heartrate10_generic_read( ctx, HEARTRATE10_REG_INT_STATUS, &reg_data );
        reg_data &= 0x01;
    } while ( reg_data );
}

err_t heartrate10_fifo_read ( heartrate10_t *ctx, uint8_t *rx_buf, uint8_t rx_len )
{
    uint8_t reg = HEARTRATE10_REG_FIFO_DATA;
    return i2c_master_write_then_read( ctx, &reg, 1, rx_buf, rx_len );
}

uint32_t heartrate10_read_fifo_sample ( heartrate10_t *ctx )
{
    uint32_t sample;
    uint8_t sample_parts[ 3 ] = { 0 };
    uint8_t fifo_reg = HEARTRATE10_REG_FIFO_DATA;
    heartrate10_fifo_read( ctx, sample_parts, 3 );
    sample = sample_parts[ 2 ] | ( ( uint32_t )sample_parts[ 1 ] << 8 ) | ( ( uint32_t )sample_parts[ 0 ] << 16 );
    sample &= 0x0007FFFF;
    return sample;
}

err_t heartrate10_read_complete_fifo_data ( heartrate10_t *ctx, uint32_t *led1, uint32_t *led2, uint32_t *led3, uint32_t *led4 )
{
    uint8_t sample_parts[ 12 ] = { 0 };
    err_t error_flag = heartrate10_fifo_read( ctx, sample_parts, 12 );
    *led1 = sample_parts[ 2 ] | ( ( uint32_t )sample_parts[ 1 ] << 8 ) | ( ( uint32_t )sample_parts[ 0 ] << 16 );
    *led1 &= 0x0007FFFF;
    *led2 = sample_parts[ 5 ] | ( ( uint32_t )sample_parts[ 4 ] << 8 ) | ( ( uint32_t )sample_parts[ 3 ] << 16 );
    *led2 &= 0x0007FFFF;
    *led3 = sample_parts[ 8 ] | ( ( uint32_t )sample_parts[ 7 ] << 8 ) | ( ( uint32_t )sample_parts[ 6 ] << 16 );
    *led3 &= 0x0007FFFF;
    *led4 = sample_parts[ 11 ] | ( ( uint32_t )sample_parts[ 10 ] << 8 ) | ( ( uint32_t )sample_parts[ 9 ] << 16 );
    *led4 &= 0x0007FFFF;
    return error_flag;
}

// ------------------------------------------------------------------------- END
