// multi thread BLE code

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLEAdvertising.h>
#include <BLE2902.h>
#include <Arduino.h>

/* BLE CODE */

#define SERVICE_UUID        "7c961cfd-2527-4808-a9b0-9ce954427712"
#define CHARACTERISTIC_UUID "207a2a33-ab38-4748-8702-5ff50b2d673f"
#define COMMAND_CHARACTERISTIC_UUID "1c902c8d-88bb-44f9-9dea-0bc5bf2d0af4"

BLEServer* pServer = NULL;
BLECharacteristic* pDataCharacteristic = NULL;
BLECharacteristic* pCommandCharacteristic = NULL;

volatile bool deviceConnected = false;
volatile bool oldDeviceConnected = false;
volatile bool sendData = false;
volatile bool seriesStopFlag = true;

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
        sendData = true;
        Serial.println("Start command received: will send messages...");
      }

      if (rxValue.equals("stop")) {
        sendData = false;
        Serial.println("Stop command received: stop sending messages...");
      }
    }
  }
};

/* THREADING CODE */

QueueHandle_t packetQueue;

#define PACKET_BUFFER_SIZE   40      // Size of each packet
#define PACKET_QUEUE_LENGTH  10      // Packet Queue Length

volatile int x = 0;
volatile int y = 0;
volatile bool pos = true;

void bluetoothTask(void *parameters) {
  char outgoingPacket[PACKET_BUFFER_SIZE];

  while (true) {
    if (!deviceConnected && oldDeviceConnected) {
      // Device was disconnected: reset shared variables and restart advertising.
      x = 0;
      y = 0;
      pos = true;
      pServer->startAdvertising();
      Serial.println("Device disconnected. Restarting advertising...");
      oldDeviceConnected = deviceConnected;
    }
    else if (deviceConnected && !oldDeviceConnected) {
      Serial.println("Client reconnected!");
      oldDeviceConnected = deviceConnected;
    }

    if (xQueueReceive(packetQueue, (void*)outgoingPacket, pdMS_TO_TICKS(50)) == pdTRUE) {
      if (deviceConnected) {
        pDataCharacteristic->setValue(outgoingPacket);
        pDataCharacteristic->notify();
        Serial.printf("Sent packet: %s\n", outgoingPacket);
      }
    }

    vTaskDelay(pdMS_TO_TICKS(10));
  }
}

void dataUpdateTask(void *parameters) {
  TickType_t xLastWakeTime = xTaskGetTickCount();
  const TickType_t xFrequency = pdMS_TO_TICKS(50);

  char packetBuffer[PACKET_BUFFER_SIZE];

  while (true) {

    while (!sendData) {
      vTaskDelay(pdMS_TO_TICKS(10));
    }

    if (sendData) {
      for (int i = 0; i < 10; i++) {
        snprintf(packetBuffer, PACKET_BUFFER_SIZE, "{\"x\": %ld, \"y\": %ld}", x, y);

        if (xQueueSend(packetQueue, (void*)packetBuffer, portMAX_DELAY) != pdPASS) {
          Serial.println("Failed to enqueue packet");
        }

        x++;
        y = pos ? y + 1 : y - 1;

        vTaskDelay(pdMS_TO_TICKS(3));
      }
      pos = !pos;
      // sendData = false;
    }

    vTaskDelayUntil(&xLastWakeTime, xFrequency);
  }
}

/* SETUP CODE */

void setup() {
  // put your setup code here, to run once:

  Serial.begin(115200);
  while (!Serial);

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
                           BLECharacteristic::PROPERTY_READ |
                           BLECharacteristic::PROPERTY_WRITE_NR
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

  packetQueue = xQueueCreate(PACKET_QUEUE_LENGTH, PACKET_BUFFER_SIZE);
  if (packetQueue == NULL) {
    Serial.println("Error creating the packet queue...");
    while(1); //halt execution
  }

  xTaskCreate(bluetoothTask, "Bluetooth Task", 4096, NULL, 1, NULL);
  xTaskCreate(dataUpdateTask, "Data Update Task", 2048, NULL, 1, NULL);
}

void loop() {}
