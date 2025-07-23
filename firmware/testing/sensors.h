#ifndef __SENSORS_H
#define __SENSORS_H

#include <Adafruit_BMP280.h>
#include <Adafruit_LIS3MDL.h>
#include <Adafruit_LSM6DS3TRC.h>
#include <Adafruit_LittleFS.h>
#include <Adafruit_SHT31.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_TinyUSB.h>
#include <InternalFileSystem.h>
#include <SPI.h>
#include <Wire.h>
#include <bluefruit.h>
#include <math.h>
#include "heartrate10.h"

// Sensor and Stream constants
#define SENSOR_COUNT 18
#define MAX_BLE_DATA 247
#define MAX_SENSOR_DATA (SENSOR_COUNT << 2)
#define MAX_PACKET_DATA (MAX_BLE_DATA - 8)
#define HEADER_ID 0xABAB

// Pinouts
#define BATTERY_PIN A6
#define PPG_INT_PIN 6
#define EVENT_PIN 7
#define SD_CS_PIN 10
#define BUTTON_PIN A0

typedef enum
{
    STATUS = 0,
    THERMISTOR = 1,
    TEMPERATURE = 2,
    PRESSURE = 3,
    HUMIDITY = 4,
    GYRO_X = 5,
    GYRO_Y = 6,
    GYRO_Z = 7,
    MAGNETIC_X = 8,
    MAGNETIC_Y = 9,
    MAGNETIC_Z = 10,
    ACCEL_X = 11,
    ACCEL_Y = 12,
    ACCEL_Z = 13,
    PPG_R = 14,
    PPG_B = 15,
    PPG_IR = 16,
    PPG_G = 17
} SensorID;

typedef enum
{
    SENSOR_OK = 0,
    SENSOR_UNAVAILABLE = -1,
    SENSOR_BUSY = 1
} SensorStatus;

// Structure to hold sensor details
typedef struct
{
    SensorID id;                       // ID of the sensor
    SensorStatus status;               // Status for the sensor
    uint16_t delay;                    // Delay between samples (in milliseconds)
    uint32_t last_sampled;             // Timestamp of the last sample taken (in milliseconds)
    uint32_t data;                     // Last sensor value recorded
    void (*update)(void **, SensorID); // Function pointer to get_[sensor] functions
} Sensor;

// Structure to hold a single sensor sample
typedef struct
{
    uint16_t millis_offset = 0;    // Millisecond offset from the start of the second
    uint32_t select = 0;           // Bitmask indicating which sensors are present in the sample
    uint16_t num_samples = 0;      // Number of samples taken
    uint8_t data[MAX_SENSOR_DATA]; // Buffer to store sensor data
} Sample;

// Structure to hold a packet of sensor data
typedef struct
{
    uint16_t id = HEADER_ID;            // Packet identifier
    uint32_t unix_seconds = 1698434747; // Unix timestamp of packet creation
    uint16_t num_samples = 0;           // Number of samples in the packet
    uint16_t offset = 0;                // Offset within the packet data
    uint8_t data[MAX_PACKET_DATA];      // Buffer to hold packet data
} Packet;

void setup_sensors(Sensor **sensors);
size_t sample_size(const Sample *, int);
void add_sensor_data(Sample *, int, void *);
void add_sample_data(Packet *, Sample *);

#endif // __SENSORS_H
