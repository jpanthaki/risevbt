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


#include "Adafruit_MAX1704X.h"
#include <Adafruit_NeoPixel.h>
#include "Adafruit_TestBed.h"
#include <Adafruit_BME280.h>
#include <Adafruit_ST7789.h> 
#include <Fonts/FreeSans12pt7b.h>

// UUIDs
#define SERVICE_UUID "7c961cfd-2527-4808-a9b0-9ce954427712"
#define DATA_CHARACTERISTIC_UUID "207a2a33-ab38-4748-8702-5ff50b2d673f"
#define MCV_CHARACTERISTIC_UUID  "54a598af-dc7a-4398-be14-69e04c9b41ef"
#define COMMAND_CHARACTERISTIC_UUID "1c902c8d-88bb-44f9-9dea-0bc5bf2d0af4"

#define SAMPLE_INTERVAL_MS 50
#define PACKET_QUEUE_LENGTH 10
#define MCV_BUFFER_SIZE 120


#define BNO055_SAMPLERATE_DELAY_MS (100)


// graphics
Adafruit_BME280 bme; // I2C
bool bmefound = false;
extern Adafruit_TestBed TB;

Adafruit_MAX17048 max_bat;
Adafruit_ST7789 display = Adafruit_ST7789(TFT_CS, TFT_DC, TFT_RST);
GFXcanvas16 canvas(240, 135);

bool maxfound = false;

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

    Q[0][0] = 1e-2; Q[0][1] = 0.0;
    Q[1][0] = 0.0;  Q[1][1] = 5e-2;
    R = 0.1;

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
KalmanFilter kalmanAccz;



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
  mcvChar->setValue(mcv);
  mcvChar->notify();
  Serial.printf("📤 Sent MCV: %.3f\n", mcv);
}
float accBiasZ = 0.0;

void calibrateAccBias() {
  accBiasZ = 0.0;
  const int biasSamples = 50;

  Serial.println("📏 Calibrating acceleration bias...");
  for (int i = 0; i < biasSamples; i++) {
    imu::Vector<3> acc = bno.getVector(Adafruit_BNO055::VECTOR_LINEARACCEL);
    accBiasZ += acc.z();
    delay(20); // 20ms * 50 = 1 second
  }
  accBiasZ /= biasSamples;
  Serial.print("✅ Acceleration bias (Z): ");
  Serial.println(accBiasZ, 6);
}


// === Tasks ===
bool readyForNextConcentric = true;
float lastSentMCV = 0.0;    // NEW: store last MCV to print later
float prevAccz, prev_filteredAccz = 0.0;    // previous filtered acceleration
float Vz = 0.0;                  // integrated velocity

unsigned long stillStartTime = 0;
bool isStill = false;


void samplingTask(void* parameter) {
  SensorPacket pkt;
  uint32_t millisOld = millis();

  while (true) {
    if (sendData && deviceConnected) {
      imu::Vector<3> acc = bno.getVector(Adafruit_BNO055::VECTOR_LINEARACCEL);
      imu::Vector<3> euler = bno.getVector(Adafruit_BNO055::VECTOR_EULER);

      float dt = (millis() - millisOld) / 1000.0;
      millisOld = millis();
      float rawAccz = acc.z() - accBiasZ;
      if (abs(rawAccz) < 0.6f) rawAccz = 0.0f;

      // Simple high-pass filter example
      float alpha = 0.95;
      float filteredAccz = alpha * (filteredAccz + rawAccz - prevAccz);
      prevAccz = rawAccz;

      // bool currentlyStill = abs(rawAccz) < 0.07;

      // if (currentlyStill) {
      //   if (!isStill) {
      //     isStill = true;
      //     stillStartTime = millis();
      //   }
      //   else if (abs(rawAccz) < 0.9) {  // 1 seconds still
      //     Vz = 0.0;  // RESET velocity!
      //   }
      // } else {
      //   isStill = false; // bar is moving again
      // }

      // float filteredAccz = kalmanAccz.update(rawAccz);

      // Then integrate
      // float Vy = kalmanAccY.update(acc.y() * dt);
      // Normal trapezoidal integration
      Vz += 0.5f * (prev_filteredAccz + filteredAccz) * dt;

      // If both acceleration and velocity are very small => bar is resting
      if (abs(filteredAccz) < 0.4f && abs(Vz) < 0.8f) {
          Vz = 0.0;
      }
      // Gentle decay to zero if velocity is small but not quite zero
      if (abs(Vz) < 2.0f && abs(filteredAccz) < 0.5f) {
          Vz *= 0.95f;  // Slow decay toward zero
      }
      // Clamp extremely tiny velocities for clean plots
      if (abs(Vz) < 0.02f) {
          Vz = 0.0f;
      }

      if (abs(Vz) > 5.0f) {
          Vz = 0.0f;
      }

      // Save for next integration step
      prev_filteredAccz = filteredAccz;



      // // Clamp near-zero velocities
      // if (abs(Vy) < 0.05) Vy = 0.0;


      pkt.dt_ms = millis() - startTime;
      pkt.velocity = Vz * 1000;
      // pkt.accel = rawAccY * 100;
      pkt.accel = rawAccz * 100;
      pkt.pitch = euler.y() * 100;
      pkt.yaw = euler.z() * 100;

      if (rawAccz >= 0.03) {
        if (!inConcentric && readyForNextConcentric) {
          inConcentric = true;
          readyForNextConcentric = false;
          concentricIndex = 0;
          Serial.println("🔄 Entered Concentric Phase");
        }
        if (inConcentric && concentricIndex < MCV_BUFFER_SIZE) {
          concentricVelocities[concentricIndex] = Vz;
          concentricTimestamps[concentricIndex] = millis();
          concentricIndex++;
        }
      } 
      else if (rawAccz < -0.03 && inConcentric) {
        inConcentric = false;
        readyForNextConcentric = true;
        Serial.println("⏹️ Switched to Eccentric Phase");

        float mcv = calculateMCV();
        sendMCV(mcv);               // Still send normally
        lastSentMCV = mcv;           // ⬅️ Store it for later printing!
      }

      xQueueSend(dataQueue, &pkt, portMAX_DELAY);
    }
    vTaskDelay(pdMS_TO_TICKS(SAMPLE_INTERVAL_MS));
  }
}


void bleTask(void* parameter) {
  SensorPacket pkt;
  static float lastPrintedMCV = -9999.0; // Track if MCV changed

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

      // 🆕 Print MCV once after it's sent
      if (lastSentMCV != lastPrintedMCV) {
        Serial.printf("💥 Mean Concentric Velocity (MCV): %.3f m/s\n", lastSentMCV);
        lastPrintedMCV = lastSentMCV;
      }
    }
    vTaskDelay(pdMS_TO_TICKS(5));
  }
}

#define EEPROM_SIZE 512
#define MAGIC_KEY 0xA55A1234  // Used to verify EEPROM content is valid

unsigned long lastDisplayUpdate = 0;
const unsigned long displayInterval = 100;  // Update every 100 ms
uint8_t j = 0;


// === Setup ===
void setup() {
  Serial.begin(115200);
  delay(1000);

  // turn on the TFT / I2C power supply
  pinMode(TFT_I2C_POWER, OUTPUT);
  digitalWrite(TFT_I2C_POWER, HIGH);

  pinMode(NEOPIXEL_POWER, OUTPUT);
  digitalWrite(NEOPIXEL_POWER, HIGH);
  delay(10);
  
  TB.neopixelPin = PIN_NEOPIXEL;
  TB.neopixelNum = 1; 
  TB.begin();
  TB.setColor(WHITE);

  display.init(135, 240); // Init ST7789 240x135
  display.setRotation(3);
  canvas.setFont(&FreeSans12pt7b);
  canvas.setTextColor(ST77XX_WHITE); 
  if (!max_bat.begin()) {
    Serial.println(F("Couldnt find Adafruit MAX1704X?\nMake sure a battery is plugged in!"));
    while (1) delay(10);
  }
  Serial.print(F("Found MAX17048"));
  Serial.print(F(" with Chip ID: 0x")); 
  Serial.println(max_bat.getChipID(), HEX);
  maxfound = true;
  
  
  if (!bno.begin()) {
    Serial.println("BNO055 not detected. Check wiring.");
    while (1);
  }

  delay(1000);

  if (alreadyCalibrated) {
    // Load calibration from EEPROM
    EEPROM.get(eeAddress, bnoID);
    bno.getSensor(&sensor);

    if (bnoID != sensor.sensor_id) {
      Serial.println("No matching calibration data found.");
    } 
    
    // load old register values from EEPROM into BNO 
    else {
      Serial.println("Restoring calibration from EEPROM...");
      delay(1000);

      adafruit_bno055_offsets_t calibrationData;

      EEPROM.get(eeAddress + sizeof(long), calibrationData);

      // set to config mode (can only read offsets and radius in config mode)
      // write sensor offsets and radius data
      // change to fusion mode

      // ******
      bno.setMode(OPERATION_MODE_CONFIG);
      delay(25);

      Serial.println("calibration data loaded into registers");
      bno.setSensorOffsets(calibrationData);

      // *******
      bno.setMode(OPERATION_MODE_NDOF);
      delay(25);

      displaySensorOffsets(calibrationData);

      printCalibrationStatus();

      // set after configuring calibration data
      // bno.setExtCrystalUse(true);

      // if (zero) {
      //   Serial.println("zeroing... please do not move the device");
      //   delay(1000);
      // }
    }

    if (millis() - lastDisplayUpdate >= displayInterval) {
    lastDisplayUpdate = millis();  // Reset timer

    canvas.fillScreen(ST77XX_BLACK);
    canvas.setCursor(0, 25);
    canvas.setTextColor(ST77XX_NORON);
    canvas.println("RiseVBT");

    canvas.setTextColor(ST77XX_WHITE); 
    canvas.print("Battery: ");
    canvas.print(max_bat.cellVoltage(), 1);
    canvas.print(" V  /  ");
    canvas.print(max_bat.cellPercent(), 0);
    canvas.println("%");

    canvas.setTextColor(ST77XX_RED);
    canvas.print("Fully calibrated!");

    canvas.setTextColor(ST77XX_WHITE);
    display.drawRGBBitmap(0, 0, canvas.getBuffer(), 240, 135);

    // Light up backlight if off
    pinMode(TFT_BACKLITE, OUTPUT);
    digitalWrite(TFT_BACKLITE, HIGH);

    // Cycle text bar color
    TB.setColor(TB.Wheel(j++));
  }
} 
  
  // calibrate sensor and store values into EEPROM
  else {
    Serial.println("Starting calibration process...");
    delay(1000);

    eeAddress = 0;
    while (!bno.isFullyCalibrated()) {
      printCalibrationStatus();


      uint8_t system, gyros, accel, magnet;
  bno.getCalibration(&sys, &gyros, &accel, &magnet);

  if (millis() - lastDisplayUpdate >= displayInterval) {
    lastDisplayUpdate = millis();  // Reset timer

    canvas.fillScreen(ST77XX_BLACK);
    canvas.setCursor(0, 25);
    canvas.setTextColor(ST77XX_NORON);
    canvas.println("RiseVBT");

    canvas.setTextColor(ST77XX_WHITE); 
    canvas.print("Battery: ");
    canvas.print(max_bat.cellVoltage(), 1);
    canvas.print(" V  /  ");
    canvas.print(max_bat.cellPercent(), 0);
    canvas.println("%");

    canvas.setTextColor(ST77XX_RED);
    canvas.print("A cal: ");
    canvas.print(float(accel), 0);
    canvas.println(",");
    canvas.print("G cal: ");
    canvas.print(float(gyros), 0);
    canvas.println(",");
    canvas.print("M cal: ");
    canvas.print(float(magnet), 0);

    canvas.setTextColor(ST77XX_WHITE);
    display.drawRGBBitmap(0, 0, canvas.getBuffer(), 240, 135);

    // Light up backlight if off
    pinMode(TFT_BACKLITE, OUTPUT);
    digitalWrite(TFT_BACKLITE, HIGH);

    // Cycle text bar color
    TB.setColor(TB.Wheel(j++));
  }

      delay(BNO055_SAMPLERATE_DELAY_MS);
    }

    // *****
    bno.setMode(OPERATION_MODE_CONFIG);

    Serial.println("Calibration complete!");
    adafruit_bno055_offsets_t newCalib;
    bno.getSensorOffsets(newCalib);
    displaySensorOffsets(newCalib);

    bno.getSensor(&sensor);
    bnoID = sensor.sensor_id;


    EEPROM.put(eeAddress, bnoID);
    EEPROM.put(eeAddress + sizeof(long), newCalib);

    EEPROM.commit();

    delay(500);
    Serial.println("Calibration data saved to EEPROM.");

    // *****
    bno.setMode(OPERATION_MODE_NDOF);

    bno.setExtCrystalUse(true);

  }

  printCalibrationStatus();
  // figure out mag mode
  // bno.setMode(OPERATION_MODE_NDOF);
  delay(500);


  bno.setExtCrystalUse(true);

  Serial.println("Calibration complete! Initializing BLE...");
  calibrateAccBias();
  // === BLE Setup
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

  Serial.println("📡 BLE Advertising Started ✅");

  dataQueue = xQueueCreate(PACKET_QUEUE_LENGTH, sizeof(SensorPacket));
  if (!dataQueue) {
    Serial.println("❌ Queue creation failed.");
    while (1);
  }

  xTaskCreatePinnedToCore(samplingTask, "Sampling Task", 4096, NULL, 2, NULL, 1);
  xTaskCreatePinnedToCore(bleTask, "BLE Task", 4096, NULL, 1, NULL, 1);
}

void loop() {
  // uint8_t system, gyros, accel, magnet;
  // bno.getCalibration(&sys, &gyros, &accel, &magnet);

  // if (millis() - lastDisplayUpdate >= displayInterval) {
  //   lastDisplayUpdate = millis();  // Reset timer

  //   canvas.fillScreen(ST77XX_BLACK);
  //   canvas.setCursor(0, 25);
  //   canvas.setTextColor(ST77XX_NORON);
  //   canvas.println("RiseVBT");

  //   canvas.setTextColor(ST77XX_WHITE); 
  //   canvas.print("Battery: ");
  //   canvas.print(max_bat.cellVoltage(), 1);
  //   canvas.print(" V  /  ");
  //   canvas.print(max_bat.cellPercent(), 0);
  //   canvas.println("%");

  //   canvas.setTextColor(ST77XX_RED);
  //   canvas.print("A cal: ");
  //   canvas.print(float(accel), 0);
  //   canvas.println(",");
  //   canvas.print("G cal: ");
  //   canvas.print(float(gyros), 0);
  //   canvas.println(",");
  //   canvas.print("M cal: ");
  //   canvas.print(float(magnet), 0);

  //   canvas.setTextColor(ST77XX_WHITE);
  //   display.drawRGBBitmap(0, 0, canvas.getBuffer(), 240, 135);

  //   // Light up backlight if off
  //   pinMode(TFT_BACKLITE, OUTPUT);
  //   digitalWrite(TFT_BACKLITE, HIGH);

  //   // Cycle text bar color
  //   TB.setColor(TB.Wheel(j++));
  // }
}
