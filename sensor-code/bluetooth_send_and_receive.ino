//code for sending and receiving data over BLE

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLEAdvertising.h>
#include <BLE2902.h>


BLEServer* pServer = NULL;
BLECharacteristic* pDataCharacteristic = NULL;
BLECharacteristic* pCommandCharacteristic = NULL;

bool deviceConnected = false;
bool oldDeviceConnected = false;
bool seriesStartFlag = false;

int x = 0;
int y = 0;
bool pos = true;

#define SERVICE_UUID        "7c961cfd-2527-4808-a9b0-9ce954427712"
#define CHARACTERISTIC_UUID "207a2a33-ab38-4748-8702-5ff50b2d673f"
#define COMMAND_CHARACTERISTIC_UUID "1c902c8d-88bb-44f9-9dea-0bc5bf2d0af4"

class MyServerCallbacks: public BLEServerCallbacks {

  void onConnect(BLEServer *pServer) {
    deviceConnected = true;
  };

  void onDisconnect(BLEServer *pServer) {
    deviceConnected = false;
  };
};

class MyCharacteristicCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String rxValue = pCharacteristic->getValue();
    if (rxValue.length() > 0) {
      Serial.print("Received Command: ");
      Serial.println(rxValue.c_str());

      if (rxValue.equals("start")) {
        seriesStartFlag = true;
        Serial.println("Start command received: will send messages...");
      }
    }
  }
};

void setup() {
  Serial.begin(115200);
  
  while(!Serial);

  BLEDevice::init("sheeeeeed");

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  pDataCharacteristic = pService->createCharacteristic(
                        CHARACTERISTIC_UUID,
                        BLECharacteristic::PROPERTY_READ | 
                        BLECharacteristic::PROPERTY_NOTIFY
                      );

  pDataCharacteristic->addDescriptor(new BLE2902());

  pCommandCharacteristic = pService->createCharacteristic(
                           COMMAND_CHARACTERISTIC_UUID,
                           BLECharacteristic::PROPERTY_WRITE | 
                           BLECharacteristic::PROPERTY_READ
                         );
  pCommandCharacteristic->setCallbacks(new MyCharacteristicCallbacks());

  pService->start();

  BLEAdvertisementData advertisementData;
  advertisementData.setName("sheeeeeed");
  advertisementData.setCompleteServices(BLEUUID(SERVICE_UUID));

  BLEAdvertisementData scanResponseData;
  scanResponseData.setName("sheeeeeed");

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponseData(scanResponseData);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x0); //set value to 0x0 to not advertise this parameter
  BLEDevice::startAdvertising();

  Serial.println("Waiting for a client connection...");
}

void loop() {

  if (deviceConnected) {
    if (seriesStartFlag) {
      for (int i = 0; i < 10; i++) {
        char packet [40];
        sprintf(packet, "{\"x\": %ld, \"y\": %ld}", x, y);

        Serial.printf("%s\n", packet);

        pDataCharacteristic->setValue(packet);
        pDataCharacteristic->notify();

        x++;
        y = pos ? y + 1 : y - 1;

        delay(3);
      }
      pos = !pos;
      seriesStartFlag = false;
    }
  }

  if (!deviceConnected && oldDeviceConnected) {
    x = 0;
    y = 0;
    pos = true;
    delay(500);
    pServer->startAdvertising();
    Serial.println("start advertising again");
    Serial.printf("deviceConnected = %b, oldDeviceConnected = %b\n", deviceConnected, oldDeviceConnected);
    oldDeviceConnected = deviceConnected;
  }

  if (deviceConnected && !oldDeviceConnected) {
    Serial.println("reconnected!!!");
    oldDeviceConnected = deviceConnected;
  }
}
