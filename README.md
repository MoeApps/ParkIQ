# ParkIQ Flutter App

Smart Parking Reservation & Access Control — Flutter frontend.

---

## Quick Start (zero Flutter experience needed)

### 1. Install Flutter
Go to https://docs.flutter.dev/get-started/install and follow the guide for your OS.
Run `flutter doctor` in your terminal — fix anything it flags.

### 2. Install dependencies
```bash
cd parkiq_flutter
flutter pub get
```

### 3. Run the app
```bash
# On a connected Android phone or emulator:
flutter run

# Or target a specific device:
flutter run -d android
flutter run -d ios
```

---

## Folder Structure

```
lib/
├── main.dart                  ← App entry point (don't edit much)
│
├── theme/
│   └── app_theme.dart         ← All colors & fonts in one place
│
├── models/
│   └── reservation.dart       ← Data classes: ParkingSpot, Reservation, ParkingLot
│
├── services/
│   └── parking_service.dart   ← ⭐ THE file to edit when connecting to ESP
│
├── widgets/
│   └── shared_widgets.dart    ← Reusable UI pieces (buttons, cards, badges…)
│
└── screens/
    ├── login_screen.dart      ← Screen 1: Sign in
    ├── dashboard_screen.dart  ← Screen 2: Home / overview
    ├── reserve_screen.dart    ← Screen 3: 3-step reservation flow
    └── entry_pin_screen.dart  ← Screen 4: PIN + QR + countdown
```

---

## Connecting to Your ESP  ⚡

**Everything happens in one file: `lib/services/parking_service.dart`**

### Step 1 — Find your ESP's IP address
When the ESP connects to WiFi it prints its IP to serial monitor, e.g. `192.168.1.42`.

### Step 2 — Set the base URL
Open `parking_service.dart` and change line 1:
```dart
// Before:
const String ESP_BASE_URL = 'http://192.168.1.100';

// After (use your actual IP):
const String ESP_BASE_URL = 'http://192.168.1.42';
```

### Step 3 — Replace mock methods with real HTTP calls
Each method has a commented-out real implementation. Example:

```dart
// ── MOCK (current) ──
Future<bool> login(String email, String password) async {
  await Future.delayed(const Duration(seconds: 1));
  return email.isNotEmpty && password.length >= 4;
}

// ── REAL (uncomment when ESP is ready) ──
Future<bool> login(String email, String password) async {
  final res = await http.post(
    Uri.parse('$ESP_BASE_URL/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );
  return res.statusCode == 200;
}
```

### ESP endpoints the app expects
| Method | Path         | Body                          | Returns           |
|--------|--------------|-------------------------------|-------------------|
| POST   | /login       | `{email, password}`           | 200 or 401        |
| GET    | /lots        | —                             | `[{id,name,...}]` |
| GET    | /spots?lot=1 | —                             | `[{id,status,...}]`|
| POST   | /reserve     | `{spot,start,duration}`       | `{id,pin,...}`    |
| POST   | /gate        | `{action:"open"\|"close"}`    | 200 or 500        |

---

## Communication Protocol Options

### Option A — WiFi / HTTP (Recommended for beginners)
The ESP runs a simple web server (ESP8266WebServer or ESP32 WebServer).
The app sends HTTP requests over the same WiFi network.
Already set up in `parking_service.dart` — just uncomment the real calls.

### Option B — Bluetooth BLE
If you choose BLE later, you'll need to:
1. Add `flutter_blue_plus: ^1.31.0` to `pubspec.yaml`
2. Replace the `http.post` calls in `parking_service.dart` with BLE write/read calls
3. The rest of the app stays exactly the same

---

## Building for Release

```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (requires macOS + Xcode)
flutter build ios --release
```

---

## Common Issues

| Problem | Fix |
|---------|-----|
| `flutter pub get` fails | Make sure you have internet and Flutter is installed correctly |
| App can't reach ESP | Make sure phone and ESP are on the same WiFi network |
| QR code not showing | Run `flutter pub get` again — qr_flutter needs to download |
| Red screen with error | Read the error message in terminal — it tells you exactly what's wrong |
# ParkIQ
