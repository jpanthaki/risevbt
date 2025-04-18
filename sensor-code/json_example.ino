#include <ArduinoJson.h>

void setup() {
  Serial.begin(115200);
  while (!Serial);

  // 1. Create a JSON document with a capacity (adjust if necessary)
  StaticJsonDocument<512> doc;

  // 2. Build the outer JSON structure:
  //    - Set "packet_time_stamp" and "dir"
  doc["packet_time_stamp"] = 1638345600;
  doc["dir"] = "con";

  // 3. Create a nested JSON array for the key "data"
  JsonArray dataArray = doc.createNestedArray("data");

  // 4. Add entries to the "data" array
  // First entry
  JsonObject entry = dataArray.createNestedObject();
  entry["time_stamp"] = 0.0;
  entry["velocity"] = 0.82;
  entry["accel"] = 11.4;

  // Second entry
  entry = dataArray.createNestedObject();
  entry["time_stamp"] = 0.05;
  entry["velocity"] = 0.87;
  entry["accel"] = 11.0;

  // Third entry (add more as needed)
  entry = dataArray.createNestedObject();
  entry["time_stamp"] = 0.10;
  entry["velocity"] = 0.91;
  entry["accel"] = 10.6;

  // You can continue adding more entries similarly...

  // 5. Serialize the JSON document to a String
  String jsonString;
  serializeJsonPretty(doc, jsonString);

  // 6. For debugging, print the resulting JSON string to the Serial Monitor
  Serial.println(jsonString);
}

void loop() {
  // Nothing to do here
}
