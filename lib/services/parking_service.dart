// lib/services/parking_service.dart
//
// Hybrid service: Lot 1 (ParkIQ Live Demo) talks to the ESP over WiFi.
// Lots 2–4 and login/payment stay mock for a richer demo UX.
//
// Phone must be on the ESP hotspot: ParkingSystem / 12345678
// ESP default IP: http://192.168.4.1

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reservation.dart';

/// ESP32 softAP address when phone joins "ParkingSystem" WiFi.
const String espBaseUrl = 'http://192.168.4.1';

/// The one lot wired to real hardware (4 physical slots).
const int hardwareLotId = 1;

/// Matches firmware COST_PER_HOUR in ParkIQ_ESP.ino
const double espHourlyRate = 20.0;

const Duration _espTimeout = Duration(seconds: 5);

class ParkingService {
  static final ParkingService instance = ParkingService._();
  ParkingService._();

  bool _espOnline = false;
  bool get espOnline => _espOnline;

  // ── Auth (mock — no /login on ESP) ─────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return email.isNotEmpty && password.length >= 4;
  }

  // ── Lots ───────────────────────────────────────────────────────────────────
  Future<List<ParkingLot>> getLots() async {
    final hardwareLot = await _fetchHardwareLot();
    return [
      hardwareLot,
      const ParkingLot(
        id: 2,
        name: 'Airport Lot B',
        address: 'Cairo International Airport',
        available: 34,
        total: 120,
        distance: '1.2 km',
        price: 8,
      ),
      const ParkingLot(
        id: 3,
        name: 'Mall Lot C',
        address: 'Cairo Festival City',
        available: 7,
        total: 60,
        distance: '2.4 km',
        price: 4,
      ),
      const ParkingLot(
        id: 4,
        name: 'Hospital Lot D',
        address: 'Ain Shams Medical Center',
        available: 22,
        total: 40,
        distance: '0.8 km',
        price: 3,
      ),
    ];
  }

  Future<ParkingLot> _fetchHardwareLot() async {
    try {
      final res = await http
          .get(Uri.parse('$espBaseUrl/status'))
          .timeout(_espTimeout);

      if (res.statusCode != 200) throw Exception('status ${res.statusCode}');

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _espOnline = true;

      return ParkingLot(
        id: hardwareLotId,
        name: 'ParkIQ Live Demo',
        address: 'ESP Hardware — connect to ParkingSystem WiFi',
        available: (data['freeSlots'] as num?)?.toInt() ?? 0,
        total: 4,
        distance: 'On-site',
        price: espHourlyRate,
        isHardwareLot: true,
        espOnline: true,
      );
    } catch (_) {
      _espOnline = false;
      return const ParkingLot(
        id: hardwareLotId,
        name: 'ParkIQ Live Demo',
        address: 'ESP offline — join ParkingSystem WiFi',
        available: 0,
        total: 4,
        distance: 'On-site',
        price: espHourlyRate,
        isHardwareLot: true,
        espOnline: false,
      );
    }
  }

  // ── Spots ──────────────────────────────────────────────────────────────────
  Future<List<ParkingSpot>> getSpots({required int lotId}) async {
    if (lotId == hardwareLotId) {
      return _fetchHardwareSpots();
    }
    return _mockSpots();
  }

  Future<List<ParkingSpot>> _fetchHardwareSpots() async {
    try {
      final res = await http
          .get(Uri.parse('$espBaseUrl/spots'))
          .timeout(_espTimeout);

      if (res.statusCode != 200) throw Exception('status ${res.statusCode}');

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final spots = data['spots'] as List<dynamic>;

      _espOnline = true;

      return spots.map((raw) {
        final s = raw as Map<String, dynamic>;
        final occupied = s['occupied'] as bool? ?? false;
        final reserved = s['reserved'] as bool? ?? false;
        final slot = (s['slot'] as num).toInt();

        return ParkingSpot(
          id: '$slot',
          status: occupied
              ? 'occupied'
              : reserved
                  ? 'reserved'
                  : 'available',
          floor: 1,
          type: 'standard',
        );
      }).toList();
    } catch (_) {
      _espOnline = false;
      rethrow;
    }
  }

  List<ParkingSpot> _mockSpots() {
    const statuses = [
      'available',
      'available',
      'available',
      'occupied',
      'reserved',
      'available',
      'occupied',
      'available',
    ];
    return List.generate(24, (i) {
      final letter = String.fromCharCode(65 + (i ~/ 8));
      final num = (i % 8) + 1;
      return ParkingSpot(
        id: '$letter$num',
        status: statuses[i % 8],
        floor: (i ~/ 8) + 1,
        type: i % 6 == 0
            ? 'disabled'
            : i % 7 == 0
                ? 'ev'
                : 'standard',
      );
    });
  }

  // ── Reserve ────────────────────────────────────────────────────────────────
  Future<Reservation> createReservation({
    required String lotName,
    required String spotId,
    required DateTime startTime,
    required int durationHours,
    required double hourlyRate,
    required bool isHardwareLot,
  }) async {
    if (isHardwareLot) {
      return _createHardwareReservation(
        lotName: lotName,
        spotId: spotId,
        startTime: startTime,
        durationHours: durationHours,
        hourlyRate: hourlyRate,
      );
    }
    return _createMockReservation(
      lotName: lotName,
      spotId: spotId,
      startTime: startTime,
      durationHours: durationHours,
      hourlyRate: hourlyRate,
    );
  }

  Future<Reservation> _createHardwareReservation({
    required String lotName,
    required String spotId,
    required DateTime startTime,
    required int durationHours,
    required double hourlyRate,
  }) async {
    final slotNum = int.tryParse(spotId);
    if (slotNum == null || slotNum < 1 || slotNum > 4) {
      throw Exception('Invalid slot for hardware lot');
    }

    final res = await http
        .post(
          Uri.parse('$espBaseUrl/reserve'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'slot': slotNum,
            'user': 'mobile',
          }),
        )
        .timeout(_espTimeout);

    if (res.statusCode != 200) {
      final body = res.body;
      throw Exception(_parseEspError(body) ?? 'Reservation failed (${res.statusCode})');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final pin = (data['pin'] as num).toInt().toString();
    final slot = (data['slot'] as num).toInt();

    _espOnline = true;

    return Reservation(
      id: 'R${DateTime.now().millisecondsSinceEpoch}',
      spotId: '$slot',
      lotName: lotName,
      startTime: startTime,
      endTime: startTime.add(Duration(hours: durationHours)),
      pin: pin,
      baseRate: hourlyRate,
      cost: hourlyRate * durationHours,
      isHardwareReservation: true,
    );
  }

  Future<Reservation> _createMockReservation({
    required String lotName,
    required String spotId,
    required DateTime startTime,
    required int durationHours,
    required double hourlyRate,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return Reservation(
      id: 'R${DateTime.now().millisecondsSinceEpoch}',
      spotId: spotId,
      lotName: lotName,
      startTime: startTime,
      endTime: startTime.add(Duration(hours: durationHours)),
      pin: _generateMockPin(),
      baseRate: hourlyRate,
      cost: hourlyRate * durationHours,
      actualEntryTime: startTime,
    );
  }

  /// Cancel a hardware reservation on the ESP (optional — for future UI).
  Future<bool> cancelHardwareReservation({int? slot, String user = 'mobile'}) async {
    try {
      final body = slot != null ? {'slot': slot} : {'user': user};
      final res = await http
          .post(
            Uri.parse('$espBaseUrl/cancel'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_espTimeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Gate ───────────────────────────────────────────────────────────────────
  Future<bool> triggerGate(String action) async {
    final path = action == 'exit' ? '/openExit' : '/openEntry';
    try {
      final res = await http
          .post(Uri.parse('$espBaseUrl$path'))
          .timeout(_espTimeout);
      _espOnline = res.statusCode == 200;
      return res.statusCode == 200;
    } catch (_) {
      _espOnline = false;
      return false;
    }
  }

  // ── Live status poll (for dashboard refresh) ───────────────────────────────
  Future<Map<String, dynamic>?> fetchEspStatus() async {
    try {
      final res = await http
          .get(Uri.parse('$espBaseUrl/status'))
          .timeout(_espTimeout);
      if (res.statusCode != 200) return null;
      _espOnline = true;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      _espOnline = false;
      return null;
    }
  }

  // ── Payment (mock — not on ESP) ────────────────────────────────────────────
  Future<PaymentResult> processPayment({
    required double amount,
    required PaymentMethod method,
    required String reservationId,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    return PaymentResult(
      success: true,
      method: method,
      amountPaid: amount,
      receiptId: 'RCP-${DateTime.now().millisecondsSinceEpoch}',
      paidAt: DateTime.now(),
    );
  }

  String _generateMockPin() {
    final n = DateTime.now().millisecondsSinceEpoch % 9000 + 1000;
    return n.toString();
  }

  String? _parseEspError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['error'] as String?;
    } catch (_) {
      return null;
    }
  }
}
