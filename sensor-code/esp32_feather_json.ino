#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BNO055.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLEAdvertising.h>
#include <BLE2902.h>
#include <ArduinoJson.h>

// IMU
Adafruit_BNO055 bno = Adafruit_BNO055(55);
#define OPERATION_MODE_NDOF 0x0C

// BLE UUIDs
#define SERVICE_UUID        "7c961cfd-2527-4808-a9b0-9ce954427712"
#define CHARACTERISTIC_UUID "207a2a33-ab38-4748-8702-5ff50b2d673f"
#define COMMAND_CHARACTERISTIC_UUID "1c902c8d-88bb-44f9-9dea-0bc5bf2d0af4"

unsigned long millisOld;
unsigned long time1;
float dt;

float Vx, Vy, Vz;
float initVx, initVy, initVz = 0;


BLEServer* pServer = NULL;
BLECharacteristic* pDataCharacteristic = NULL;
BLECharacteristic* pCommandCharacteristic = NULL;

bool deviceConnected = false;
bool sendData = false;
String direction = "con";  // Change this dynamically if needed

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) { deviceConnected = true; }
  void onDisconnect(BLEServer* pServer) { deviceConnected = false; }
};

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("✅ BLE client connected.");
  }
  void onDisconnect(BLEServer* pServer) {
    Serial.println("❌ BLE client disconnected. Restarting advertising...");
    delay(500);
    BLEDevice::startAdvertising();
  }
};

class CommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {

    String rx = pCharacteristic->getValue();
    if (rx == "start") {
      sendData = true;
      Serial.println("✅ Start command received.");
    } else if (rx == "stop") {
      sendData = false;
      Serial.println("🛑 Stop command received.");
    }
  }
};

void setup() {
  Serial.begin(115200);
  BLEDevice::deinit(true);
  delay(1000);
  BLEDevice::init("sheeeeeed");

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  pDataCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pDataCharacteristic->addDescriptor(new BLE2902());

  pCommandCharacteristic = pService->createCharacteristic(
    COMMAND_CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  pCommandCharacteristic->setCallbacks(new CommandCallbacks());

  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  while (!bno.begin()) {
    Serial.println("BNO055 not detected");
    delay(1000);
  }
  bno.setMode((adafruit_bno055_opmode_t)OPERATION_MODE_NDOF);
  bno.setExtCrystalUse(true);
  Serial.println("IMU and BLE ready");
}

void sendChunkedJson(const String &jsonString) {
  const size_t chunkSize = 20;
  size_t totalLength = jsonString.length();
  size_t numChunks = (totalLength + chunkSize - 1) / chunkSize;

  Serial.printf("📦 Sending JSON in %d chunks (total length %d)...\n", numChunks, totalLength);

  for (size_t i = 0; i < numChunks; i++) {
    String chunk = jsonString.substring(i * chunkSize, min((i + 1) * chunkSize, totalLength));
    pDataCharacteristic->setValue(chunk.c_str());
    pDataCharacteristic->notify();
    vTaskDelay(pdMS_TO_TICKS(10));  // avoid overloading the BLE stack
  }
}

// Kalman Filter class for smoothing
class KalmanFilter {
public:
  KalmanFilter(float q = 1e-5, float r = 1e-2, float p = 1.0) : q(q), r(r), p(p), x(0.0) {}
  float update(float measurement) {
    p += q;
    float k = p / (p + r);
    x += k * (measurement - x);
    p *= (1 - k);
    return x;
  }
private:
  float q, r, p, x;
};

KalmanFilter kalmanY;
float velY = 0.0;

void loop() {
  if (!deviceConnected || !sendData) {
    delay(100);
    return;
  }

  Serial.println("📥 Collecting 3s of IMU data...");

  StaticJsonDocument<1024> doc;
  doc["packet_time_stamp"] = millis();
  doc["dir"] = direction;

  JsonArray dataArray = doc.createNestedArray("data");
  unsigned long start = millis();

  while (millis() - start < 3000) {
    imu::Vector<3> acc = bno.getVector(Adafruit_BNO055::VECTOR_LINEARACCEL);
    imu::Vector<3> euler = bno.getVector(Adafruit_BNO055::VECTOR_EULER);

    // Calculate dt
    dt = (millis() - millisOld) / 1000.0;
    millisOld = millis();

    // Update velocity and apply Kalman filter
    // Apply a low-pass threshold: if accel is very small, treat it as 0
    float accY = abs(acc.y()) < 0.05 ? 0.0 : acc.y();

    // Kalman filter on acceleration
    float accY_filtered = kalmanY.update(accY);

    // Integrate velocity only when accel is significant
    if (accY_filtered == 0.0) {
      // Optional: gradual decay to zero (simulate friction)
      velY *= 0.90;
    } else {
      velY += accY_filtered * dt;
    }


    // Optional hard clamp if velocity gets tiny
    if (abs(velY) < 0.05) {
      velY = 0.0;
    }


    // Only store significant motion data
    if (abs(velY) >= 0.1) {
      JsonObject entry = dataArray.createNestedObject();
      entry["time_stamp"] = millis() / 1000.0;
      entry["velocity"] = velY;
      entry["accel"] = acc.y();
      entry["pitch"] = euler.y();
      entry["yaw"] = euler.z();
    }

    delay(50);  // ~20 Hz sampling
  }

  String jsonString;
  serializeJson(doc, jsonString);
  Serial.println("📤 Full JSON prepared. Sending...");
  Serial.println(jsonString);
  sendChunkedJson(jsonString);
}
