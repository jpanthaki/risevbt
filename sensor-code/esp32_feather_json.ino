
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

#define SAMPLE_INTERVAL_MS 50
#define PACKET_QUEUE_LENGTH 10
#define MCV_BUFFER_SIZE 120  // up to 6 seconds of samples at 20Hz

// Sensor and BLE
Adafruit_BNO055 bno = Adafruit_BNO055(55);
BLECharacteristic* dataChar;
BLECharacteristic* mcvChar;
BLECharacteristic* commandChar;
BLEServer* pServer;
QueueHandle_t dataQueue;

// State
volatile bool deviceConnected = false;
volatile bool sendData = false;
bool inConcentric = false;
unsigned long startTime = 0;
float previousAccY = 0.0;

// Struct for IMU data
struct __attribute__((packed)) SensorPacket {
  uint16_t dt_ms;
  int16_t velocity;
  int16_t accel;
  int16_t pitch;
  int16_t yaw;
};

// Buffers
float concentricVelocities[MCV_BUFFER_SIZE];
uint32_t concentricTimestamps[MCV_BUFFER_SIZE];
int concentricIndex = 0;

// BLE Callbacks
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
      startTime = millis();
      sendData = true;
      concentricIndex = 0;
      Serial.println("✅ Start command received.");
    } else if (value == "stop") {
      sendData = false;
      Serial.println("🛑 Stop command received.");
    }
  }
};

float calculateMCV() {
  if (concentricIndex == 0) return 0.0;
  if (concentricIndex == 1) return concentricVelocities[0];

  float weightedSum = 0.0;
  uint32_t totalTime = concentricTimestamps[concentricIndex - 1] - concentricTimestamps[0];
  float arithmeticMean = 0.0;

  for (int i = 0; i < concentricIndex; i++) {
    arithmeticMean += concentricVelocities[i];
  }
  arithmeticMean /= concentricIndex;

  if (totalTime == 0) return arithmeticMean;

  for (int i = 0; i < concentricIndex - 1; i++) {
    float dt = (float)(concentricTimestamps[i+1] - concentricTimestamps[i]) / 1000.0;
    weightedSum += concentricVelocities[i] * dt;
  }

  return weightedSum / (totalTime / 1000.0);
}

void sendMCV(float mcv) {
  int16_t mcvScaled = mcv * 1000;
  // mcvChar->setValue((uint8_t*)&mcvScaled, sizeof(mcvScaled));
  mcvChar->setValue(mcv);
  mcvChar->notify();
  Serial.printf("📤 Sent MCV: %.3f", mcv);
}

void samplingTask(void* parameter) {
  SensorPacket pkt;
  uint32_t millisOld = millis();

  while (true) {
    if (sendData && deviceConnected) {
      imu::Vector<3> acc = bno.getVector(Adafruit_BNO055::VECTOR_LINEARACCEL);
      imu::Vector<3> euler = bno.getVector(Adafruit_BNO055::VECTOR_EULER);

      float dt = (millis() - millisOld) / 1000.0;
      millisOld = millis();
      float Vy = acc.y() * dt;

      if (abs(Vy) < 0.1) Vy = 0.0;

      pkt.dt_ms = millis() - startTime;
      pkt.velocity = Vy * 1000;
      pkt.accel = acc.y() * 100;
      pkt.pitch = euler.y() * 100;
      pkt.yaw = euler.z() * 100;

      // Concentric phase detection
      if (acc.y() >= 0.05) {
        if (!inConcentric) {
          concentricIndex = 0;  // reset buffer
          inConcentric = true;
          Serial.println("🔄 Entered Concentric Phase");
        }

        if (concentricIndex < MCV_BUFFER_SIZE) {
          concentricVelocities[concentricIndex] = Vy;
          concentricTimestamps[concentricIndex] = millis();
          concentricIndex++;
        }

      } else if (acc.y() < -0.05 && inConcentric) {
        inConcentric = false;
        Serial.println("⏹️ Switching to Eccentric Phase, sending MCV...");
        float mcv = calculateMCV();
        sendMCV(mcv);
        concentricIndex = 0;
      }

      xQueueSend(dataQueue, &pkt, portMAX_DELAY);
    }

    vTaskDelay(pdMS_TO_TICKS(SAMPLE_INTERVAL_MS));
  }
}

void bleTask(void* parameter) {
  SensorPacket pkt;

  while (true) {
    if (sendData && deviceConnected && xQueueReceive(dataQueue, &pkt, portMAX_DELAY)) {
      dataChar->setValue((uint8_t*)&pkt, sizeof(pkt));
      dataChar->notify();
      Serial.printf("📤 Sent IMU | dt: %d ms | vel: %.3f | acc: %.2f | pitch: %.2f | yaw: %.2f",
      pkt.dt_ms, pkt.velocity / 1000.0, pkt.accel / 100.0, pkt.pitch / 100.0, pkt.yaw / 100.0);
    }
    vTaskDelay(pdMS_TO_TICKS(5));
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

  Serial.println("✅ BLE Advertising started...");

  dataQueue = xQueueCreate(PACKET_QUEUE_LENGTH, sizeof(SensorPacket));
  if (dataQueue == NULL) {
    Serial.println("❌ Queue creation failed.");
    while (1);
  }

  xTaskCreatePinnedToCore(samplingTask, "Sampling Task", 4096, NULL, 2, NULL, 1);
  xTaskCreatePinnedToCore(bleTask, "BLE Task", 4096, NULL, 1, NULL, 1);
}

void loop() {}
