#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLEAdvertising.h>
#include <BLE2902.h>
#include <Arduino.h>
#include <ArduinoJson.h>

/* BLE DEFINITIONS */

#define SERVICE_UUID        "7c961cfd-2527-4808-a9b0-9ce954427712"
#define CHARACTERISTIC_UUID "207a2a33-ab38-4748-8702-5ff50b2d673f"
#define COMMAND_CHARACTERISTIC_UUID "1c902c8d-88bb-44f9-9dea-0bc5bf2d0af4"

// Increase the packet buffer size to accommodate larger JSON strings.
#define PACKET_BUFFER_SIZE   1024      
#define PACKET_QUEUE_LENGTH  10      

BLEServer* pServer = NULL;
BLECharacteristic* pDataCharacteristic = NULL;
BLECharacteristic* pCommandCharacteristic = NULL;

volatile bool deviceConnected = false;
volatile bool oldDeviceConnected = false;
volatile bool sendData = false;

/* BLE SERVER CALLBACKS */
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
        Serial.println("Start command received: will send dummy packets...");
      }
      if (rxValue.equals("stop")) {
        sendData = false;
        Serial.println("Stop command received: stop sending packets...");
      }
    }
  }
};

/* THREADING CODE */
QueueHandle_t packetQueue;

// We'll alternate between sending concentric and eccentric packets.
volatile bool sendConPacket = true; 

// Dummy JSON packets for concentric and eccentric data.
// Note: the inner quotes in the "data" field have been escaped (") so that the string is parsed correctly.
const char *conPacket = R"({"packet_time_stamp":1638345600,"dir":"con","data":[{"time_stamp":0.0,"velocity":0.82,"accel":11.4},{"time_stamp":0.05,"velocity":0.87,"accel":11.0},{"time_stamp":0.10,"velocity":0.91,"accel":10.6},{"time_stamp":0.15,"velocity":0.95,"accel":10.3},{"time_stamp":0.20,"velocity":0.93,"accel":10.5},{"time_stamp":0.25,"velocity":0.90,"accel":10.7},{"time_stamp":0.30,"velocity":0.88,"accel":10.9}]})"
;

const char *eccPacket = R"({"packet_time_stamp":1638345605,"dir":"ecc","data":[{"time_stamp":0.00,"velocity":-0.8200,"accel":-1.5333},{"time_stamp":0.05,"velocity":-0.8856,"accel":-1.0889},{"time_stamp":0.10,"velocity":-0.9289,"accel":-0.6444},{"time_stamp":0.15,"velocity":-0.9500,"accel":-0.2000},{"time_stamp":0.20,"velocity":-0.9489,"accel":0.2445},{"time_stamp":0.25,"velocity":-0.9256,"accel":0.6889},{"time_stamp":0.30,"velocity":-0.8800,"accel":1.1333}]})"
;

void sendChunkedData(const String &jsonString) {
  const size_t chunkSize = 20;
  size_t totalLength = jsonString.length();
  size_t numChunks = (totalLength + chunkSize - 1) / chunkSize;

  Serial.printf("Total length: %d, sending in %d chunks\n", totalLength, numChunks);

  for (size_t i = 0; i < numChunks; i++) {
    int start = i * chunkSize;
    int end = min(start + chunkSize, totalLength);
    String chunk = jsonString.substring(start, end);

    pDataCharacteristic->setValue(chunk.c_str());
    pDataCharacteristic->notify();

    vTaskDelay(pdMS_TO_TICKS(10));
  }

}

/* BLUETOOTH TASK */
void bluetoothTask(void *parameters) {
  char outgoingPacket[PACKET_BUFFER_SIZE];

  while (true) {
    if (!deviceConnected && oldDeviceConnected) {
      // Device was disconnected: reset and restart advertising.
      Serial.println("Device disconnected. Restarting advertising...");
      sendData = false;
      pServer->startAdvertising();
      oldDeviceConnected = deviceConnected;
    }
    else if (deviceConnected && !oldDeviceConnected) {
      Serial.println("Client reconnected!");
      oldDeviceConnected = deviceConnected;
    }

    if (xQueueReceive(packetQueue, (void*)outgoingPacket, pdMS_TO_TICKS(50)) == pdTRUE) {
      if (deviceConnected) {
        sendChunkedData(outgoingPacket);
        Serial.printf("Sent packet: %sn", outgoingPacket);
      }
    }
    vTaskDelay(pdMS_TO_TICKS(10));
  }
}

/* DATA UPDATE TASK */
void dataUpdateTask(void *parameters) {
  TickType_t xLastWakeTime = xTaskGetTickCount();
  const TickType_t xFrequency = pdMS_TO_TICKS(5000);  // send one packet per 5 seconds

  char packetBuffer[PACKET_BUFFER_SIZE];

  while (true) {
    // Wait until sendData flag is set (via BLE command "start")
    if (sendData) {
      // Alternate between sending con and ecc packets.
      if (sendConPacket) {
        strncpy(packetBuffer, conPacket, PACKET_BUFFER_SIZE);
        Serial.println("Preparing Concentric Packet");
      } else {
        strncpy(packetBuffer, eccPacket, PACKET_BUFFER_SIZE);
        Serial.println("Preparing Eccentric Packet");
      }

      Serial.println("here");

      // Enqueue the packet.
      if (xQueueSend(packetQueue, (void*)packetBuffer, portMAX_DELAY) != pdPASS) {
        Serial.println("Failed to enqueue packet");
      } else {
        Serial.println("Packet enqueued successfully");
      }

      // Toggle for the next packet.
      // sendConPacket = !sendConPacket;
    }

    sendData = false;

    vTaskDelayUntil(&xLastWakeTime, xFrequency);
  }
}

/* SETUP CODE */
void setup() {
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
  pAdvertising->setMinPreferred(0x0);
  BLEDevice::startAdvertising();

  Serial.println("Waiting for a client connection...");

  packetQueue = xQueueCreate(PACKET_QUEUE_LENGTH, PACKET_BUFFER_SIZE);
  if (packetQueue == NULL) {
    Serial.println("Error creating the packet queue...");
    while(1); // Halt execution
  }

  xTaskCreate(bluetoothTask, "Bluetooth Task", 4096, NULL, 1, NULL);
  xTaskCreate(dataUpdateTask, "Data Update Task", 4096, NULL, 1, NULL);
}

void loop() {
  // Nothing to do here.
}