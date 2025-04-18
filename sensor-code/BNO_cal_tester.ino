#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BNO055.h>
#include <utility/imumaths.h>
#include <math.h> // for calculating tilt (trig)
#include <EEPROM.h>

#define BNO055_SAMPLERATE_DELAY_MS (100)

Adafruit_BNO055 bno = Adafruit_BNO055();

bool zero = true;
bool foundCalib;
bool alreadyCalibrated = true; 
int zeroTime = 50;

sensors_event_t event;
int eeAddress;
long bnoID;
sensor_t sensor;
uint8_t systemCal, gyroCal, accelCal, magCal;

void displaySensorOffsets(const adafruit_bno055_offsets_t &calibData)
{
    Serial.print("Accelerometer: ");
    Serial.print(calibData.accel_offset_x); Serial.print(" ");
    Serial.print(calibData.accel_offset_y); Serial.print(" ");
    Serial.print(calibData.accel_offset_z); Serial.print(" ");

    Serial.print("\nGyro: ");
    Serial.print(calibData.gyro_offset_x); Serial.print(" ");
    Serial.print(calibData.gyro_offset_y); Serial.print(" ");
    Serial.print(calibData.gyro_offset_z); Serial.print(" ");

    Serial.print("\nMag: ");
    Serial.print(calibData.mag_offset_x); Serial.print(" ");
    Serial.print(calibData.mag_offset_y); Serial.print(" ");
    Serial.print(calibData.mag_offset_z); Serial.print(" ");

    Serial.print("\nAccel Radius: ");
    Serial.print(calibData.accel_radius);

    Serial.print("\nMag Radius: ");
    Serial.print(calibData.mag_radius);
}

void setup() {
  // check for bno

  Serial.begin(115200); 
  bno.begin(); // turns on
  delay(1000);

  // check if needs to be calibrated
  if (alreadyCalibrated) {
    eeAddress = 0;
    foundCalib = true;
    EEPROM.get(eeAddress, bnoID);
    adafruit_bno055_offsets_t calibrationData;

    // look for sensor's unique ID at beginning of EEPROM
    sensor_t sensor; 
    bno.getSensor(&sensor);

    if (bnoID != sensor.sensor_id) {
      Serial.println("\n No calibration data exists in EEPROM");
      delay(300);
    }

    // ????????????????????????????????
    // load calibration status (already calibrated)
    else {
      Serial.println("\n Return EEPROM values to BNO.");
      eeAddress += sizeof(long);
      EEPROM.get(eeAddress, calibrationData);
      displaySensorOffsets(calibrationData);
      bno.setSensorOffsets(calibrationData);
      Serial.println("\n\n calibration data loaded into BNO");

    }
  }


  else {
    Serial.println("Get Ready to calibrate sensors: ");

    Serial.println("Begin Calibration\n");
    while (!bno.isFullyCalibrated()) {
      bno.getEvent(&event);

      delay(200);

      systemCal, gyroCal, accelCal, magCal = 0;
      bno.getCalibration(&systemCal, &gyroCal, &accelCal, &magCal);

      // PRINT CALIBRATIONS
      Serial.print("Scal: ");
      Serial.print(systemCal);
      Serial.print(",  ");
      Serial.print("Acal: ");
      Serial.print(accelCal);
      Serial.print(",  ");
      Serial.print("Gcal: ");
      Serial.print(gyroCal);
      Serial.print(",  ");
      Serial.print("Mcal: ");
      Serial.println(magCal);

    }

    // now fully calibrated
    Serial.print("\n fully calibrated!");
    delay(600);
  
    // get ready to store values in the EEPROM
    adafruit_bno055_offsets_t newCalib;
    bno.getSensorOffsets(newCalib);
    Serial.print("Displaying sensor offsets: ");
    displaySensorOffsets(newCalib);

    // now store calibration in the sensor
    Serial.println("\n storing data to EEPROM");

    eeAddress = 0;
    bno.getSensor(&sensor);
    bnoID = sensor.sensor_id;

    EEPROM.put(eeAddress, bnoID);

    eeAddress += sizeof(long);
    EEPROM.put(eeAddress, newCalib);
    Serial.println("Data stored to EEPROM");

    delay(5000);
    Serial.println("getting ready to zero, please don't move device");

    // ?????????
    if (zero) {
      Serial.println("zeroing... please do not move the device");
      delay(1000);
    }

    bno.setExtCrystalUse(true);

    // ????????????????
    bno.setMode(0x0C);

    delay(500);

  }
    


}

void loop() {
  // grab values to report variables (i.e. time, gyro, mag, accel)

  Serial.println("completed setup...");
  delay(10000);

  // grab vector tools
  imu::Vector<3> acc = bno.getVector(Adafruit_BNO055::VECTOR_ACCELEROMETER);
  imu::Vector<3> gyro = bno.getVector(Adafruit_BNO055::VECTOR_GYROSCOPE);
  imu::Vector<3> mag = bno.getVector(Adafruit_BNO055::VECTOR_MAGNETOMETER);



  // PRINT CALIBRATIONS
  Serial.print("Scal: ");
  Serial.print(systemCal);
  Serial.print(",  ");
  Serial.print("Acal: ");
  Serial.print(accelCal);
  Serial.print(",  ");
  Serial.print("Gcal: ");
  Serial.print(gyroCal);
  Serial.print(",  ");
  Serial.print("Mcal: ");
  Serial.println(magCal);

}
