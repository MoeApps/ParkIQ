// lib/screens/entry_pin_screen.dart
//
// Shows after a reservation is confirmed.
// Displays: PIN digits, QR code, countdown timer, spot info.
// This is the screen the user shows at the gate.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../models/reservation.dart';
import '../services/parking_service.dart';

class EntryPinScreen extends StatefulWidget {
  final Reservation reservation;

  const EntryPinScreen({super.key, required this.reservation});

  @override
  State<EntryPinScreen> createState() => _EntryPinScreenState();
}

class _EntryPinScreenState extends State<EntryPinScreen> {
  // ── Countdown timer ────────────────────────────────────────────────────────
  late Timer  _timer;
  Duration    _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();

    // Tick every second to update the countdown
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    final r = widget.reservation.endTime.difference(DateTime.now());
    if (mounted) {
      setState(() => _remaining = r.isNegative ? Duration.zero : r);
    }
  }

  @override
  void dispose() {
    _timer.cancel(); // always cancel timers to avoid memory leaks
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  bool get _isExpired => _remaining == Duration.zero;

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String get _countdownText {
    if (_isExpired) return 'EXPIRED';
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60);
    final s = _remaining.inSeconds.remainder(60);
    return '${_twoDigits(h)}:${_twoDigits(m)}:${_twoDigits(s)}';
  }

  // The string encoded in the QR code — when your ESP scans this it
  // can validate and open the gate.
  String get _qrData =>
      'PARKIQ:${widget.reservation.id}:${widget.reservation.pin}:${widget.reservation.spotId}';

  // ── UI ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final res = widget.reservation;
    final isHardware = res.isHardwareReservation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entry Status'),
        actions: [
          // Status badge in the app bar
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: StatusBadge(_isExpired ? 'EXPIRED' : 'ACTIVE'),
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Gate status banner ─────────────────────────────────────────
            _GateStatusBanner(isExpired: _isExpired, isHardware: isHardware),

            const SizedBox(height: 20),

            // ── PIN display ────────────────────────────────────────────────
            AppCard(
              child: Column(
                children: [
                  const Text('Entry PIN',
                      style: TextStyle(color: AppColors.textSecond,
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),

                  // PIN digits — shown as individual boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: res.pin.split('').map((digit) =>
                      _PinDigitBox(digit: digit, expired: _isExpired),
                    ).toList(),
                  ),

                  const SizedBox(height: 12),
                  Text(
                    _isExpired
                        ? 'This PIN has expired'
                        : isHardware
                            ? 'At the gate: press 2, then enter this PIN on the keypad'
                            : 'Enter this PIN at the gate keypad',
                    style: TextStyle(
                      color:    _isExpired ? AppColors.red : AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── QR code (demo lots — ESP uses physical keypad) ─────────────
            if (!isHardware) AppCard(
              child: Column(
                children: [
                  const Text('Scan at Gate',
                      style: TextStyle(color: AppColors.textSecond,
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),

                  // White background for QR readability
                  Container(
                    padding:     const EdgeInsets.all(12),
                    decoration:  BoxDecoration(
                      color:        Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data:           _qrData,
                      version:        QrVersions.auto,
                      size:           180,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color:    Color(0xFF05060F),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color:           Color(0xFF05060F),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Text(
                    'ID: ${res.id}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11,
                        fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),

            if (!isHardware) const SizedBox(height: 16),

            if (isHardware)
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.sensors, color: AppColors.cyan, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Exit: drive to the exit sensor and enter this PIN '
                        'on the physical keypad. Billing is handled by the ESP.',
                        style: const TextStyle(
                          color: AppColors.textSecond,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (isHardware) const SizedBox(height: 16),

            // ── Countdown timer ────────────────────────────────────────────
            AppCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Time Remaining',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      if (!_isExpired) const LiveDot(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(
                    _countdownText,
                    style: TextStyle(
                      fontSize:   40,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color:    _isExpired ? AppColors.red : AppColors.cyan,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'Ends at ${_formatTime(res.endTime)}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Reservation details ────────────────────────────────────────
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reservation Details',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),

                  InfoRow(label: 'Booking ID', value: res.id),
                  const AppDivider(),
                  InfoRow(label: 'Location',   value: res.lotName),
                  const AppDivider(),
                  InfoRow(label: 'Spot',       value: res.spotId,
                      valueColor: AppColors.cyan),
                  const AppDivider(),
                  InfoRow(label: 'Start',      value: _formatTime(res.startTime)),
                  const AppDivider(),
                  InfoRow(label: 'End',        value: _formatTime(res.endTime)),
                  const AppDivider(),
                  InfoRow(
                    label:      'Total Cost',
                    value:      '\$${res.cost.toStringAsFixed(2)}',
                    valueColor: AppColors.teal,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Bottom actions ─────────────────────────────────────────────
            if (!_isExpired) ...[
              if (isHardware)
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await ParkingService.instance.triggerGate('open');
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok
                            ? 'Entry gate open command sent to ESP'
                            : 'Could not reach ESP. Check ParkingSystem WiFi.'),
                        backgroundColor: AppColors.surface,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.lock_open_rounded,
                      color: AppColors.green),
                  label: const Text('Override: Open Entry Gate',
                      style: TextStyle(color: AppColors.green)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    side: const BorderSide(color: AppColors.green),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              if (isHardware) const SizedBox(height: 12),
            ],

            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon:  const Icon(Icons.home_outlined,
                  color: AppColors.textSecond),
              label: const Text('Back to Dashboard',
                  style: TextStyle(color: AppColors.textSecond)),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime d) =>
      '${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';
}

// ── Gate Status Banner ────────────────────────────────────────────────────────
class _GateStatusBanner extends StatelessWidget {
  final bool isExpired;
  final bool isHardware;
  const _GateStatusBanner({required this.isExpired, this.isHardware = false});

  @override
  Widget build(BuildContext context) {
    final color   = isExpired ? AppColors.red   : AppColors.green;
    final icon    = isExpired ? Icons.cancel_outlined : Icons.check_circle_outline;
    final label   = isExpired ? 'Reservation Expired' : 'Entry Approved';
    final subtext = isExpired
        ? 'This reservation is no longer valid.'
        : isHardware
            ? 'Reserved on live hardware. Use the physical gate keypad to enter.'
            : 'Your reservation is active. Show QR or PIN at the gate.';

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 48),
          const SizedBox(height: 12),
          Text(label,
              style: TextStyle(
                  color:      color,
                  fontSize:   20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtext,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color:    AppColors.textSecond,
                  fontSize: 13,
                  height:   1.5)),
        ],
      ),
    );
  }
}

// ── PIN Digit Box ─────────────────────────────────────────────────────────────
class _PinDigitBox extends StatelessWidget {
  final String digit;
  final bool   expired;

  const _PinDigitBox({required this.digit, required this.expired});

  @override
  Widget build(BuildContext context) {
    final color = expired ? AppColors.red : AppColors.cyan;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width:  56, height: 68,
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Center(
        child: Text(
          digit,
          style: TextStyle(
            fontSize:   28,
            fontWeight: FontWeight.w800,
            color:      color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
