#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLEAdvertising.h>
#include <BLE2902.h>
#include <Arduino.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BNO055.h>
#include <Wire.h>
#include <EEPROM.h>
#include <utility/imumaths.h>

// UUIDs
#define SERVICE_UUID "7c961cfd-2527-4808-a9b0-9ce954427712"
#define DATA_CHARACTERISTIC_UUID "207a2a33-ab38-4748-8702-5ff50b2d673f"
#define MCV_CHARACTERISTIC_UUID  "54a598af-dc7a-4398-be14-69e04c9b41ef"
#define COMMAND_CHARACTERISTIC_UUID "1c902c8d-88bb-44f9-9dea-0bc5bf2d0af4"

#define SAMPLE_INTERVAL_MS 50
#define PACKET_QUEUE_LENGTH 10
#define MCV_BUFFER_SIZE 120

Adafruit_BNO055 bno = Adafruit_BNO055(55);

// BLE
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

// Calibration
bool alreadyCalibrated = true;
int eeAddress = 0;
long bnoID;
sensor_t sensor;
uint8_t sys, gyroCal, accelCal, magCal;

// Struct
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

class Kalman1D {
public:
  float v;      // velocity estimate
  float a;      // acceleration estimate
  float dt;

  float x[2];   // state vector [v, a]
  float P[2][2];

  float Q[2][2];  // process noise
  float R;        // measurement noise

  Kalman1D(float dt_) : dt(dt_) {
    x[0] = 0.0; x[1] = 0.0; // initial velocity, acceleration
    P[0][0] = 1.0; P[0][1] = 0.0;
    P[1][0] = 0.0; P[1][1] = 1.0;

    Q[0][0] = 1e-4; Q[0][1] = 0.0;
    Q[1][0] = 0.0;  Q[1][1] = 1e-4;
    R = 0.01;
  }

  void update(float measured_accel) {
    // Prediction step
    x[0] += x[1] * dt;  // v = v + a*dt
    x[1] = x[1];        // acceleration remains

    P[0][0] += dt * (P[1][1] * dt + P[0][1] + P[1][0]) + Q[0][0];
    P[0][1] += dt * P[1][1];
    P[1][0] += dt * P[1][1];
    P[1][1] += Q[1][1];

    // Measurement update (only a)
    float y = measured_accel - x[1]; // residual
    float S = P[1][1] + R;
    float K0 = P[0][1] / S;
    float K1 = P[1][1] / S;

    x[0] += K0 * y;
    x[1] += K1 * y;

    // Update P
    float P00_temp = P[0][0];
    float P01_temp = P[0][1];

    P[0][0] -= K0 * P01_temp;
    P[0][1] -= K0 * P[1][1];
    P[1][0] -= K1 * P01_temp;
    P[1][1] -= K1 * P[1][1];

    v = x[0];
    a = x[1];
  }

  float getVelocity() { return v; }
  float getAcceleration() { return a; }
};

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
KalmanFilter kalmanAccY;



// === Calibration ===
void displaySensorOffsets(const adafruit_bno055_offsets_t &calibData) {
  Serial.print("Accel Offset: ");
  Serial.print(calibData.accel_offset_x); Serial.print(" ");
  Serial.print(calibData.accel_offset_y); Serial.print(" ");
  Serial.println(calibData.accel_offset_z);

  Serial.print("Gyro Offset: ");
  Serial.print(calibData.gyro_offset_x); Serial.print(" ");
  Serial.print(calibData.gyro_offset_y); Serial.print(" ");
  Serial.println(calibData.gyro_offset_z);

  Serial.print("Mag Offset: ");
  Serial.print(calibData.mag_offset_x); Serial.print(" ");
  Serial.print(calibData.mag_offset_y); Serial.print(" ");
  Serial.println(calibData.mag_offset_z);

  Serial.print("Accel Radius: "); Serial.println(calibData.accel_radius);
  Serial.print("Mag Radius: "); Serial.println(calibData.mag_radius);
}

void printCalibrationStatus() {
  bno.getCalibration(&sys, &gyroCal, &accelCal, &magCal);
  Serial.print("Calib Status -> Sys: ");
  Serial.print(sys); Serial.print(" Accel: ");
  Serial.print(accelCal); Serial.print(" Gyro: ");
  Serial.print(gyroCal); Serial.print(" Mag: ");
  Serial.println(magCal);
}

// === BLE Callbacks ===
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

// === MCV ===
float calculateMCV() {
  if (concentricIndex == 0) return 0.0;
  if (concentricIndex == 1) return concentricVelocities[0];

  float weightedSum = 0.0;
  uint32_t totalTime = concentricTimestamps[concentricIndex - 1] - concentricTimestamps[0];
  float arithmeticMean = 0.0;

  for (int i = 0; i < concentricIndex; i++) arithmeticMean += concentricVelocities[i];
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
  mcvChar->setValue((uint8_t*)&mcvScaled, sizeof(mcvScaled));
  mcvChar->notify();
  Serial.printf("📤 Sent MCV: %.3f\n", mcv);
}

// === Tasks ===
void samplingTask(void* parameter) {
  SensorPacket pkt;
  uint32_t millisOld = millis();

  while (true) {
    if (sendData && deviceConnected) {
      imu::Vector<3> acc = bno.getVector(Adafruit_BNO055::VECTOR_LINEARACCEL);
      imu::Vector<3> euler = bno.getVector(Adafruit_BNO055::VECTOR_EULER);

      float dt = (millis() - millisOld) / 1000.0;
      millisOld = millis();
      float rawAccY = acc.y();
      float filteredAccY = kalmanAccY.update(rawAccY);

      // Then integrate
      float Vy = kalmanAccY.update(acc.y() * dt);
      if (abs(Vy) < 0.08) Vy = 0.0;


      // // Clamp near-zero velocities
      // if (abs(Vy) < 0.05) Vy = 0.0;


      pkt.dt_ms = millis() - startTime;
      pkt.velocity = Vy * 1000;
      pkt.accel = filteredAccY * 100;
      pkt.pitch = euler.y() * 100;
      pkt.yaw = euler.z() * 100;

      // Detect concentric phase
      if (acc.y() >= 0.05) {
        if (!inConcentric) {
          concentricIndex = 0;
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
        Serial.println("⏹️ Switched to Eccentric Phase");
        sendMCV(calculateMCV());
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
      uint8_t sys, gyro, accel, mag;
      bno.getCalibration(&sys, &gyro, &accel, &mag);
      Serial.printf("📤 Sent IMU | dt: %d ms | vel: %.3f | acc: %.2f | pitch: %.2f | yaw: %.2f\n",
        pkt.dt_ms, pkt.velocity / 1000.0, pkt.accel / 100.0,
        pkt.pitch / 100.0, pkt.yaw / 100.0);
      Serial.printf("📊 Calibration -> Sys: %d | Gyro: %d | Accel: %d | Mag: %d\n", sys, gyro, accel, mag);

    }
    vTaskDelay(pdMS_TO_TICKS(5));
  }
}


#define EEPROM_SIZE 512
#define MAGIC_KEY 0xA55A1234  // Used to verify EEPROM content is valid

// === Setup ===
void setup() {
  Serial.begin(115200);
  delay(1000);
  EEPROM.begin(EEPROM_SIZE);
  Serial.println("🌀 Booting...");

  if (!bno.begin()) {
    Serial.println("❌ BNO055 not detected!");
    while (1);
  }
  delay(1000);

  long magic = 0;
  EEPROM.get(0, magic);

  if (magic == MAGIC_KEY) {
    EEPROM.get(sizeof(long), bnoID);
    bno.getSensor(&sensor);

    Serial.printf("🔍 EEPROM bnoID: %ld | Sensor ID: %ld\n", bnoID, sensor.sensor_id);

    if (bnoID == sensor.sensor_id) {
      Serial.println("🔁 Restoring calibration from EEPROM...");
      adafruit_bno055_offsets_t calib;
      EEPROM.get(sizeof(long) * 2, calib);

      bno.setMode(OPERATION_MODE_CONFIG);
      delay(25);
      bno.setSensorOffsets(calib);
      bno.setMode(OPERATION_MODE_NDOF);
      delay(25);
      displaySensorOffsets(calib);
      Serial.println("✅ Calibration restored successfully!");
    } else {
      Serial.println("⚠️ Sensor ID mismatch. Skipping calibration restore.");
    }
  } else {
    Serial.println("🧭 Calibrating...");
    while (!bno.isFullyCalibrated()) {
      printCalibrationStatus();
      delay(100);
    }

    adafruit_bno055_offsets_t calib;
    bno.setMode(OPERATION_MODE_CONFIG);
    delay(25);
    bno.getSensorOffsets(calib);
    bno.getSensor(&sensor);
    bnoID = sensor.sensor_id;

    EEPROM.put(0, MAGIC_KEY);
    EEPROM.put(sizeof(long), bnoID);
    EEPROM.put(sizeof(long) * 2, calib);
    EEPROM.commit();

    bno.setMode(OPERATION_MODE_NDOF);
    delay(25);
    Serial.println("✅ Calibration saved to EEPROM!");
    displaySensorOffsets(calib);
  }

  bno.setExtCrystalUse(true);

  // === BLE Setup (unchanged)
  BLEDevice::init("sheeeeeed");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);

  dataChar = pService->createCharacteristic(DATA_CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  dataChar->addDescriptor(new BLE2902());

  mcvChar = pService->createCharacteristic(MCV_CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  mcvChar->addDescriptor(new BLE2902());

  commandChar = pService->createCharacteristic(COMMAND_CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_WRITE);
  commandChar->setCallbacks(new MyCommandCallbacks());

  pService->start();
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  BLEDevice::startAdvertising();

  Serial.println("📡 BLE Advertising...");

  dataQueue = xQueueCreate(PACKET_QUEUE_LENGTH, sizeof(SensorPacket));
  if (!dataQueue) {
    Serial.println("❌ Queue creation failed.");
    while (1);
  }

  xTaskCreatePinnedToCore(samplingTask, "Sampling Task", 4096, NULL, 2, NULL, 1);
  xTaskCreatePinnedToCore(bleTask, "BLE Task", 4096, NULL, 1, NULL, 1);
}

void loop() {}
