#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLEAdvertising.h>
#include <BLE2902.h>
#include <Arduino.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BNO055.h>
#include <Wire.h>

// UUIDs
#define SERVICE_UUID           "7c961cfd-2527-4808-a9b0-9ce954427712"
#define DATA_CHARACTERISTIC_UUID    "207a2a33-ab38-4748-8702-5ff50b2d673f"
#define MCV_CHARACTERISTIC_UUID     "54a598af-dc7a-4398-be14-69e04c9b41ef"
#define COMMAND_CHARACTERISTIC_UUID "1c902c8d-88bb-44f9-9dea-0bc5bf2d0af4"

// Sampling and BLE
#define SAMPLE_INTERVAL_MS 50
#define CHUNK_SIZE 20
#define PACKET_QUEUE_LENGTH 10

float Vx, Vy, Vz;
float initVx, initVy, initVz = 0;
unsigned long millisOld;
unsigned long time1;
float dt;

// BLE
BLECharacteristic* dataChar;
BLECharacteristic* mcvChar;
BLECharacteristic* commandChar;
BLEServer* pServer;
QueueHandle_t dataQueue;

// Flags
volatile bool deviceConnected = false;
volatile bool sendData = false;

// Sensor
Adafruit_BNO055 bno = Adafruit_BNO055(55);

// Struct for packed IMU data
struct __attribute__((packed)) SensorPacket {
  uint16_t dt_ms;
  int16_t velocity;
  int16_t accel;
  int16_t pitch;
  int16_t yaw;
};

// BLE callbacks
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) { deviceConnected = true; }
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    BLEDevice::startAdvertising();
  }
};

class MyCommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    String value = pCharacteristic->getValue().c_str();
    if (value == "start") {
      sendData = true;
      Serial.println("✅ Start command received.");
    } else if (value == "stop") {
      sendData = false;
      Serial.println("🛑 Stop command received.");
    }
  }
};

// Sampling task
void samplingTask(void* parameter) {
  SensorPacket pkt;
  uint32_t lastMillis = millis();

  while (true) {
    if (sendData && deviceConnected) {
      imu::Vector<3> acc = bno.getVector(Adafruit_BNO055::VECTOR_LINEARACCEL);
      imu::Vector<3> euler = bno.getVector(Adafruit_BNO055::VECTOR_EULER);

      dt = (millis() - millisOld) / 1000.; 
      millisOld = millis();
      time1 = millisOld / 1000;
      Vy = initVy + acc.y() * dt;

      pkt.dt_ms = SAMPLE_INTERVAL_MS;
      pkt.velocity = Vy * 1000;  // scale velocity
      pkt.accel = acc.y() * 100;
      pkt.pitch = euler.y() * 100;
      pkt.yaw = euler.z() * 100;

      xQueueSend(dataQueue, &pkt, portMAX_DELAY);
    }

    vTaskDelay(pdMS_TO_TICKS(SAMPLE_INTERVAL_MS));
  }
}

// MCV sending task
void meanTask(void* parameter) {
  while (true) {
    if (sendData && deviceConnected) {
      SensorPacket pkt;
      int32_t sum = 0;
      int count = 0;

      for (int i = 0; i < 60; ++i) {
        if (xQueueReceive(dataQueue, &pkt, pdMS_TO_TICKS(10))) {
          sum += pkt.velocity;
          count++;
        }
      }

      if (count > 0) {
        int16_t meanVelocity = sum / count;
        mcvChar->setValue((uint8_t*)&meanVelocity, sizeof(meanVelocity));
        mcvChar->notify();
        Serial.printf("📤 Sent MCV: %d\n", meanVelocity);
      }
    }

    vTaskDelay(pdMS_TO_TICKS(3000));
  }
}

// BLE packet streaming
void bleTask(void* parameter) {
  SensorPacket pkt;

  uint8_t sys, gyroCalib, accelCalib, magCalib;
  bno.getCalibration(&sys, &gyroCalib, &accelCalib, &magCalib);

  while (true) {
    if (sendData && deviceConnected && xQueueReceive(dataQueue, &pkt, portMAX_DELAY)) {
      dataChar->setValue((uint8_t*)&pkt, sizeof(pkt));
      dataChar->notify();

      Serial.printf("📤 Sent IMU packet | dt: %dms | vel: %.3f | acc: %.2f | pitch: %.2f | yaw: %.2f\n | Calib Sys: %d | Calib Acc: %d | Calib Gyro: %d | Calib Mag: %d",
        pkt.dt_ms,
        pkt.velocity / 1000.0,
        pkt.accel / 100.0,
        pkt.pitch / 100.0,
        pkt.yaw / 100.0, 
        sys, accelCalib, gyroCalib, magCalib
      );
    }

    vTaskDelay(pdMS_TO_TICKS(10));
  }
}


void setup() {
  Serial.begin(115200);
  while (!Serial);
  Serial.println("Booting...");

  if (!bno.begin()) {
    Serial.println("BNO055 not detected!");
    while (1);
  }

  bno.setExtCrystalUse(true);

  BLEDevice::init("sheeeeeed");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);

  dataChar = pService->createCharacteristic(
    DATA_CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  dataChar->addDescriptor(new BLE2902());

  mcvChar = pService->createCharacteristic(
    MCV_CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  mcvChar->addDescriptor(new BLE2902());

  commandChar = pService->createCharacteristic(
    COMMAND_CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  commandChar->setCallbacks(new MyCommandCallbacks());

  pService->start();

  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  BLEDevice::startAdvertising();

  Serial.println("✅ Ready and advertising...");

  dataQueue = xQueueCreate(PACKET_QUEUE_LENGTH, sizeof(SensorPacket));
  if (dataQueue == NULL) {
    Serial.println("❌ Failed to create data queue.");
    while (1);
  }

  xTaskCreatePinnedToCore(samplingTask, "Sampling Task", 4096, NULL, 2, NULL, 1);
  xTaskCreatePinnedToCore(meanTask, "Mean Task", 2048, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(bleTask, "BLE Task", 4096, NULL, 1, NULL, 1);
}

void loop() {
  // Nothing here
}
