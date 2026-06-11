// lib/screens/dashboard_screen.dart
//
// Home screen after login.
// Shows the user's active reservation and nearby lots.
// Tapping "Reserve" navigates to ReserveScreen.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/parking_service.dart';
import '../models/reservation.dart';
import 'reserve_screen.dart';
import 'entry_pin_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  List<ParkingLot>? _lots;          // null = still loading
  Reservation?      _activeRes;     // the user's current reservation (if any)
  bool              _lotsError = false;
  bool              _espOnline = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final lots = await ParkingService.instance.getLots();
      if (mounted) {
        setState(() {
          _lots = lots;
          _espOnline = ParkingService.instance.espOnline;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _lotsError = true);
    }
  }

  // Called when user returns from ReserveScreen with a new reservation
  void _onReservationCreated(Reservation res) {
    setState(() => _activeRes = res);
  }

  void _handleLogout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
          child: const Text('PARKIQ',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20,
                  letterSpacing: 1.5, color: Colors.white)),
        ),
        actions: [
          // Live indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                LiveDot(color: _espOnline ? AppColors.green : AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  _espOnline ? 'ESP Live' : 'ESP Offline',
                  style: TextStyle(
                    color: _espOnline ? AppColors.green : AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Logout button
          IconButton(
            icon:    const Icon(Icons.logout_rounded, color: AppColors.textSecond),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),

      body: RefreshIndicator(
        color:    AppColors.cyan,
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Greeting ────────────────────────────────────────────────────
            _GreetingHeader(),
            const SizedBox(height: 24),

            // ── Active reservation banner (only shown when user has one) ──
            if (_activeRes != null) ...[
              _ActiveReservationBanner(
                reservation: _activeRes!,
                onViewPin: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EntryPinScreen(reservation: _activeRes!),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Quick stats row ─────────────────────────────────────────────
            _QuickStatsRow(lots: _lots),
            const SizedBox(height: 24),

            // ── Reserve button ──────────────────────────────────────────────
            GradientButton(
              label: 'Reserve a Parking Spot',
              icon:  Icons.add_circle_outline_rounded,
              onTap: () async {
                final result = await Navigator.push<Reservation>(
                  context,
                  MaterialPageRoute(builder: (_) => const ReserveScreen()),
                );
                if (result != null) _onReservationCreated(result);
              },
            ),

            const SizedBox(height: 28),

            // ── Nearby lots ─────────────────────────────────────────────────
            const Text('Nearby Parking Lots',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            if (_lots == null && !_lotsError)
              const LoadingView(message: 'Fetching lots...')
            else if (_lotsError)
              _ErrorCard(onRetry: _loadData)
            else
              ...(_lots!.map((lot) => _LotCard(lot: lot))),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets (private to this file) ────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning'
                   : hour < 17 ? 'Good afternoon'
                   : 'Good evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$greeting, Ahmed 👋',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          _formatDate(DateTime.now()),
          style: const TextStyle(color: AppColors.textSecond, fontSize: 13),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    const days   = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ── Active Reservation Banner ─────────────────────────────────────────────────
class _ActiveReservationBanner extends StatelessWidget {
  final Reservation  reservation;
  final VoidCallback onViewPin;

  const _ActiveReservationBanner({
    required this.reservation,
    required this.onViewPin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.cyan.withOpacity(0.1),
            AppColors.teal.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cyan.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const LiveDot(color: AppColors.green),
              const SizedBox(width: 8),
              const Text('Active Reservation',
                  style: TextStyle(color: AppColors.green,
                      fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              StatusBadge(reservation.spotId),
            ],
          ),
          const SizedBox(height: 12),

          // Lot name
          Text(reservation.lotName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Ends at ${_formatTime(reservation.endTime)}',
            style: const TextStyle(color: AppColors.textSecond, fontSize: 13),
          ),

          const SizedBox(height: 16),

          // View PIN button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onViewPin,
              icon: const Icon(Icons.qr_code_2_rounded,
                  color: AppColors.cyan, size: 18),
              label: const Text('View Entry PIN & QR',
                  style: TextStyle(color: AppColors.cyan)),
              style: OutlinedButton.styleFrom(
                side:   const BorderSide(color: AppColors.cyan),
                shape:  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}

// ── Quick Stats Row ───────────────────────────────────────────────────────────
class _QuickStatsRow extends StatelessWidget {
  final List<ParkingLot>? lots;
  const _QuickStatsRow({required this.lots});

  @override
  Widget build(BuildContext context) {
    final totalAvail = lots?.fold<int>(0, (s, l) => s + l.available) ?? 0;
    final totalSpots = lots?.fold<int>(0, (s, l) => s + l.total)     ?? 0;

    return Row(
      children: [
        _StatTile(value: '${lots?.length ?? 0}', label: 'Lots Nearby',
            color: AppColors.cyan),
        const SizedBox(width: 12),
        _StatTile(value: '$totalAvail', label: 'Free Spots',
            color: AppColors.green),
        const SizedBox(width: 12),
        _StatTile(value: totalSpots > 0
            ? '${((totalSpots - totalAvail) / totalSpots * 100).round()}%'
            : '--',
            label: 'Occupied',    color: AppColors.amber),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color  color;

  const _StatTile({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                color: color, fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Lot Card ──────────────────────────────────────────────────────────────────
class _LotCard extends StatelessWidget {
  final ParkingLot lot;
  const _LotCard({required this.lot});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(lot.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (lot.isHardwareLot) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (lot.espOnline ? AppColors.green : AppColors.red)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (lot.espOnline ? AppColors.green : AppColors.red)
                                  .withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            lot.espOnline ? 'LIVE' : 'OFFLINE',
                            style: TextStyle(
                              color: lot.espOnline ? AppColors.green : AppColors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        AppColors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('\$${lot.price}/hr',
                      style: const TextStyle(color: AppColors.teal,
                          fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Address + distance
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    color: AppColors.textMuted, size: 13),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('${lot.address}  ·  ${lot.distance}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),

            const SizedBox(height: 12),
            OccupancyBar(available: lot.available, total: lot.total),
          ],
        ),
      ),
    );
  }
}

// ── Error Card ────────────────────────────────────────────────────────────────
class _ErrorCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 36),
          const SizedBox(height: 8),
          const Text('Could not load lots', style: TextStyle(color: AppColors.textSecond)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry,
              child: const Text('Retry', style: TextStyle(color: AppColors.cyan))),
        ],
      ),
    );
  }
}
