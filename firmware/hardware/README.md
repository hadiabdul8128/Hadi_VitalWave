# README.md

## Function Overview
The code consists of functions to initialize sensors, sample sensor data, package it into packets, and transmit it via BLE. Here's a high-level overview of key functionalities:

### Sensor Initialization
- **setup_sampling**: Initializes all sensors and the MAX32664 biohub. 
### Sensor Sampling 
-  **get_status**: Retrieves battery voltage and waypoint status from the button on the Feather and the battery voltage pin.
- **get_temp**: Obtains temperature readings from the BMP280 sensor.
- **get_pressure**: Obtains barometric pressure readings from the BMP280 sensor.
- **get_humidity**: Obtains humidity readings from the SHT31 sensor.
- **get_acc_gyro**: Obtains accelerometer and gyroscope readings from the LSM6DS3TRC sensor.
- **get_magnet**: Obtains magnetometer readings from the LIS3MDL sensor.
- **get_thermistor**: Obtains thermistor readings (to be implemented). - **get_ppg**: Obtains photoplethysmography (PPG) readings from the MAX32664 biohub.
### BLE Communication  
-  **setupBLE**: Configures and starts BLE advertising. 
- **connect_callback**: Callback invoked when a central device connects to the BLE service. 
- **disconnect_callback**: Callback invoked when a connection is dropped. 
- **startAdv**: Configures and starts BLE advertising. 
- **ble_sleep**: Puts the BLE module to sleep by disconnecting existing connections and stopping advertising. 
### Data Logging 
- **add_sensor_data**: Adds sensor data to a sample.
-  **add_sample_data**: Adds sample data to a packet.
-  **send_packet**: Sends a packet via BLE and saves data to the SD card. 

## Changes
### Sensor Sampling
To modify the sampling rates for each sensor: 
1. Locate the `sampling` array in the code. This array holds the sampling rates in milliseconds for each sensor. 
2. Each element in the `sampling` array corresponds to a sensor index. For example, `sampling[0]` corresponds to the status sensor's sampling rate. 
3. To change the sampling rate for a particular sensor, update the value in the corresponding index of the `sampling` array. For instance, to change the sampling rate of the temperature sensor, modify the value of `sampling[2]`. 
4. Testing is required to ensure whether or not the new sampling rates match what is desired. A slightly higher sampling rate might be needed due to the delay in actually sampling the data.


### Adjusting SD Card Saving Rate 
To modify the rate at which data is saved to the SD card: 
1. Locate the `sd_buffer` array and change the size to the desired buffer size. This must be smaller than 32KiB.
2. Locate the `send_packet` function in the code. This function is responsible for saving data to the SD card. Inside the `send_packet` function, there is a conditional statement that checks whether the save count reaches a certain threshold before saving data to the SD card. The threshold is currently set to 132, meaning data will be saved every 132 packets.
 3. To change the saving rate, you can adjust the value of the threshold in the conditional statement. This should be the maximum amount of data that can fit in the `sd_buffer` array divided by 247, rounded down.


