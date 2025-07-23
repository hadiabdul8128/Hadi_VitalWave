#include <Adafruit_BMP280.h>
#include <Adafruit_LIS3MDL.h>
#include <Adafruit_LSM6DS3TRC.h>
#include <Adafruit_LittleFS.h>
#include <Adafruit_SHT31.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_TinyUSB.h>
#include <InternalFileSystem.h>
#include <SD.h>
#include <SPI.h>
#include <Wire.h>
#include <bluefruit.h>
#include <math.h>
#include "heartrate10.h"

// Define constants
#define MAX_SENSOR 18
#define MAX_SENSOR_DATA MAX_SENSOR << 2
#define MAX_BLE_DATA 247
#define MAX_PACKET_DATA MAX_BLE_DATA - 8
#define HEADER_ID 0xABAB

// Define Pinouts
#define VBATPIN A6
#define EVENT_PIN 7
#define INT_PIN 6 
#define SD_CS 10
#define BUTTON A0

// Declare sensor objects
Adafruit_BMP280 bmp280;      // temperature, barometric pressure
Adafruit_LIS3MDL lis3mdl;    // magnetometer
Adafruit_LSM6DS3TRC lsm6ds33;  // accelerometer, gyroscope
Adafruit_SHT31 sht30;        // humidity
heartrate10_t *heartrate10;
int hr_not_en = 0;

// Buffer for SD card
File dataFile;
char sd_buffer[32604];
int prev_mod, save_count;

// Declare variables to hold sensor readings
float temperature, pressure;
float magnetic_x, magnetic_y, magnetic_z;
float accel_x, accel_y, accel_z;
float gyro_x, gyro_y, gyro_z;
float humidity;
uint32_t thermistor, ppg_r, ppg_g, ppg_b, ppg_ir, status;

bool is_on; // Flag to determine whether the device is on

// Unix timestamp when sampling started
// Current time represents a time in the past before web server was active
uint32_t start_unix = 1698434747;

// Structure to hold a single sensor sample
typedef struct {
  uint16_t millis_offset = 0;     // Millisecond offset from the start of the second
  uint32_t select = 0;            // Bitmask indicating which sensors are present in the sample
  uint16_t num_samples = 0;       // Number of samples taken
  uint8_t data[MAX_SENSOR_DATA];  // Buffer to store sensor data
} Sample;

Sample curr_sample;  // Current sensor sample

// Structure to hold a packet of sensor data
typedef struct {
  uint16_t id = HEADER_ID;             // Packet identifier
  uint32_t unix_seconds = 1698434747;  // Unix timestamp of packet creation
  uint16_t num_samples = 0;            // Number of samples in the packet
  uint16_t offset = 0;                 // Offset within the packet data
  uint8_t data[MAX_PACKET_DATA];       // Buffer to hold packet data
} Packet;

Packet curr_packet;  // Current packet of sensor data

// Array to store sampling rates for each sensor
uint16_t sampling[] = {1000, 1000, 1000, 1000, 1000, 40, 40, 40, 40, 40, 40, 10, 10, 10, 10, 10, 10, 10};

long prev[MAX_SENSOR] = {};  // Array to store previous sampling times for each sensor

// Function to convert sampling rate from milliseconds to ticks
int to_milli(uint8_t rate) { return rate << 2; }

// Function to convert ticks to samples
uint8_t to_sample(int milli) { return milli >> 2; }

// BLE UART Service.
BLEUart bleuart;
void startAdv();
void connect_callback(uint16_t conn_handle);
void disconnect_callback(uint16_t conn_handle, uint8_t reason);

/**
 * Initializes and configures the BLE service for communication over Bluetooth.
 */
void setupBLE() {
  // Setup the BLE LED to be enabled on CONNECT
  // Note: This is actually the default behavior, but provided
  // here in case you want to control this LED manually via PIN 19
  Bluefruit.autoConnLed(true);

  // Config the peripheral connection with maximum bandwidth
  // more SRAM required by SoftDevice
  // Note: All config***() function must be called before begin()
  Bluefruit.configPrphBandwidth(BANDWIDTH_MAX);

  Bluefruit.begin();
  Bluefruit.setTxPower(8);  // Check bluefruit.h for supported values

  Bluefruit.Periph.setConnectCallback(connect_callback);
  Bluefruit.Periph.setDisconnectCallback(disconnect_callback);
  Bluefruit.setName("Ritvik Bass Wearable");

  bleuart.begin();

  // Set up and start advertising
  startAdv();
}

/**
 * Callback invoked when a central device connects to the BLE service.
 * @param conn_handle Connection handle of the central device.
 */
void connect_callback(uint16_t conn_handle) {
  // Get the reference to current connection
  BLEConnection *connection = Bluefruit.Connection(conn_handle);

  char central_name[32] = {0};
  connection->getPeerName(central_name, sizeof(central_name));

  Serial.print("Connected to ");
  Serial.println(central_name);
}

/**
 * Callback invoked when a connection is dropped.
 * @param conn_handle Connection handle where this event happens.
 * @param reason BLE_HCI_STATUS_CODE indicating the reason for disconnection.
 */
void disconnect_callback(uint16_t conn_handle, uint8_t reason) {
  (void)conn_handle;
  (void)reason;
  startAdv();
}

/**
 * Configures and starts BLE advertising.
 *
 * The function sets up the advertising packet, including flags, transmission power,
 * and the BLE UART service. It also adds a secondary scan response packet for the device name.
 * The advertising interval is set to recommended values for compatibility.
 *
 * @note The function enables auto advertising if disconnected and restarts advertising on disconnection.
 */
void startAdv() {
  // Advertising packet
  Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE);
  Bluefruit.Advertising.addTxPower();

  // Include bleuart 128-bit uuid
  Bluefruit.Advertising.addService(bleuart);
  // Serial.println(bleuart.uuid.toString());

  // Secondary Scan Response packet (optional)
  // Since there is no room for 'Name' in Advertising packet
  Bluefruit.ScanResponse.addName();

  /* Start Advertising
   * - Enable auto advertising if disconnected
   * - Interval:  fast mode = 20 ms, slow mode = 152.5 ms
   * - Timeout for fast mode is 30 seconds
   * - Start(timeout) with timeout = 0 will advertise forever (until connected)
   *
   * For recommended advertising interval
   * https://developer.apple.com/library/content/qa/qa1931/_index.html
   */
  Bluefruit.Advertising.restartOnDisconnect(true);
  Bluefruit.Advertising.setInterval(32, 244);  // in unit of 0.625 ms
  Bluefruit.Advertising.setFastTimeout(30);    // number of seconds in fast mode
  Bluefruit.Advertising.start(0);              // 0 = Don't stop advertising after n seconds
}

/**
 * Initializes all of the sensors on the device
 */
void setup_sampling() {
  
  // Sets the most recently sampled time as the current time
  for (int i = 0; i < MAX_SENSOR; i++) {
    prev[i] = millis();
  }

  // Begin communication with all onboard sensors
  Wire.begin();
  bmp280.begin();
  lis3mdl.begin_I2C();
  lsm6ds33.begin_I2C();
  sht30.begin();

  // Initialize the ppg
  heartrate10 = heartrate10_init(INT_PIN);
  if ( HEARTRATE10_ERROR == heartrate10_default_cfg ( heartrate10 ) ) 
  {
    Serial.println("Error with MAX86916, reporting -1s for PPG ");
    hr_not_en = -1;
  }
}

/**
 * Computes the values for a status sample and places it in `status`
 */
void get_status() {
  float measuredvbat = analogRead(VBATPIN);
  measuredvbat *= 2;     // we divided by 2, so multiply back
  measuredvbat *= 3.6;   // Multiply by 3.6V, our reference voltage
  measuredvbat /= 1024;  // convert to voltage
  measuredvbat -= 3.2;
  measuredvbat *= 100;
  uint8_t battery = measuredvbat;
  uint8_t waypoint = digitalRead(EVENT_PIN);
  status = (battery << 24) | (waypoint << 16);
}

/**
 * Obtains the values for a temperature sample and places it in `temperature`
 */
void get_temp() { temperature = bmp280.readTemperature(); }

/**
 * Obtains the values for a pressure sample and places it in `pressure`
 */
void get_pressure() { pressure = bmp280.readPressure(); }

/**
 * Obtains the values for a humidity sample and places it in `humidity`
 */
void get_humidity() { humidity = sht30.readHumidity(); }

/**
 * Obtains the values for the magnetometer samples and places 
 * it in `magnetic_x`, `magnetic_y`, or `magnetic_z`
 */
void get_magnet() {
  lis3mdl.read();
  magnetic_x = lis3mdl.x;
  magnetic_y = lis3mdl.y;
  magnetic_z = lis3mdl.z;
}

/**
 * Obtains the values for the accelerometer and gyroscope samples and places 
 * it in `accel_x`, `accel_y`, `accel_z`, `gyro_x`, `gyro_y`, and `gyro_z`,
 */
void get_acc_gyro() {
  sensors_event_t accel;
  sensors_event_t gyro;
  sensors_event_t temp;
  lsm6ds33.getEvent(&accel, &gyro, &temp);
  accel_x = accel.acceleration.x;
  accel_y = accel.acceleration.y;
  accel_z = accel.acceleration.z;
  gyro_x = gyro.gyro.x;
  gyro_y = gyro.gyro.y;
  gyro_z = gyro.gyro.z;
}

/**
 * Obtains the values for the therminstor sample and places it in `thermistor`.
 * Currently hardcoded to 255. To be implemented when the ThermaSENSE sensor is integrated.
 */
void get_thermistor() { thermistor = 255; }

/**
 * Obtains the values for a ppg sample and places it in `ppg_r`, `ppg_g`,
 * `ppg_b`, and `ppg_ir` is successful. 
 */
void get_ppg() {
  if (hr_not_en < 0){
    ppg_ir = -1;
    ppg_r = -1;
    ppg_g = -1;
    ppg_b = -1;
  }
  int8_t rd_dat = 0;
  heartrate10_generic_read( heartrate10, HEARTRATE10_REG_INT_STATUS, (uint8_t*) &rd_dat );
  if ((rd_dat & 0x40))       
    heartrate10_read_complete_fifo_data( heartrate10, &ppg_ir, &ppg_r, &ppg_g, &ppg_b );
    Serial.println("IR:"+String(ppg_ir)+"R:"+String(ppg_r)+"G:"+String(ppg_g)+"B:"+String(ppg_b));
}

/**
 * Calculates the size of a sample based on the number of data points it contains.
 * 
 * @param sample Pointer to the Sample structure.
 * @param count Number of data points in the sample.
 * @return The calculated size of the sample.
 */
size_t sample_size(const Sample *sample, int count) {
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
void add_sensor_data(Sample *sample, int sensor, void *data) {
  uint32_t flag = 1 << sensor;
  sample->select |= flag;  // Use bitwise OR to set the flag

  // Calculate offset based on the number of samples already present
  int offset = 10 + (sample->num_samples << 2);  // equivalent to 8 + sample->num_samples * 4

  // Cast sample to uint8_t* for byte-level manipulation
  uint8_t *addr = (uint8_t *)sample + offset;

  // Copy data into the sample buffer
  memcpy(addr, data, sizeof(uint32_t));  // Assuming data size is 4 bytes (uint32_t)

  // Increment the number of samples
  sample->num_samples += 1;
}

/**
 * Adds sample data to a packet.
 * 
 * @param packet Pointer to the Packet structure.
 * @param sample Pointer to the Sample structure.
 */
void add_sample_data(Packet *packet, Sample *sample) {

  // Define starting address
  uint8_t *addr = packet->data + packet->offset;

  // Copy millis_offset
  memcpy(addr, &(sample->millis_offset), sizeof(sample->millis_offset));
  addr += sizeof(sample->millis_offset);

  // Copy select
  memcpy(addr, &(sample->select), sizeof(sample->select));
  addr += sizeof(sample->select);

  // Copy data
  for (int i = 0; i < (sample->num_samples << 2); ++i) {
    memcpy(addr, &(sample->data[i]), 1);
    addr += 1;
  }

  // Update offset
  packet->offset = (uint16_t)(addr - packet->data);
  packet->num_samples += 1;

  // Clear sample
  sample->num_samples = 0;
  sample->select = 0;
  for (int i = 0; i < MAX_SENSOR_DATA; i++) {
    sample->data[i] = 0;
  }
}

/**
 * Sends a packet to via BLE. 
 * Prints the Hex to the serial monitor.
 * Saves data to the SD card.
 * 
 * @param packet Pointer to the Packet structure.
 */
void send_packet(Packet *packet) {
  uint8_t buffer[MAX_BLE_DATA];

  // Copy relevent parts of packet to buffer
  memcpy(buffer, &(packet->id), 2);
  memcpy(buffer + 2, &(packet->unix_seconds), 4);
  memcpy(buffer + 6, &(packet->num_samples), 2);
  memcpy(buffer + 8, packet->data, MAX_PACKET_DATA);

  /*
  // Add to the SD buffer
  memcpy(sd_buffer + (MAX_BLE_DATA * save_count), buffer, MAX_BLE_DATA);
  save_count++;
  */

  // Print Packet Hex
  // Serial.print("Packet: ");
  // for (int i = 0; i < MAX_BLE_DATA; ++i) {
  //   print_hex(buffer[i]);
  // }
  // Serial.println("");
  bleuart.write((char *) buffer, 247);
  /*
  if (save_count == 132){
    appendFile(sd_buffer);
    save_count = 0;
  }
  */
  
  packet->num_samples = 0;
  packet->offset = 0;  // Assuming the offset starts at 10 based on your code
  packet->unix_seconds = start_unix + millis() / 1000;
  for (int i = 0; i < MAX_PACKET_DATA; i++) {
    packet->data[i] = 0;
  }
}

/**
 * Appends data to a file on the SD card.
 * 
 * @param data Pointer to the data to be appended.
 */
void appendFile(char *data) {

  dataFile = SD.open("record", FILE_WRITE);
  // if the file is available, write to it:
  if (dataFile) {
    dataFile.print(data);
    // print to the serial port too:
    Serial.println("Saved");
  }
  // if the file isn't open, pop up an error:
  else {
    Serial.println("error opening ");
  }
}

/**
 * Ensures the SD card is inserted
 */
void checkSD() {
  SD.begin(SD_CS);
  delay(500);
  Serial.println("card initialized.");
}

/**
 * Puts the BLE module to sleep by disconnecting existing connections and stopping advertising.
 */
void ble_sleep(void) {
  Bluefruit.Advertising.restartOnDisconnect(false);
  uint16_t connections = Bluefruit.connected();
  for (uint16_t conn = 0; conn < connections; conn++) {
    Bluefruit.disconnect(conn);
  }
  Bluefruit.Advertising.stop();
}

/**
 * Checks if the start_unix time is within valid bounds.
 * 
 * @return True if the start_unix time is within valid bounds, false otherwise.
 */
bool isValidStartUnix() {
  return start_unix > 1698434747      // October 27, 2023 7:25:47 PM
         && start_unix < 2524607999;  // December 31, 2049 11:59:59 PM
}

/**
 * Prints a hexadecimal representation of a byte.
 * 
 * @param hex The byte to be printed in hexadecimal format.
 */
void print_hex(uint8_t hex) {
  if (hex < 0x10) {
    Serial.print('0');
  }
  Serial.print(hex, HEX);
}

/**
 * Ardunio setup function
 */
void setup() {
  Serial.begin(115200);
  SPI.begin();
  setupBLE();
  //checkSD();
  setup_sampling();
  pinMode(BUTTON, INPUT_PULLUP);
  is_on = digitalRead(BUTTON) != HIGH;
}



/**
 * Ardunio loop function
 */
void loop() {
  
  // Flags packet was not sent
  bool sent = false;

  // Executes this when the button is turned off
  if (digitalRead(BUTTON) == HIGH) {
    if (is_on){
      ble_sleep();
      is_on = false;
      Serial.println("turned off");
      //max32664.EnableSensor(false);
      dataFile.close();
    }
    delay(100);
    return;
  }

  // If function is not returned, then the button is on
  // Turns on the device
  is_on = true;
  startAdv();
  //max32664.EnableSensor(true);

  // Checks whether the time is valid
  if (bleuart.available() && !isValidStartUnix()) {
    start_unix = bleuart.read32() - millis() / 1000;
    Serial.println("Received unix time");
  } 
  if (!isValidStartUnix()) { return; }

  // Determine which values are sampled, using the start millis as the referencw
  long curr = millis();
  int samples = 0;
  for (int i = 0; i < MAX_SENSOR; i++) {
    if (curr - prev[i] > sampling[i]) {
      samples++;
    }
  }

  // Determine whether or not to send the packet
  int mod = curr % 1000;
  if (curr_packet.offset + sample_size(&curr_sample, samples) > MAX_PACKET_DATA || prev_mod > mod) {
    send_packet(&curr_packet);
    sent = true;
  }
  prev_mod = mod;

  // Loop to sample all of the sensors, if the requsite time has passed
  curr_sample.millis_offset = millis() % 1000;
  
  // Loop to sample all of the sensors, if the requsite time has passed
  for (int i = 0; i < MAX_SENSOR; i++) {
    if (curr - prev[i] > sampling[i]) {
      // Sample the sensors
      switch (i) {
        case 0: get_status(); break;
        case 1: get_thermistor(); break;
        case 2: get_temp(); break;
        case 3: get_pressure(); break;
        case 4: get_humidity(); break;
        case 8: get_magnet(); break;
        case 11: get_acc_gyro(); break;
        case 14: get_ppg(); break;
        default: break;
      }
      void *addr;
      // Sample the sensors
      switch (i) {
        case 0: addr = &status; break;
        case 1: addr = &thermistor; break;
        case 2: addr = &temperature; break;
        case 3: addr = &pressure; break;
        case 4: addr = &humidity; break;
        case 5: addr = &gyro_x; break;
        case 6: addr = &gyro_y; break;
        case 7: addr = &gyro_z; break;
        case 8: addr = &magnetic_x; break;
        case 9: addr = &magnetic_y; break;
        case 10: addr = &magnetic_z; break;
        case 11: addr = &accel_x; break;
        case 12: addr = &accel_y; break;
        case 13: addr = &accel_z; break;
        // case 14: addr = &ppg_r; break;
        // case 15: addr = &ppg_b; break;
        // case 16: addr = &ppg_ir; break;
        // case 17: addr = &ppg_g; break;
        default: break;
      }
      prev[i] = curr;
      add_sensor_data(&curr_sample, i, addr);
    }
  }
  add_sample_data(&curr_packet, &curr_sample);
}