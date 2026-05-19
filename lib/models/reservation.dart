// lib/models/reservation.dart
//
// Simple data classes. No fancy libraries needed.
// Think of these like "structs" — they just hold data.

// ── Parking Spot ──────────────────────────────────────────────────────────────
class ParkingSpot {
  final String id;
  final String status;   // "available" | "occupied" | "reserved"
  final int    floor;    // 1, 2, or 3
  final String type;     // "standard" | "ev" | "disabled"

  const ParkingSpot({
    required this.id,
    required this.status,
    required this.floor,
    required this.type,
  });

  bool get isAvailable => status == 'available';

  // Build a ParkingSpot from a JSON map (used when ESP sends data)
  factory ParkingSpot.fromJson(Map<String, dynamic> json) {
    return ParkingSpot(
      id:     json['id']     as String,
      status: json['status'] as String,
      floor:  json['floor']  as int,
      type:   json['type']   as String,
    );
  }
}

// ── Reservation ───────────────────────────────────────────────────────────────
class Reservation {
  final String   id;
  final String   spotId;
  final String   lotName;
  final DateTime startTime;
  final DateTime endTime;
  final String   pin;       // 4-digit gate PIN
  final double   baseRate;  // lot hourly rate — used by PricingService
  final double   cost;      // pre-estimated cost at booking time
  final DateTime? actualEntryTime; // set when gate opens
  final DateTime? actualExitTime;  // set when user taps Exit

  const Reservation({
    required this.id,
    required this.spotId,
    required this.lotName,
    required this.startTime,
    required this.endTime,
    required this.pin,
    required this.baseRate,
    required this.cost,
    this.actualEntryTime,
    this.actualExitTime,
  });

  Duration get remaining => endTime.difference(DateTime.now());
  bool get isActive => !remaining.isNegative;
  DateTime get billingStartTime => actualEntryTime ?? startTime;

  Reservation copyWith({
    DateTime? actualEntryTime,
    DateTime? actualExitTime,
  }) {
    return Reservation(
      id: id,
      spotId: spotId,
      lotName: lotName,
      startTime: startTime,
      endTime: endTime,
      pin: pin,
      baseRate: baseRate,
      cost: cost,
      actualEntryTime: actualEntryTime ?? this.actualEntryTime,
      actualExitTime: actualExitTime ?? this.actualExitTime,
    );
  }

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'] as String,
      spotId: json['spot'] as String,
      lotName: json['lot'] as String,
      startTime: DateTime.parse(json['start'] as String),
      endTime: DateTime.parse(json['end'] as String),
      pin: json['pin'] as String,
      baseRate: (json['baseRate'] as num).toDouble(),
      cost: (json['cost'] as num).toDouble(),
    );
  }
}

// ── Parking Lot ───────────────────────────────────────────────────────────────
class ParkingLot {
  final int    id;
  final String name;
  final String address;
  final int    available;
  final int    total;
  final String distance;
  final double price;

  const ParkingLot({
    required this.id,
    required this.name,
    required this.address,
    required this.available,
    required this.total,
    required this.distance,
    required this.price,
  });

  double get occupancyPercent => (total - available) / total;
}

// ── Payment Method ─────────────────────────────────────────────────────────────
enum PaymentMethod { card, cash }

// ── Payment Result ─────────────────────────────────────────────────────────────
class PaymentResult {
  final bool          success;
  final PaymentMethod method;
  final double        amountPaid;
  final String        receiptId;
  final DateTime      paidAt;

  const PaymentResult({
    required this.success,
    required this.method,
    required this.amountPaid,
    required this.receiptId,
    required this.paidAt,
  });
}
