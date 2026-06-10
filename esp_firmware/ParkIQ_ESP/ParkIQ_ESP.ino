/*
 * ParkIQ ESP32 Smart Parking Firmware
 *
 * ARDUINO IDE SETUP:
 *   Board:  ESP32 Dev Module
 *   Port:   your COM port
 *   Upload Speed: 115200  (lower if upload fails)
 *
 * LIBRARIES (Library Manager):
 *   - ArduinoJson by Benoit Blanchon  (v6.x or v7.x)
 *   - ESP32Servo
 *   - LiquidCrystal I2C
 *   - Keypad by Mark Stanley
 *
 * UPLOAD FAILS (exit status 2)?
 *   1. Close Serial Monitor before uploading
 *   2. Tools -> Upload Speed -> 115200
 *   3. Hold BOOT, tap EN/RESET, release BOOT when "Connecting..." appears
 *   4. Disconnect IR sensors / keypad wires from GPIO 12 and 15 during upload
 *      (strapping pins can block flashing)
 *   5. Use a data USB cable (not charge-only)
 */

#include <WiFi.h>
#include <WebServer.h>
#include <ArduinoJson.h>
#include <ESP32Servo.h>
#include <LiquidCrystal_I2C.h>
#include <Keypad.h>
#include <Wire.h>
#include <limits.h>

// =====================================================
// WIFI ACCESS POINT
// =====================================================
const char* WIFI_SSID = "ParkingSystem";
const char* WIFI_PASSWORD = "12345678";

WebServer server(80);

// =====================================================
// LCD
// =====================================================
LiquidCrystal_I2C lcd(0x27, 16, 2);

// =====================================================
// IR SENSORS
// =====================================================
#define ENTRY_IR 12
#define EXIT_IR 14

#define SLOT1_IR 27
#define SLOT2_IR 26
#define SLOT3_IR 25
#define SLOT4_IR 33

// =====================================================
// SERVOS
// =====================================================
#define ENTRY_SERVO_PIN 18
#define EXIT_SERVO_PIN 19

Servo entryServo;
Servo exitServo;

// =====================================================
// LEDS
// =====================================================
#define GREEN_LED 23
#define RED_LED 32

// =====================================================
// KEYPAD 3x3
// =====================================================
const byte ROWS = 3;
const byte COLS = 3;

char keys[ROWS][COLS] = {
  {'1', '2', '3'},
  {'4', '5', '6'},
  {'7', '8', '9'}
};

byte rowPins[ROWS] = {5, 17, 16};
byte colPins[COLS] = {4, 15, 13};

Keypad keypad = Keypad(
  makeKeymap(keys),
  rowPins,
  colPins,
  ROWS,
  COLS
);

// =====================================================
// PARKING CONFIG
// =====================================================
const float COST_PER_HOUR = 20.0;

const int MAX_SLOTS = 4;
const int MAX_RESERVATIONS = 10;
const int MAX_PENDING = 4;

// =====================================================
// SLOT STRUCTURE
// =====================================================
struct ParkingSlot {
  bool occupied;
  bool reserved;
  int pinCode;
  unsigned long entryTime;
};

ParkingSlot slots[MAX_SLOTS];

// =====================================================
// RESERVATIONS (app bookings - tied to a specific slot)
// =====================================================
struct Reservation {
  bool active;
  String username;
  int slotIndex;
  int pin;
  unsigned long createdAt;
};

Reservation reservations[MAX_RESERVATIONS];

// =====================================================
// PENDING CARS (inside after gate opened, not yet parked)
// Walk-in: targetSlot = -1  -> FIFO slot assignment
// Reserved: targetSlot = 0..3 -> must park in that slot
// =====================================================
struct PendingCar {
  bool active;
  int pin;
  unsigned long queuedAt;
  int targetSlot;
};

PendingCar pendingQueue[MAX_PENDING];

// =====================================================
// REVENUE & STATUS
// =====================================================
float totalRevenue = 0;
int freeSlots = 4;
bool parkingFull = false;
String systemStatus = "READY";

// =====================================================
// ENTRY GATE UI STATE
// =====================================================
enum EntryUiState {
  ENTRY_IDLE,
  ENTRY_MENU
};

EntryUiState entryUiState = ENTRY_IDLE;
bool wasAtEntryGate = false;

// =====================================================
// LCD HELPERS
// =====================================================
void showMessage(String line1, String line2) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(line1);
  lcd.setCursor(0, 1);
  lcd.print(line2);
}

void showWelcome() {
  showMessage("WELCOME TO", "PARKIQ");
}

void showEntryMenu() {
  showMessage("1=GET PIN", "2=RESERV PIN");
}

// =====================================================
// FREE / FULL SLOT LOGIC
// =====================================================
int getFreeSlots() {
  int count = 0;

  for (int i = 0; i < MAX_SLOTS; i++) {
    if (!slots[i].occupied && !slots[i].reserved) {
      count++;
    }
  }

  return count;
}

bool isWalkInFull() {
  return getFreeSlots() == 0;
}

// =====================================================
// PIN HELPERS
// =====================================================
bool pinInUse(int pin) {
  if (pin <= 0) {
    return false;
  }

  for (int i = 0; i < MAX_SLOTS; i++) {
    if ((slots[i].occupied || slots[i].reserved) &&
        slots[i].pinCode == pin) {
      return true;
    }
  }

  for (int i = 0; i < MAX_PENDING; i++) {
    if (pendingQueue[i].active && pendingQueue[i].pin == pin) {
      return true;
    }
  }

  return false;
}

int generatePin() {
  for (int attempt = 0; attempt < 100; attempt++) {
    int pin = random(11, 99);
    int tens = pin / 10;
    int ones = pin % 10;

    if (tens != 0 && ones != 0 && !pinInUse(pin)) {
      return pin;
    }
  }

  return 11;
}

// =====================================================
// SERVO CONTROL
// =====================================================
void openEntryGate() {
  entryServo.write(90);
  delay(3000);
  entryServo.write(0);
}

void openExitGate() {
  exitServo.write(90);
  delay(3000);
  exitServo.write(0);
}

// =====================================================
// LED STATUS
// =====================================================
void updateStatusLEDs() {
  freeSlots = getFreeSlots();

  if (freeSlots == 0) {
    digitalWrite(RED_LED, HIGH);
    digitalWrite(GREEN_LED, LOW);
    parkingFull = true;
  } else {
    digitalWrite(RED_LED, LOW);
    digitalWrite(GREEN_LED, HIGH);
    parkingFull = false;
  }
}

// =====================================================
// SLOT SENSOR
// =====================================================
bool slotOccupied(int slotIndex) {
  switch (slotIndex) {
    case 0: return digitalRead(SLOT1_IR) == LOW;
    case 1: return digitalRead(SLOT2_IR) == LOW;
    case 2: return digitalRead(SLOT3_IR) == LOW;
    case 3: return digitalRead(SLOT4_IR) == LOW;
  }

  return false;
}

bool isAtEntryGate() {
  return digitalRead(ENTRY_IR) == LOW;
}

// =====================================================
// PENDING QUEUE
// =====================================================
bool enqueuePending(int pin, int targetSlot) {
  for (int i = 0; i < MAX_PENDING; i++) {
    if (!pendingQueue[i].active) {
      pendingQueue[i].active = true;
      pendingQueue[i].pin = pin;
      pendingQueue[i].queuedAt = millis();
      pendingQueue[i].targetSlot = targetSlot;
      return true;
    }
  }

  return false;
}

void deactivatePending(int index) {
  pendingQueue[index].active = false;
  pendingQueue[index].pin = 0;
  pendingQueue[index].targetSlot = -1;
}

int findOldestWalkInPending() {
  int bestIndex = -1;
  unsigned long oldest = ULONG_MAX;

  for (int i = 0; i < MAX_PENDING; i++) {
    if (pendingQueue[i].active &&
        pendingQueue[i].targetSlot == -1 &&
        pendingQueue[i].queuedAt < oldest) {
      oldest = pendingQueue[i].queuedAt;
      bestIndex = i;
    }
  }

  return bestIndex;
}

int findPendingForSlot(int slotIndex) {
  for (int i = 0; i < MAX_PENDING; i++) {
    if (pendingQueue[i].active &&
        pendingQueue[i].targetSlot == slotIndex) {
      return i;
    }
  }

  return -1;
}

// =====================================================
// SLOT ASSIGNMENT
// =====================================================
void clearReservationForSlot(int slotIndex) {
  for (int i = 0; i < MAX_RESERVATIONS; i++) {
    if (reservations[i].active &&
        reservations[i].slotIndex == slotIndex) {
      reservations[i].active = false;
    }
  }
}

void completeSlotAssignment(int slotIndex, int pin) {
  slots[slotIndex].occupied = true;
  slots[slotIndex].reserved = false;
  slots[slotIndex].pinCode = pin;
  slots[slotIndex].entryTime = millis();

  clearReservationForSlot(slotIndex);
  updateStatusLEDs();

  if (entryUiState == ENTRY_IDLE) {
    showMessage("PARKED SLOT", String(slotIndex + 1));
    delay(1500);
    showWelcome();
  }
}

void processPendingParking() {
  for (int s = 0; s < MAX_SLOTS; s++) {
    if (!slotOccupied(s) || slots[s].occupied) {
      continue;
    }

    int pendingIndex = findPendingForSlot(s);
    if (pendingIndex == -1) {
      continue;
    }

    int pin = pendingQueue[pendingIndex].pin;
    deactivatePending(pendingIndex);
    completeSlotAssignment(s, pin);
  }

  for (int s = 0; s < MAX_SLOTS; s++) {
    if (!slotOccupied(s) || slots[s].occupied || slots[s].reserved) {
      continue;
    }

    int pendingIndex = findOldestWalkInPending();
    if (pendingIndex == -1) {
      continue;
    }

    int pin = pendingQueue[pendingIndex].pin;
    deactivatePending(pendingIndex);
    completeSlotAssignment(s, pin);
  }
}

// =====================================================
// FIND SLOT BY PIN (exit)
// =====================================================
int findSlotByPin(int pin) {
  for (int i = 0; i < MAX_SLOTS; i++) {
    if (slots[i].occupied && slots[i].pinCode == pin) {
      return i;
    }
  }

  return -1;
}

int findReservedSlotByPin(int pin) {
  for (int i = 0; i < MAX_SLOTS; i++) {
    if (slots[i].reserved &&
        !slots[i].occupied &&
        slots[i].pinCode == pin) {
      return i;
    }
  }

  return -1;
}

// =====================================================
// KEYPAD PIN READ
// =====================================================
int readPinBlocking() {
  String pin = "";

  showMessage("ENTER PIN", "");

  while (pin.length() < 2) {
    char key = keypad.getKey();

    if (key) {
      pin += key;
      lcd.setCursor(0, 1);
      lcd.print(pin);
    }
  }

  return pin.toInt();
}

int readPinAtEntryGate() {
  String pin = "";

  showMessage("ENTER PIN", "");

  while (pin.length() < 2) {
    if (!isAtEntryGate()) {
      return -1;
    }

    char key = keypad.getKey();

    if (key) {
      pin += key;
      lcd.setCursor(0, 1);
      lcd.print(pin);
    }

    delay(10);
  }

  return pin.toInt();
}

// =====================================================
// ENTRY GATE OPTIONS
// =====================================================
void handleOptionGetPin() {
  updateStatusLEDs();

  if (isWalkInFull()) {
    showMessage("PARKING", "FULL");
    systemStatus = "FULL";
    delay(2000);

    if (isAtEntryGate()) {
      showEntryMenu();
    }

    return;
  }

  int pin = generatePin();

  if (!enqueuePending(pin, -1)) {
    showMessage("SYSTEM", "BUSY");
    delay(2000);

    if (isAtEntryGate()) {
      showEntryMenu();
    }

    return;
  }

  showMessage("YOUR PIN:", String(pin));
  systemStatus = "ENTRY_GRANTED";
  openEntryGate();

  delay(1500);

  if (isAtEntryGate()) {
    showEntryMenu();
  }
}

void handleOptionReservationPin() {
  int pin = readPinAtEntryGate();

  if (pin == -1) {
    entryUiState = ENTRY_IDLE;
    showWelcome();
    systemStatus = "READY";
    return;
  }

  int slot = findReservedSlotByPin(pin);

  if (slot == -1) {
    showMessage("NO", "RESERVATION");
    systemStatus = "NO_RESERVATION";
    delay(2000);

    if (isAtEntryGate()) {
      showEntryMenu();
    } else {
      entryUiState = ENTRY_IDLE;
      showWelcome();
      systemStatus = "READY";
    }

    return;
  }

  if (!enqueuePending(pin, slot)) {
    showMessage("SYSTEM", "BUSY");
    delay(2000);

    if (isAtEntryGate()) {
      showEntryMenu();
    }

    return;
  }

  showMessage("GO TO SLOT", String(slot + 1));
  systemStatus = "RES_ENTRY";
  openEntryGate();

  delay(1500);

  if (isAtEntryGate()) {
    showEntryMenu();
  }
}

void handleEntryGatePresence() {
  bool atGate = isAtEntryGate();

  if (atGate && !wasAtEntryGate) {
    entryUiState = ENTRY_MENU;
    showEntryMenu();
    systemStatus = "AT_ENTRY";
  } else if (!atGate && wasAtEntryGate) {
    entryUiState = ENTRY_IDLE;
    showWelcome();
    systemStatus = "READY";
  }

  wasAtEntryGate = atGate;

  if (atGate && entryUiState == ENTRY_MENU) {
    char key = keypad.getKey();

    if (key == '1') {
      handleOptionGetPin();
    } else if (key == '2') {
      handleOptionReservationPin();
    }
  }
}

// =====================================================
// COST CALCULATION
// =====================================================
float calculateCost(unsigned long parkedTimeMs) {
  float hours = parkedTimeMs / 3600000.0;

  if (hours < 1.0) {
    hours = 1.0;
  }

  return hours * COST_PER_HOUR;
}

// =====================================================
// HANDLE EXIT
// =====================================================
void handleExit() {
  int pin = readPinBlocking();

  int slot = findSlotByPin(pin);

  if (slot == -1) {
    showMessage("INVALID", "PIN");
    delay(2000);
    showWelcome();
    return;
  }

  unsigned long duration = millis() - slots[slot].entryTime;
  float cost = calculateCost(duration);

  totalRevenue += cost;

  showMessage("COST", String(cost));
  openExitGate();

  slots[slot].occupied = false;
  slots[slot].reserved = false;
  slots[slot].pinCode = 0;
  slots[slot].entryTime = 0;

  delay(2000);
  updateStatusLEDs();
  showWelcome();
}

// =====================================================
// RESERVATIONS (APP API)
// =====================================================
bool addReservation(String user, int slotIndex, int pin) {
  for (int i = 0; i < MAX_RESERVATIONS; i++) {
    if (!reservations[i].active) {
      reservations[i].active = true;
      reservations[i].username = user;
      reservations[i].slotIndex = slotIndex;
      reservations[i].pin = pin;
      reservations[i].createdAt = millis();
      return true;
    }
  }

  return false;
}

bool cancelReservationBySlot(int slotIndex) {
  bool found = false;

  if (slotIndex >= 0 &&
      slotIndex < MAX_SLOTS &&
      slots[slotIndex].reserved &&
      !slots[slotIndex].occupied) {
    slots[slotIndex].reserved = false;
    slots[slotIndex].pinCode = 0;
    found = true;
  }

  for (int i = 0; i < MAX_RESERVATIONS; i++) {
    if (reservations[i].active &&
        reservations[i].slotIndex == slotIndex) {
      reservations[i].active = false;
      found = true;
    }
  }

  updateStatusLEDs();
  return found;
}

bool cancelReservationByUser(String user) {
  for (int i = 0; i < MAX_RESERVATIONS; i++) {
    if (reservations[i].active &&
        reservations[i].username == user) {
      return cancelReservationBySlot(reservations[i].slotIndex);
    }
  }

  return false;
}

int reservationCount() {
  int count = 0;

  for (int i = 0; i < MAX_RESERVATIONS; i++) {
    if (reservations[i].active) {
      count++;
    }
  }

  return count;
}

// =====================================================
// JSON HELPERS (ArduinoJson v6 + v7 compatible)
// =====================================================
#if ARDUINOJSON_VERSION_MAJOR >= 7
  #define JSON_ARRAY(doc, key) (doc)[key].to<JsonArray>()
  #define JSON_OBJECT(arr) (arr).add<JsonObject>()
#else
  #define JSON_ARRAY(doc, key) (doc).createNestedArray(key)
  #define JSON_OBJECT(arr) (arr).createNestedObject()
#endif

// =====================================================
// API : STATUS
// =====================================================
void apiStatus() {
  StaticJsonDocument<512> doc;

  doc["status"] = systemStatus;
  doc["freeSlots"] = getFreeSlots();
  doc["revenue"] = totalRevenue;
  doc["reservations"] = reservationCount();
  doc["full"] = parkingFull;

  String response;
  serializeJson(doc, response);

  server.send(200, "application/json", response);
}

// =====================================================
// API : SPOTS
// =====================================================
void apiSpots() {
  StaticJsonDocument<512> doc;

  JsonArray spots = JSON_ARRAY(doc, "spots");

  for (int i = 0; i < MAX_SLOTS; i++) {
    JsonObject spot = JSON_OBJECT(spots);

    spot["slot"] = i + 1;
    spot["occupied"] = slots[i].occupied;
    spot["reserved"] = slots[i].reserved;
  }

  String response;
  serializeJson(doc, response);

  server.send(200, "application/json", response);
}

// =====================================================
// API : REVENUE
// =====================================================
void apiRevenue() {
  StaticJsonDocument<256> doc;

  doc["revenue"] = totalRevenue;

  String response;
  serializeJson(doc, response);

  server.send(200, "application/json", response);
}

// =====================================================
// API : RESERVE
// Body JSON: { "slot": 1..4, "pin": 45, "user": "mobile" }
// =====================================================
void apiReserve() {
  int slotNum = 0;
  int pin = 0;
  String user = "mobile";

  if (server.hasArg("plain")) {
    StaticJsonDocument<256> doc;
    DeserializationError err = deserializeJson(doc, server.arg("plain"));

    if (!err) {
      slotNum = doc["slot"] | 0;
      pin = doc["pin"] | 0;
      if (!doc["user"].isNull()) {
        user = String(doc["user"].as<const char*>());
      }
    }
  }

  if (slotNum < 1 || slotNum > MAX_SLOTS) {
    server.send(400, "application/json", "{\"error\":\"Invalid slot\"}");
    return;
  }

  int slotIndex = slotNum - 1;

  if (slots[slotIndex].occupied || slots[slotIndex].reserved) {
    server.send(400, "application/json", "{\"error\":\"Slot unavailable\"}");
    return;
  }

  if (pin <= 0) {
    pin = generatePin();
  } else if (pinInUse(pin)) {
    server.send(400, "application/json", "{\"error\":\"PIN already in use\"}");
    return;
  }

  slots[slotIndex].reserved = true;
  slots[slotIndex].pinCode = pin;

  if (!addReservation(user, slotIndex, pin)) {
    slots[slotIndex].reserved = false;
    slots[slotIndex].pinCode = 0;
    server.send(400, "application/json", "{\"error\":\"Reservation limit\"}");
    return;
  }

  updateStatusLEDs();

  StaticJsonDocument<256> outDoc;
  outDoc["message"] = "Reservation Added";
  outDoc["slot"] = slotNum;
  outDoc["pin"] = pin;

  String response;
  serializeJson(outDoc, response);

  server.send(200, "application/json", response);
}

// =====================================================
// API : CANCEL
// =====================================================
void apiCancel() {
  int slotNum = 0;
  String user = "mobile";
  bool ok = false;

  if (server.hasArg("plain")) {
    StaticJsonDocument<256> doc;
    DeserializationError err = deserializeJson(doc, server.arg("plain"));

    if (!err) {
      slotNum = doc["slot"] | 0;
      if (!doc["user"].isNull()) {
        user = String(doc["user"].as<const char*>());
      }
    }
  }

  if (slotNum >= 1 && slotNum <= MAX_SLOTS) {
    ok = cancelReservationBySlot(slotNum - 1);
  } else {
    ok = cancelReservationByUser(user);
  }

  if (ok) {
    server.send(200, "text/plain", "Reservation Cancelled");
  } else {
    server.send(400, "text/plain", "Reservation Not Found");
  }
}

// =====================================================
// ADMIN OPEN ENTRY / EXIT
// =====================================================
void apiOpenEntry() {
  openEntryGate();
  server.send(200, "text/plain", "Entry Opened");
}

void apiOpenExit() {
  openExitGate();
  server.send(200, "text/plain", "Exit Opened");
}

// =====================================================
// SETUP
// =====================================================
void setup() {
  Serial.begin(115200);

  Wire.begin();
  lcd.init();
  lcd.backlight();
  showWelcome();
  delay(2000);

  pinMode(ENTRY_IR, INPUT);
  pinMode(EXIT_IR, INPUT);

  pinMode(SLOT1_IR, INPUT);
  pinMode(SLOT2_IR, INPUT);
  pinMode(SLOT3_IR, INPUT);
  pinMode(SLOT4_IR, INPUT);

  pinMode(GREEN_LED, OUTPUT);
  pinMode(RED_LED, OUTPUT);

  entryServo.attach(ENTRY_SERVO_PIN);
  exitServo.attach(EXIT_SERVO_PIN);
  entryServo.write(0);
  exitServo.write(0);

  for (int i = 0; i < MAX_SLOTS; i++) {
    slots[i].occupied = false;
    slots[i].reserved = false;
    slots[i].pinCode = 0;
    slots[i].entryTime = 0;
  }

  for (int i = 0; i < MAX_RESERVATIONS; i++) {
    reservations[i].active = false;
  }

  for (int i = 0; i < MAX_PENDING; i++) {
    pendingQueue[i].active = false;
    pendingQueue[i].pin = 0;
    pendingQueue[i].targetSlot = -1;
  }

  randomSeed(micros());

  WiFi.softAP(WIFI_SSID, WIFI_PASSWORD);

  Serial.println();
  Serial.println("HOTSPOT STARTED");
  Serial.print("IP: ");
  Serial.println(WiFi.softAPIP());

  server.on("/status", HTTP_GET, apiStatus);
  server.on("/spots", HTTP_GET, apiSpots);
  server.on("/revenue", HTTP_GET, apiRevenue);
  server.on("/reserve", HTTP_POST, apiReserve);
  server.on("/cancel", HTTP_POST, apiCancel);
  server.on("/openEntry", HTTP_POST, apiOpenEntry);
  server.on("/openExit", HTTP_POST, apiOpenExit);

  server.begin();

  updateStatusLEDs();
  showWelcome();
}

// =====================================================
// LOOP
// =====================================================
void loop() {
  server.handleClient();

  updateStatusLEDs();
  processPendingParking();
  handleEntryGatePresence();

  if (digitalRead(EXIT_IR) == LOW) {
    delay(200);
    handleExit();

    while (digitalRead(EXIT_IR) == LOW) {
      delay(50);
    }
  }
}
