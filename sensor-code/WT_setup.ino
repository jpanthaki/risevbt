#include "BLEDevice.h"

// Replace with your device's MAC address
static BLEAddress imuAddress("38:1e:c7:e4:eb:e8");

// Common WT901 service and characteristic UUIDs
static BLEUUID serviceUUID("0000FFE5-0000-1000-8000-00805F9A34FB");
static BLEUUID charUUID("0000FFE4-0000-1000-8000-00805F9A34FB");

static BLERemoteCharacteristic* pRemoteCharacteristic;
static boolean connected = false;

class MyClientCallback : public BLEClientCallbacks {
  void onConnect(BLEClient* pclient) {
    Serial.println("✅ Connected to WT901BLE67");
  }

  void onDisconnect(BLEClient* pclient) {
    Serial.println("❌ Disconnected.");
    connected = false;
  }
};
#define PACKET_SIZE 11
static int packetCount = 0;

void notifyCallback(
  BLERemoteCharacteristic* p,
  uint8_t* data,
  size_t length,
  bool isNotify
) {
  for (int offset = 0; offset + PACKET_SIZE <= length; offset += PACKET_SIZE) {
    if (data[offset] != 0x55) continue;

    uint8_t* packet = &data[offset];
    int16_t rawX = (packet[3] << 8) | packet[2];
    int16_t rawY = (packet[5] << 8) | packet[4];
    int16_t rawZ = (packet[7] << 8) | packet[6];
    int16_t rawTemp = (packet[9] << 8) | packet[8];

    // Assign fake label based on sequence (loop: ACCEL → GYRO → ANGLE)
    String label;
    float xScaled, yScaled, zScaled;
    String unit;
    
    if (packetCount % 3 == 0) {
      label = "ACCEL";
      xScaled = rawX * 16.0 / 32768.0;
      yScaled = rawY * 16.0 / 32768.0;
      zScaled = rawZ * 16.0 / 32768.0;
      unit = "g";
    } else if (packetCount % 3 == 1) {
      label = "GYRO";
      xScaled = rawX * 2000.0 / 32768.0;
      yScaled = rawY * 2000.0 / 32768.0;
      zScaled = rawZ * 2000.0 / 32768.0;
      unit = "deg/s";
    } else {
      label = "ANGLE";
      xScaled = rawX * 180.0 / 32768.0;
      yScaled = rawY * 180.0 / 32768.0;
      zScaled = rawZ * 180.0 / 32768.0;
      unit = "°";
    }
    packetCount++;

    // Print both raw and scaled
    Serial.print(label); Serial.print(",");
    Serial.print(xScaled, 3); Serial.print(",");
    Serial.print(yScaled, 3); Serial.print(",");
    Serial.print(zScaled, 3); Serial.print(",");
    Serial.print(rawTemp); Serial.print(",");
    Serial.println(unit);
  }
}



void connectToIMU() {
  BLEClient*  pClient  = BLEDevice::createClient();
  pClient->setClientCallbacks(new MyClientCallback());

  if (!pClient->connect(imuAddress)) {
    Serial.println("⚠️ Failed to connect. Retrying...");
    return;
  }

  BLERemoteService* pRemoteService = pClient->getService(serviceUUID);
  if (pRemoteService == nullptr) {
    Serial.println("⚠️ Failed to find service.");
    pClient->disconnect();
    return;
  }

  pRemoteCharacteristic = pRemoteService->getCharacteristic(charUUID);
  if (pRemoteCharacteristic == nullptr) {
    Serial.println("⚠️ Failed to find characteristic.");
    pClient->disconnect();
    return;
  }

  if (pRemoteCharacteristic->canNotify()) {
    pRemoteCharacteristic->registerForNotify(notifyCallback);
    connected = true;
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println("🔍 Starting BLE Client...");
  BLEDevice::init("");
  connectToIMU();
}

void loop() {
  if (!connected) {
    delay(5000);
    connectToIMU();
  }
  delay(100);
}
