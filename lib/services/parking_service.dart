// lib/services/parking_service.dart
//
// ════════════════════════════════════════════════════════════════
//  THIS IS THE ONLY FILE YOU NEED TO EDIT WHEN YOU CONNECT THE ESP
//
//  Right now every method returns fake (mock) data so the app works
//  without any hardware. When your ESP is ready:
//
//    1. Set ESP_BASE_URL to your ESP's IP address, e.g.
//       const String ESP_BASE_URL = 'http://192.168.1.42';
//
//    2. Replace the mock return values below with real HTTP calls
//       (examples are shown in comments next to each method).
//
//  The rest of the app never changes — screens just call these methods.
// ════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reservation.dart';

// ── Config ────────────────────────────────────────────────────────────────────
// Change this to your ESP's IP when you're ready
const String ESP_BASE_URL = 'http://192.168.1.100';

class ParkingService {
  // Singleton — one instance shared across the whole app
  static final ParkingService instance = ParkingService._();
  ParkingService._();

  // ── Auth ────────────────────────────────────────────────────────────────────

  /// Returns true if credentials are valid.
  /// MOCK: always succeeds.
  /// REAL: POST $ESP_BASE_URL/login  body: { email, password }
  Future<bool> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1)); // fake network delay

    // ── REAL implementation (uncomment when ESP is ready) ──
    // final res = await http.post(
    //   Uri.parse('$ESP_BASE_URL/login'),
    //   headers: {'Content-Type': 'application/json'},
    //   body: jsonEncode({'email': email, 'password': password}),
    // );
    // return res.statusCode == 200;

    return email.isNotEmpty && password.length >= 4;
  }

  // ── Spots ───────────────────────────────────────────────────────────────────

  /// Returns all parking spots for a given lot.
  /// MOCK: 24 hard-coded spots.
  /// REAL: GET $ESP_BASE_URL/spots?lot=1
  Future<List<ParkingSpot>> getSpots({int lotId = 1}) async {
    await Future.delayed(const Duration(milliseconds: 600));

    // ── REAL implementation ──
    // final res = await http.get(Uri.parse('$ESP_BASE_URL/spots?lot=$lotId'));
    // final List data = jsonDecode(res.body);
    // return data.map((j) => ParkingSpot.fromJson(j)).toList();

    // Mock: generate 24 spots across 3 floors
    final statuses = ['available','available','available','occupied','reserved','available','occupied','available'];
    return List.generate(24, (i) {
      final letter = String.fromCharCode(65 + (i ~/ 8)); // A, B, C
      final num    = (i % 8) + 1;
      return ParkingSpot(
        id:     '$letter$num',
        status: statuses[i % 8],
        floor:  (i ~/ 8) + 1,
        type:   i % 6 == 0 ? 'disabled' : i % 7 == 0 ? 'ev' : 'standard',
      );
    });
  }

  // ── Lots ────────────────────────────────────────────────────────────────────

  /// Returns the list of available parking lots near the user.
  /// MOCK: 4 hard-coded Cairo lots.
  /// REAL: GET $ESP_BASE_URL/lots
  Future<List<ParkingLot>> getLots() async {
    await Future.delayed(const Duration(milliseconds: 500));

    return const [
      ParkingLot(id: 1, name: 'Downtown Lot A',  address: '15 Tahrir Square',         available: 18, total: 48,  distance: '0.3 km', price: 5),
      ParkingLot(id: 2, name: 'Airport Lot B',   address: 'Cairo International Airport', available: 34, total: 120, distance: '1.2 km', price: 8),
      ParkingLot(id: 3, name: 'Mall Lot C',      address: 'Cairo Festival City',        available: 7,  total: 60,  distance: '2.4 km', price: 4),
      ParkingLot(id: 4, name: 'Hospital Lot D',  address: 'Ain Shams Medical Center',   available: 22, total: 40,  distance: '0.8 km', price: 3),
    ];
  }

  // ── Reserve ─────────────────────────────────────────────────────────────────

  /// Creates a reservation and returns it (with a generated PIN).
  /// MOCK: returns a fake Reservation immediately.
  /// REAL: POST $ESP_BASE_URL/reserve
  Future<Reservation> createReservation({
    required String lotName,
    required String spotId,
    required DateTime startTime,
    required int durationHours,
    required double hourlyRate,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    // ── REAL implementation ──
    // final res = await http.post(
    //   Uri.parse('$ESP_BASE_URL/reserve'),
    //   headers: {'Content-Type': 'application/json'},
    //   body: jsonEncode({
    //     'spot':     spotId,
    //     'start':    startTime.toIso8601String(),
    //     'duration': durationHours,
    //   }),
    // );
    // return Reservation.fromJson(jsonDecode(res.body));

    return Reservation(
      id:        'R${DateTime.now().millisecondsSinceEpoch}',
      spotId:    spotId,
      lotName:   lotName,
      startTime: startTime,
      endTime:   startTime.add(Duration(hours: durationHours)),
      pin:       _generatePin(),
      cost:      hourlyRate * durationHours,
    );
  }

  // ── Gate ────────────────────────────────────────────────────────────────────

  /// Tells the ESP to open/close the gate. Returns true if it worked.
  /// MOCK: always succeeds.
  /// REAL: POST $ESP_BASE_URL/gate  body: { action: "open" | "close" }
  Future<bool> triggerGate(String action) async {
    await Future.delayed(const Duration(milliseconds: 800));

    // ── REAL implementation ──
    // final res = await http.post(
    //   Uri.parse('$ESP_BASE_URL/gate'),
    //   headers: {'Content-Type': 'application/json'},
    //   body: jsonEncode({'action': action}),
    // );
    // return res.statusCode == 200;

    return true; // mock always succeeds
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _generatePin() {
    final n = DateTime.now().millisecondsSinceEpoch % 9000 + 1000;
    return n.toString();
  }
}
