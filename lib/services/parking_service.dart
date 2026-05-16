// lib/services/parking_service.dart
//
// ════════════════════════════════════════════════════════════════
//  THIS IS THE ONLY FILE YOU NEED TO EDIT WHEN YOU CONNECT THE ESP
//
//  Right now every method returns fake (mock) data so the app works
//  without any hardware. When your ESP is ready:
//
//    1. Set ESP_BASE_URL to your ESP's IP address
//    2. Uncomment the real HTTP calls inside each method
//    3. The rest of the app stays exactly the same
// ════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reservation.dart';

const String ESP_BASE_URL = 'http://192.168.1.100';

class ParkingService {
  static final ParkingService instance = ParkingService._();
  ParkingService._();

  // ── Auth ────────────────────────────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    // REAL: POST $ESP_BASE_URL/login  { email, password } → 200 or 401
    return email.isNotEmpty && password.length >= 4;
  }

  // ── Lots ────────────────────────────────────────────────────────────────────
  Future<List<ParkingLot>> getLots() async {
    await Future.delayed(const Duration(milliseconds: 500));
    // REAL: GET $ESP_BASE_URL/lots
    return const [
      ParkingLot(id: 1, name: 'Downtown Lot A',  address: '15 Tahrir Square',           available: 18, total: 48,  distance: '0.3 km', price: 5),
      ParkingLot(id: 2, name: 'Airport Lot B',   address: 'Cairo International Airport', available: 34, total: 120, distance: '1.2 km', price: 8),
      ParkingLot(id: 3, name: 'Mall Lot C',      address: 'Cairo Festival City',         available: 7,  total: 60,  distance: '2.4 km', price: 4),
      ParkingLot(id: 4, name: 'Hospital Lot D',  address: 'Ain Shams Medical Center',    available: 22, total: 40,  distance: '0.8 km', price: 3),
    ];
  }

  // ── Spots ───────────────────────────────────────────────────────────────────
  Future<List<ParkingSpot>> getSpots({int lotId = 1}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    // REAL: GET $ESP_BASE_URL/spots?lot=$lotId
    final statuses = ['available','available','available','occupied','reserved','available','occupied','available'];
    return List.generate(24, (i) {
      final letter = String.fromCharCode(65 + (i ~/ 8));
      final num    = (i % 8) + 1;
      return ParkingSpot(
        id:     '$letter$num',
        status: statuses[i % 8],
        floor:  (i ~/ 8) + 1,
        type:   i % 6 == 0 ? 'disabled' : i % 7 == 0 ? 'ev' : 'standard',
      );
    });
  }

  // ── Reserve ─────────────────────────────────────────────────────────────────
  Future<Reservation> createReservation({
    required String   lotName,
    required String   spotId,
    required DateTime startTime,
    required int      durationHours,
    required double   hourlyRate,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    // REAL: POST $ESP_BASE_URL/reserve  { spot, start, duration }
    return Reservation(
      id:        'R${DateTime.now().millisecondsSinceEpoch}',
      spotId:    spotId,
      lotName:   lotName,
      startTime: startTime,
      endTime:   startTime.add(Duration(hours: durationHours)),
      pin:       _generatePin(),
      baseRate:  hourlyRate,
      cost:      hourlyRate * durationHours,
      // Simulate the car already entered for demo purposes
      actualEntryTime: startTime,
    );
  }

  // ── Gate ────────────────────────────────────────────────────────────────────
  Future<bool> triggerGate(String action) async {
    await Future.delayed(const Duration(milliseconds: 800));
    // REAL: POST $ESP_BASE_URL/gate  { action: "open" | "close" }
    return true;
  }

  // ── Payment ─────────────────────────────────────────────────────────────────
  /// Processes payment. Currently a dummy — always succeeds.
  ///
  /// TO INTEGRATE STRIPE:
  ///   1. Add stripe_sdk to pubspec.yaml
  ///   2. Call your backend to create a PaymentIntent
  ///   3. Use Stripe.instance.confirmPayment(...)
  ///   4. Replace the fake return below with the real result
  ///
  /// TO INTEGRATE PAYPAL:
  ///   1. Add flutter_paypal_payment to pubspec.yaml
  ///   2. Use PaypalPayment widget with your credentials
  Future<PaymentResult> processPayment({
    required double        amount,
    required PaymentMethod method,
    required String        reservationId,
  }) async {
    // Simulate network delay (real payment takes a moment too)
    await Future.delayed(const Duration(seconds: 2));

    // ── REAL Stripe example (uncomment when ready) ──────────────────────────
    // if (method == PaymentMethod.card) {
    //   final response = await http.post(
    //     Uri.parse('$ESP_BASE_URL/payment/intent'),
    //     headers: {'Content-Type': 'application/json'},
    //     body: jsonEncode({'amount': (amount * 100).round(), 'currency': 'usd'}),
    //   );
    //   final clientSecret = jsonDecode(response.body)['client_secret'];
    //   final result = await Stripe.instance.confirmPayment(
    //     paymentIntentClientSecret: clientSecret,
    //     data: const PaymentMethodParams.card(paymentMethodData: PaymentMethodData()),
    //   );
    //   return PaymentResult(
    //     success:    result.status == PaymentIntentsStatus.Succeeded,
    //     method:     method,
    //     amountPaid: amount,
    //     receiptId:  'STR-${result.id}',
    //     paidAt:     DateTime.now(),
    //   );
    // }

    // Mock: always succeeds
    return PaymentResult(
      success:    true,
      method:     method,
      amountPaid: amount,
      receiptId:  'RCP-${DateTime.now().millisecondsSinceEpoch}',
      paidAt:     DateTime.now(),
    );
  }

  String _generatePin() {
    final n = DateTime.now().millisecondsSinceEpoch % 9000 + 1000;
    return n.toString();
  }
}