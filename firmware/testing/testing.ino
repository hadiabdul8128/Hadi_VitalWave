#include <Adafruit_TinyUSB.h>
#include <InternalFileSystem.h>
#include <SD.h>
#include <SPI.h>
#include <Wire.h>
#include <bluefruit.h>
#include "sensors.h"

// Sensor data
Sample curr_sample;           // Current sensor sample
Packet curr_packet;           // Current packet of sensor data
Sensor sensors[SENSOR_COUNT]; // Array of sensors
bool is_on;
int prev_mod;

// SD Card
char sd_buffer[32604];
int save_count;
File dataFile;

// BLE UART Service.
BLEUart bleuart;
void startAdv();
void connect_callback(uint16_t conn_handle);
void disconnect_callback(uint16_t conn_handle, uint8_t reason);
uint32_t start_unix = 1698434747;

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
 * Sends a packet to via BLE.
 * Prints the Hex to the serial monitor.
 * Saves data to the SD card.
 *
 * @param packet Pointer to the Packet structure.
 */
void send_packet(Packet *packet)
{
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
  Serial.print("Packet: ");
  for (int i = 0; i < MAX_BLE_DATA; ++i)
  {
    print_hex(buffer[i]);
  }
  Serial.println("");
  bleuart.write((char *)buffer, 247);
  /*
  if (save_count == 132){
    appendFile(sd_buffer);
    save_count = 0;
  }
  */

  packet->num_samples = 0;
  packet->offset = 0; // Assuming the offset starts at 10 based on your code
  packet->unix_seconds = start_unix + millis() / 1000;
  for (int i = 0; i < MAX_PACKET_DATA; i++)
  {
    packet->data[i] = 0;
  }
}

/**
 * Appends data to a file on the SD card.
 *
 * @param data Pointer to the data to be appended.
 */
void appendFile(char *data)
{

  dataFile = SD.open("record", FILE_WRITE);
  // if the file is available, write to it:
  if (dataFile)
  {
    dataFile.print(data);
    // print to the serial port too:
    Serial.println("Saved");
  }
  // if the file isn't open, pop up an error:
  else
  {
    Serial.println("error opening ");
  }
}

/**
 * Ardunio setup function
 */
void setup()
{
  Serial.begin(115200);
  setupBLE();
  delay(100);
  SPI.begin();
  Wire.begin();
  delay(100);

  // checkSD();
  setup_sensors((Sensor **)&sensors);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  is_on = digitalRead(BUTTON_PIN) != HIGH;
}

/**
 * Ardunio loop function
 */
void loop()
{
  // Flags packet was not sent
  bool sent = false;

  // Executes this when the button is turned off
  if (digitalRead(BUTTON_PIN) == HIGH) {
    if (is_on){
      ble_sleep();
      is_on = false;
      Serial.println("turned off");
      //max32664.EnableSensor(false);
      //dataFile.close();
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
  if (isValidStartUnix()){
    Serial.println("Valid Time");
  } else if (bleuart.available()) {
    start_unix = bleuart.read32() - millis() / 1000;
    Serial.println("Received unix time");
  } 
  else { return; }

  Serial.println(start_unix);

  // Determine which values are sampled, using the start millis as the referencw
  long curr = millis();
  int samples = 0;
  for (int i = 0; i < SENSOR_COUNT; i++)
  {
    if (curr - sensors[i].last_sampled > sensors[i].delay)
      samples++;
  }

  // Determine whether or not to send the packet
  int mod = curr % 1000;
  if (curr_packet.offset + sample_size(&curr_sample, samples) > MAX_PACKET_DATA || prev_mod > mod)
  {
    send_packet(&curr_packet);
    sent = true;
  }
  prev_mod = mod;

  // Loop to sample all of the sensors, if the requsite time has passed
  curr_sample.millis_offset = millis() % 1000;

  // Loop to sample all of the sensors, if the requsite time has passed
  for (int i = 0; i < SENSOR_COUNT; i++)
  {
    if (curr - sensors[i].last_sampled > sensors[i].delay)
    {
      sensors[i].update((void **)&sensors, sensors[i].id);
      sensors[i].last_sampled = curr;
      add_sensor_data(&curr_sample, i, &sensors[i].data);
    }
  }
  add_sample_data(&curr_packet, &curr_sample);
}