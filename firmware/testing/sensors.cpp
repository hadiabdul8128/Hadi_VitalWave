#include "sensors.h"

Adafruit_BMP280 bmp280;       // Temperature, Barometric Pressure
Adafruit_LIS3MDL lis3mdl;     // Magnetometer
Adafruit_LSM6DS3TRC lsm6ds33; // Accelerometer, Gyroscope
Adafruit_SHT31 sht30;         // Humidity
heartrate10_t *max86916;      // PPG sensor

/**
 * Calculates the size of a sample based on the number of data points it contains.
 *
 * @param sample Pointer to the Sample structure.
 * @param count Number of data points in the sample.
 * @return The calculated size of the sample.
 */
size_t sample_size(const Sample *sample, int count)
{
    size_t overhead = sizeof(sample->millis_offset) + sizeof(sample->select);
    size_t data = count << 2;
    return overhead + data;
}

/**
 * Adds sensor data to a sample.
 *
 * @param sample Pointer to the Sample structure.
 * @param sensor Index of the sensor.
 * @param data Pointer to the sensor data.
 */
void add_sensor_data(Sample *sample, int sensor, void *data)
{
    uint32_t flag = 1 << sensor;
    sample->select |= flag; // Use bitwise OR to set the flag

    // Calculate offset based on the number of samples already present
    int offset = 10 + (sample->num_samples << 2); // equivalent to 8 + sample->num_samples * 4

    // Cast sample to uint8_t* for byte-level manipulation
    uint8_t *addr = (uint8_t *)sample + offset;

    // Copy data into the sample buffer
    memcpy(addr, data, sizeof(uint32_t)); // Assuming data size is 4 bytes (uint32_t)

    // Increment the number of samples
    sample->num_samples += 1;
}

/**
 * Adds sample data to a packet.
 *
 * @param packet Pointer to the Packet structure.
 * @param sample Pointer to the Sample structure.
 */
void add_sample_data(Packet *packet, Sample *sample)
{

    // Define starting address
    uint8_t *addr = packet->data + packet->offset;

    // Copy millis_offset
    memcpy(addr, &(sample->millis_offset), sizeof(sample->millis_offset));
    addr += sizeof(sample->millis_offset);

    // Copy select
    memcpy(addr, &(sample->select), sizeof(sample->select));
    addr += sizeof(sample->select);

    // Copy data
    for (int i = 0; i < (sample->num_samples << 2); ++i)
    {
        memcpy(addr, &(sample->data[i]), 1);
        addr += 1;
    }

    // Update offset
    packet->offset = (uint16_t)(addr - packet->data);
    packet->num_samples += 1;

    // Clear sample
    sample->num_samples = 0;
    sample->select = 0;
    for (int i = 0; i < MAX_SENSOR_DATA; i++)
    {
        sample->data[i] = 0;
    }
}

uint32_t float_to_uint32(float f)
{
    return *(uint32_t *)&f;
}

void get_status(void **sensorsptr, SensorID stream)
{
    // Return early if the condition isn't met
    if (stream != STATUS)
        return;

    // Case the sensorptr to the sensors array
    Sensor **sensors = (Sensor **)sensorsptr;

    // Determine battery level
    float measuredvbat = analogRead(BATTERY_PIN);
    measuredvbat *= 2;    // we divided by 2, so multiply back
    measuredvbat *= 3.6;  // Multiply by 3.6V, our reference voltage
    measuredvbat /= 1024; // convert to voltage
    measuredvbat -= 3.2;
    measuredvbat *= 100;

    // Determine waypoint
    uint8_t battery = measuredvbat;
    uint8_t waypoint = digitalRead(EVENT_PIN);

    // Update status by bit shifting
    sensors[STATUS]->data = (battery << 24) | (waypoint << 16);
    sensors[STATUS]->status = SENSOR_OK;
}

void get_temp(void **sensorsptr, SensorID stream)
{
    // Return early if not the correct stream
    if (stream != TEMPERATURE)
        return;

    // Case the sensorptr to the sensors array
    Sensor **sensors = (Sensor **)sensorsptr;

    // Return early if the sensor is unavailable
    // IMPLEMENT ERROR CHECKING HERE

    // Update temperature data as a float
    sensors[TEMPERATURE]->data = float_to_uint32(bmp280.readTemperature());
    sensors[TEMPERATURE]->status = SENSOR_OK;
}

void get_pressure(void **sensorsptr, SensorID stream)
{
    // Return early if not the correct stream
    if (stream != PRESSURE)
        return;

    // Case the sensorptr to the sensors array
    Sensor **sensors = (Sensor **)sensorsptr;

    // Return early if the sensor is unavailable
    // IMPLEMENT ERROR CHECKING HERE

    // Update pressure data as a float
    sensors[PRESSURE]->data = float_to_uint32(bmp280.readPressure());
    sensors[PRESSURE]->status = SENSOR_OK;
}

void get_humidity(void **sensorsptr, SensorID stream)
{
    // Return early if not the correct stream
    if (stream != HUMIDITY)
        return;

    // Case the sensorptr to the sensors array
    Sensor **sensors = (Sensor **)sensorsptr;

    // Return early if the sensor is unavailable
    // IMPLEMENT ERROR CHECKING HERE

    // Update humidity data as a float
    sensors[HUMIDITY]->data = float_to_uint32(sht30.readHumidity());
    sensors[HUMIDITY]->status = SENSOR_OK;
}

void get_magnet(void **sensorsptr, SensorID stream)
{
    // Return early if not the correct stream
    if (stream != MAGNETIC_X)
        return;

    // Case the sensorptr to the sensors array
    Sensor **sensors = (Sensor **)sensorsptr;

    // Return early if the sensor is unavailable
    // IMPLEMENT ERROR CHECKING HERE

    // Update magnetometer data
    lis3mdl.read();
    sensors[MAGNETIC_X]->data = float_to_uint32(lis3mdl.x);
    sensors[MAGNETIC_Y]->data = float_to_uint32(lis3mdl.y);
    sensors[MAGNETIC_Z]->data = float_to_uint32(lis3mdl.z);
    sensors[MAGNETIC_X]->status = SENSOR_OK;
    sensors[MAGNETIC_Y]->status = SENSOR_OK;
    sensors[MAGNETIC_Z]->status = SENSOR_OK;
}

void get_acc_gyro(void **sensorsptr, SensorID stream)
{
    // Return early if not the correct stream
    if (stream != ACCEL_X)
        return;

    // Case the sensorptr to the sensors array
    Sensor **sensors = (Sensor **)sensorsptr;

    // Return early if the sensor is unavailable
    // IMPLEMENT ERROR CHECKING HERE

    // Update accelerometer and gyroscope data
    sensors_event_t accel;
    sensors_event_t gyro;
    sensors_event_t temp;
    lsm6ds33.getEvent(&accel, &gyro, &temp);
    sensors[ACCEL_X]->data = float_to_uint32(accel.acceleration.x);
    sensors[ACCEL_Y]->data = float_to_uint32(accel.acceleration.y);
    sensors[ACCEL_Z]->data = float_to_uint32(accel.acceleration.z);
    sensors[GYRO_X]->data = float_to_uint32(gyro.gyro.x);
    sensors[GYRO_Y]->data = float_to_uint32(gyro.gyro.y);
    sensors[GYRO_Z]->data = float_to_uint32(gyro.gyro.z);
    sensors[TEMPERATURE]->data = float_to_uint32(temp.temperature);

    // Update Sensor status to OK
    sensors[ACCEL_X]->status = SENSOR_OK;
    sensors[ACCEL_Y]->status = SENSOR_OK;
    sensors[ACCEL_Z]->status = SENSOR_OK;
    sensors[GYRO_X]->status = SENSOR_OK;
    sensors[GYRO_Y]->status = SENSOR_OK;
    sensors[GYRO_Z]->status = SENSOR_OK;
    sensors[TEMPERATURE]->status = SENSOR_OK;
}

void get_thermistor(void **sensorsptr, SensorID stream)
{
    // Return early if not the correct stream
    if (stream != THERMISTOR)
        return;

    // Case the sensorptr to the sensors array
    Sensor **sensors = (Sensor **)sensorsptr;

    // Update thermistor data and indicate it is unavailable
    sensors[THERMISTOR]->status = SENSOR_UNAVAILABLE;
    sensors[THERMISTOR]->data = 255;
}

void get_ppg(void **sensorsptr, SensorID stream)
{
    // Return early if not the correct stream
    if (stream != PPG_R)
        return;

    // Case the sensorptr to the sensors array
    Sensor **sensors = (Sensor **)sensorsptr;

    // Return early if the sensor is unavailable
    // IMPLEMENT ERROR CHECKING HERE

    // Read PPG data
    int8_t rd_dat = 0;
    heartrate10_generic_read(max86916, HEARTRATE10_REG_INT_STATUS, (uint8_t *)&rd_dat);
    if (rd_dat & 0x40)
    {
        heartrate10_read_complete_fifo_data(max86916, &sensors[PPG_IR]->data, &sensors[PPG_R]->data, &sensors[PPG_G]->data, &sensors[PPG_B]->data);
        sensors[PPG_R]->status = SENSOR_OK;
        sensors[PPG_IR]->status = SENSOR_OK;
        sensors[PPG_G]->status = SENSOR_OK;
        sensors[PPG_B]->status = SENSOR_OK;
        Serial.println(String(sensors[PPG_IR]->data) + "," + String(sensors[PPG_R]->data) + "," + String(sensors[PPG_G]->data) + "," + String(sensors[PPG_B]->data));
    }
    else
    {
        sensors[PPG_R]->status = SENSOR_BUSY;
        sensors[PPG_IR]->status = SENSOR_BUSY;
        sensors[PPG_G]->status = SENSOR_BUSY;
        sensors[PPG_B]->status = SENSOR_BUSY;
    }
}

void init_sensor(Sensor **sensors, SensorID id, uint16_t msdelay, void (*callback)(void **, SensorID))
{
    sensors[id]->id = id;
    sensors[id]->status = SENSOR_OK;
    sensors[id]->delay = msdelay;
    sensors[id]->last_sampled = 0;
    sensors[id]->data = 0;
    sensors[id]->update = callback;
}

void setup_sensors(Sensor **sensors)
{
    // Set up the sensor objects

    delay(1000);

    bmp280.begin();
    delay(50);
    lis3mdl.begin_I2C();
    delay(50);
    lsm6ds33.begin_I2C();
    delay(50);
    sht30.begin();
    delay(50);
    max86916 = heartrate10_init(PPG_INT_PIN);
    if (HEARTRATE10_ERROR == heartrate10_default_cfg(max86916))
    {
        Serial.println("Error with MAX86916, reporting -1s for PPG ");
    }
    delay(50);

    // Initialize all sensors with appropriate sampling rates and callbacks
    init_sensor(sensors, STATUS, 1000, get_status);
    init_sensor(sensors, THERMISTOR, 1000, get_thermistor);
    init_sensor(sensors, TEMPERATURE, 1000, get_acc_gyro);
    init_sensor(sensors, PRESSURE, 1000, get_pressure);
    init_sensor(sensors, HUMIDITY, 1000, get_humidity);
    init_sensor(sensors, GYRO_X, 40, get_acc_gyro);
    init_sensor(sensors, GYRO_Y, 40, get_acc_gyro);
    init_sensor(sensors, GYRO_Z, 40, get_acc_gyro);
    init_sensor(sensors, MAGNETIC_X, 1000, get_magnet);
    init_sensor(sensors, MAGNETIC_Y, 1000, get_magnet);
    init_sensor(sensors, MAGNETIC_Z, 1000, get_magnet);
    init_sensor(sensors, ACCEL_X, 10, get_acc_gyro);
    init_sensor(sensors, ACCEL_Y, 10, get_acc_gyro);
    init_sensor(sensors, ACCEL_Z, 10, get_acc_gyro);
    init_sensor(sensors, PPG_R, 5, get_ppg);
    init_sensor(sensors, PPG_B, 5, get_ppg);
    init_sensor(sensors, PPG_IR, 5, get_ppg);
    init_sensor(sensors, PPG_G, 5, get_ppg);
}