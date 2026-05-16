// lib/services/pricing_service.dart
//
// ═══════════════════════════════════════════════════════════════
//  ALL PRICING LOGIC LIVES HERE.
//  If you want to change any rate, this is the only file to edit.
//
//  Current rules:
//   1. Base hourly rate (set per lot when creating a reservation)
//   2. Peak hour surcharge  → +50% on top of base rate
//        Morning peak : 07:00 – 09:00
//        Evening peak : 17:00 – 19:00
//   3. Weekend surcharge    → +20% on top of base rate
//        Saturday & Sunday
//   Surcharges STACK — a weekend peak hour = +70%
// ═══════════════════════════════════════════════════════════════

// ── Rate constants ─────────────────────────────────────────────────────────────
// Change these numbers to adjust pricing across the whole app.
class PricingRates {
  PricingRates._();

  /// Extra fraction added during peak hours  (0.5 = +50%)
  static const double peakSurcharge    = 0.50;

  /// Extra fraction added on weekends        (0.2 = +20%)
  static const double weekendSurcharge = 0.20;

  /// Peak morning window  (hour of day, 24h)
  static const int morningPeakStart = 7;
  static const int morningPeakEnd   = 9;

  /// Peak evening window
  static const int eveningPeakStart = 17;
  static const int eveningPeakEnd   = 19;
}

// ── Billing breakdown ─────────────────────────────────────────────────────────
// Returned by PricingService.calculate() so the UI can show every line item.
class BillBreakdown {
  final Duration duration;         // how long the car was parked
  final double   baseRate;         // per-hour base (from the lot)
  final double   baseCharge;       // baseRate × hours
  final double   peakSurcharge;    // extra for peak hours (may be 0)
  final double   weekendSurcharge; // extra for weekend     (may be 0)
  final double   subtotal;         // baseCharge + surcharges
  final double   tax;              // 14% VAT
  final double   total;            // subtotal + tax

  // Which surcharges were triggered — used to show labels in the UI
  final bool isPeak;
  final bool isWeekend;

  const BillBreakdown({
    required this.duration,
    required this.baseRate,
    required this.baseCharge,
    required this.peakSurcharge,
    required this.weekendSurcharge,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.isPeak,
    required this.isWeekend,
  });

  // Convenience: hours parked as a readable string e.g. "1h 42m"
  String get durationLabel {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

// ── Pricing service ───────────────────────────────────────────────────────────
class PricingService {
  PricingService._();
  static final PricingService instance = PricingService._();

  // ── Main calculation ────────────────────────────────────────────────────────
  /// Call this when the user taps "Exit" to get the full bill.
  ///
  /// [baseRate]  — hourly rate of the lot (e.g. 5.0 = $5/hr)
  /// [entryTime] — when the car entered (DateTime)
  /// [exitTime]  — when the car exited  (defaults to now)
  BillBreakdown calculate({
    required double   baseRate,
    required DateTime entryTime,
    DateTime?         exitTime,
  }) {
    final exit     = exitTime ?? DateTime.now();
    final duration = exit.difference(entryTime);

    // Always bill at least 15 minutes
    final billableMins = duration.inMinutes < 15 ? 15 : duration.inMinutes;
    final hours        = billableMins / 60.0;

    // Base charge — straight hours × rate
    final baseCharge = _round(baseRate * hours);

    // ── Check surcharges ───────────────────────────────────────────────────
    // We check the ENTRY time to decide surcharges.
    // (Simpler for the user — they know what they're paying when they arrive.)
    final bool isPeak    = _isPeakHour(entryTime);
    final bool isWeekend = _isWeekend(entryTime);

    final double peakExtra    = isPeak    ? _round(baseCharge * PricingRates.peakSurcharge)    : 0;
    final double weekendExtra = isWeekend ? _round(baseCharge * PricingRates.weekendSurcharge) : 0;

    final subtotal = _round(baseCharge + peakExtra + weekendExtra);
    final tax      = _round(subtotal * 0.14); // 14% VAT
    final total    = _round(subtotal + tax);

    return BillBreakdown(
      duration:         duration,
      baseRate:         baseRate,
      baseCharge:       baseCharge,
      peakSurcharge:    peakExtra,
      weekendSurcharge: weekendExtra,
      subtotal:         subtotal,
      tax:              tax,
      total:            total,
      isPeak:           isPeak,
      isWeekend:        isWeekend,
    );
  }

  // ── Live cost estimate ──────────────────────────────────────────────────────
  /// Called every second on the active session screen to show a running cost.
  /// Returns just the total so far (no breakdown needed mid-session).
  double liveCost({required double baseRate, required DateTime entryTime}) {
    return calculate(baseRate: baseRate, entryTime: entryTime).total;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  bool _isPeakHour(DateTime t) {
    final h = t.hour;
    return (h >= PricingRates.morningPeakStart && h < PricingRates.morningPeakEnd) ||
           (h >= PricingRates.eveningPeakStart && h < PricingRates.eveningPeakEnd);
  }

  bool _isWeekend(DateTime t) =>
      t.weekday == DateTime.saturday || t.weekday == DateTime.sunday;

  double _round(double v) => (v * 100).round() / 100;

  // ── UI helpers ──────────────────────────────────────────────────────────────
  /// Returns a short human-readable label for the current pricing context.
  /// Shown on the active session screen so the user always knows why they're
  /// paying what they're paying.
  String pricingContextLabel(DateTime entryTime) {
    final isPeak    = _isPeakHour(entryTime);
    final isWeekend = _isWeekend(entryTime);

    if (isPeak && isWeekend) return '⚡ Weekend Peak Rate';
    if (isPeak)              return '⚡ Peak Hour Rate';
    if (isWeekend)           return '📅 Weekend Rate';
    return '✓ Standard Rate';
  }

  /// Returns the effective rate per hour including surcharges.
  /// Used for the "currently paying X/hr" label on the active session screen.
  double effectiveHourlyRate(double baseRate, DateTime entryTime) {
    double rate = baseRate;
    if (_isPeakHour(entryTime))  rate += baseRate * PricingRates.peakSurcharge;
    if (_isWeekend(entryTime))   rate += baseRate * PricingRates.weekendSurcharge;
    return _round(rate);
  }
}