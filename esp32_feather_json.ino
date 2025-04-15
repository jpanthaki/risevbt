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
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
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
  BLEDevice::init("RiseVBT_sensor");

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

void loop() {
  // pinMode(LED_BUILTIN, OUTPUT);
  // digitalWrite(LED_BUILTIN, deviceConnected ? HIGH : LOW);



  Serial.print("🔄 deviceConnected: ");
  Serial.print(deviceConnected);
  Serial.print(" | sendData: ");
  Serial.println(sendData);

  if (!deviceConnected || !sendData) {
    delay(100);
    return;
  }

  Serial.println("📤 Sending IMU packet...");


  imu::Vector<3> acc = bno.getVector(Adafruit_BNO055::VECTOR_LINEARACCEL);
  imu::Vector<3> gyro = bno.getVector(Adafruit_BNO055::VECTOR_GYROSCOPE);
  imu::Vector<3> euler = bno.getVector(Adafruit_BNO055::VECTOR_EULER);

  static unsigned long packetTime = millis();

  dt = (millis() - millisOld) / 1000.; 
  millisOld = millis();

  time1 = millisOld / 1000;

  Vx = initVx + acc.x() * dt;
  Vy = initVy + acc.y() * dt;
  Vz = (initVz + acc.z() * dt) - 1;

  StaticJsonDocument<512> doc;
  doc["packet_time_stamp"] = packetTime;
  doc["dir"] = direction;

  JsonArray data = doc.createNestedArray("data");

  JsonObject entry = data.createNestedObject();
  entry["time_stamp"] = millis() / 1000.0;
  entry["velocity"] = Vy;  // Replace with your velocity calculation if needed
  entry["accel"] = acc.y();     // Use appropriate axis
  entry["pitch"] = euler.y();
  entry["yaw"] = euler.z();

  String jsonString;
  serializeJson(doc, jsonString);
  Serial.println(jsonString);

  pDataCharacteristic->setValue(jsonString.c_str());
  pDataCharacteristic->notify();

  delay(100);  // adjust based on desired sampling
}
