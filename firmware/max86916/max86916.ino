#include "heartrate10.h"
#include <Adafruit_TinyUSB.h>
#include <Wire.h>
#include <bluefruit.h>

#define PPG_INT_PIN 6

heartrate10_t *heartrate10;
long prev;

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

void setup()
{
  Serial.begin(115200);
  Wire.begin();
  setupBLE();

  delay(5000);
  Serial.println("Begin");
 
  heartrate10 = heartrate10_init(PPG_INT_PIN);
  while (HEARTRATE10_ERROR == heartrate10_default_cfg(heartrate10))
  {
    Serial.println("Error init with default config ");
    delay(100);
  }
  prev = millis();
}

void loop()
{
  if (millis() - prev < 10)
    return;
  int8_t rd_dat = 0;
  heartrate10_generic_read(heartrate10, HEARTRATE10_REG_INT_STATUS, (uint8_t *)&rd_dat);
  if ((rd_dat & 0x40))
  {
    uint32_t ir, red, green, blue = 0;
    heartrate10_read_complete_fifo_data(heartrate10, &ir, &red, &green, &blue);
    Serial.println("I:" + String(ir) + ", R:" + String(red) + ", G:" + String(green) + ", B:" + String(blue));
    bleuart.println("I:" + String(ir) + ", R:" + String(red) + ", G:" + String(green) + ", B:" + String(blue));
    prev = millis();
  }
}
