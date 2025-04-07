// code framework courtesy of Paul McWhorter

#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BNO055.h>
#include <utility/imumaths.h>
#include <math.h> // for calculating tilt (trig)

#define BNO055_SAMPLERATE_DELAY_MS (100)

float thetaM;
float phiM;
float thetaFold = 0;
float thetaFnew;
float phiFold = 0;
float phiFnew;

float thetaG = 0;
float phiG = 0;

float theta;
float phi;

unsigned long millisOld;
unsigned long time;
float dt;

float Vx, Vy, Vz;
float initVx, initVy, initVz = 0;


Adafruit_BNO055 bno = Adafruit_BNO055();


void setup() {
  // put your setup code here, to run once:

  Serial.begin(115200); 
  bno.begin(); // turns on
  delay(1000);
  bno.setExtCrystalUse(true);
  millisOld = millis();
}


void loop() {

  uint8_t system, gyros, accel, magnet = 0;
  bno.getCalibration(&system, &gyros, &accel, &magnet);
  // 0 = lowest calibration, 3 = highest calibration 

  // grab all vector tools
  imu::Vector<3> acc = bno.getVector(Adafruit_BNO055::VECTOR_ACCELEROMETER);
  imu::Vector<3> gyro = bno.getVector(Adafruit_BNO055::VECTOR_GYROSCOPE);
  imu::Vector<3> mag = bno.getVector(Adafruit_BNO055::VECTOR_MAGNETOMETER);

  // define angles in degrees (theta for pitch, phi for roll)
  // reads expected angles about y axis
  thetaM = atan2(acc.x() / 9.8, acc.z() / 9.8) / 2/3.141592653589793238 * 360;
  // reads expected angles about x axis
  phiM = atan2(acc.y() / 9.8, acc.z() / 9.8) / 2/3.141592653589793238 * 360;

  phiFnew = 0.95 * phiFold + 0.05 * phiM;
  thetaFnew = 0.95 * thetaFold + 0.05 * thetaM;
  // filter and add weight to favor short term gyro data and long term acceleration data
  // establish angular velocity and change in time for gyro use
  dt = (millis() - millisOld) / 1000.; 
  millisOld = millis();
  theta = (theta + gyro.y() * dt) * 0.95 + thetaM * 0.05;
  phi = (phi - gyro.x() * dt) * 0.95 + phiM * 0.05;
  thetaG = thetaG + gyro.y() * dt;
  phiG = phiG - gyro.x() * dt;

  time = millisOld / 1000;

  Vx = initVx + acc.x() * dt;
  Vy = initVy + acc.y() * dt;
  Vz = (initVz + acc.z() * dt) - 1;


// PRINT TIME
Serial.print("Time: ");
Serial.print(time);
Serial.print(",  ");

// PRINT CALIBRATIONS
Serial.print("Scal: ");
Serial.print(system);
Serial.print(",  ");
Serial.print("Acal: ");
Serial.print(accel);
Serial.print(",  ");
Serial.print("Gcal: ");
Serial.print(gyros);
Serial.print(",  ");
Serial.print("Mcal: ");
Serial.print(magnet);
Serial.print(",  ");

// (normalize acceleration by dividing by 1g)
// PRINT ACCELERATIONS
Serial.print("Ax: ");
Serial.print(acc.x()/9.81);
Serial.print(",  ");
Serial.print("Ay: ");
Serial.print(acc.y()/9.81);
Serial.print(",  ");
Serial.print("Az: ");
Serial.print((acc.z()/9.81) - 1);
Serial.print(",  ");

// PRINT ANGLES
Serial.print("theta: "); 
Serial.print(thetaM);
Serial.print(",  ");
Serial.print("phi: ");
Serial.print(phiM);
Serial.print(",  ");

// PRINT VELOCITIES
Serial.print("V_x: ");
Serial.print(Vx);
Serial.print(",  ");
Serial.print("V_y: ");
Serial.print(Vy);
Serial.print(",  ");
Serial.print("V_z: ");
Serial.println(Vz);


// Serial.print(",  ");
// Serial.print("thetaFnew : ");
// Serial.print(thetaFnew);
// Serial.print(",  ");
// Serial.print("phiFnew : ");
// Serial.println(phiFnew);
// Serial.print(",");

// print angles
// Serial.print("thetaG: ");
// Serial.print(thetaG);
// Serial.print(",");
// Serial.print("phiG: ");
// Serial.print(phiG);
// Serial.print(",");
// Serial.print("theta: ");
// Serial.print(theta);
// Serial.print(",");
// Serial.print("phi: ");
// Serial.println(phi);
 



// Serial.print(gyro.x());
// Serial.print(",");
// Serial.print(gyro.y());
// Serial.print(",");
// Serial.print(gyro.z());

// Serial.print(mag.x());
// Serial.print(",");
// Serial.print(mag.y());
// Serial.print(",");
// Serial.println(mag.z());

  phiFold=phiFnew;
  thetaFold=thetaFnew;

  delay(BNO055_SAMPLERATE_DELAY_MS);

}
