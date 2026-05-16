// lib/screens/reserve_screen.dart
//
// 3-step reservation flow:
//   Step 1 → Pick a lot + date + duration
//   Step 2 → Pick a specific spot from the map
//   Step 3 → Review & confirm
//
// On confirm, returns the new Reservation to DashboardScreen.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/parking_service.dart';
import '../models/reservation.dart';

class ReserveScreen extends StatefulWidget {
  const ReserveScreen({super.key});

  @override
  State<ReserveScreen> createState() => _ReserveScreenState();
}

class _ReserveScreenState extends State<ReserveScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  int _step = 1; // which step we're on: 1, 2, or 3

  // Step 1 selections
  ParkingLot? _selectedLot;
  DateTime    _date     = DateTime.now();
  TimeOfDay   _time     = TimeOfDay.now();
  int         _duration = 2; // hours

  // Step 2 selection
  ParkingSpot? _selectedSpot;

  // Data loading
  List<ParkingLot>?  _lots;
  List<ParkingSpot>? _spots;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLots();
  }

  // ── Data loading ──────────────────────────────────────────────────────────
  Future<void> _loadLots() async {
    setState(() => _isLoading = true);
    final lots = await ParkingService.instance.getLots();
    if (mounted) setState(() { _lots = lots; _isLoading = false; });
  }

  Future<void> _loadSpots() async {
    if (_selectedLot == null) return;
    setState(() { _isLoading = true; _spots = null; });
    final spots = await ParkingService.instance.getSpots(lotId: _selectedLot!.id);
    if (mounted) setState(() { _spots = spots; _isLoading = false; });
  }

  // ── Step navigation ────────────────────────────────────────────────────────
  void _goToStep2() {
    if (_selectedLot == null) {
      _showSnack('Please select a parking lot first.');
      return;
    }
    _loadSpots();
    setState(() => _step = 2);
  }

  void _goToStep3() {
    if (_selectedSpot == null) {
      _showSnack('Please select an available spot.');
      return;
    }
    setState(() => _step = 3);
  }

  // ── Confirm reservation ────────────────────────────────────────────────────
  Future<void> _confirm() async {
    setState(() => _isLoading = true);

    final startTime = DateTime(
      _date.year, _date.month, _date.day,
      _time.hour, _time.minute,
    );

    final reservation = await ParkingService.instance.createReservation(
      lotName:      _selectedLot!.name,
      spotId:       _selectedSpot!.id,
      startTime:    startTime,
      durationHours: _duration,
      hourlyRate:   _selectedLot!.price,
    );

    if (!mounted) return;

    // Return the reservation to DashboardScreen
    Navigator.pop(context, reservation);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  double get _totalCost => (_selectedLot?.price ?? 0) * _duration;

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:  Text(msg),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _date,
      firstDate:   DateTime.now(),
      lastDate:    DateTime.now().add(const Duration(days: 30)),
      builder:     (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.cyan),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context:     context,
      initialTime: _time,
      builder:     (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.cyan),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reserve — Step $_step of 3'),
        leading: _step == 1
            ? const BackButton()
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step--),
              ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step progress bar at the top
            _StepIndicator(current: _step, total: 3),

            // Page content
            Expanded(
              child: switch (_step) {
                1 => _Step1Body(
                    lots:          _lots,
                    selectedLot:   _selectedLot,
                    isLoading:     _isLoading,
                    date:          _date,
                    time:          _time,
                    duration:      _duration,
                    onPickLot:     (lot) => setState(() => _selectedLot = lot),
                    onPickDate:    _pickDate,
                    onPickTime:    _pickTime,
                    onDurationChanged: (v) => setState(() => _duration = v),
                  ),
                2 => _Step2Body(
                    spots:       _spots,
                    isLoading:   _isLoading,
                    selectedId:  _selectedSpot?.id,
                    onPickSpot:  (s) => setState(() => _selectedSpot = s),
                  ),
                _ => _Step3Body(
                    lot:        _selectedLot!,
                    spot:       _selectedSpot!,
                    date:       _date,
                    time:       _time,
                    duration:   _duration,
                    totalCost:  _totalCost,
                    isLoading:  _isLoading,
                  ),
              },
            ),

            // Bottom action button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: GradientButton(
                isLoading: _isLoading,
                label: switch (_step) {
                  1 => 'Continue to Spot Selection',
                  2 => 'Review Booking',
                  _ => 'Confirm & Reserve  —  \$${_totalCost.toStringAsFixed(2)}',
                },
                onTap: _isLoading ? null : switch (_step) {
                  1 => _goToStep2,
                  2 => _goToStep3,
                  _ => _confirm,
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP 1 — Choose lot, date, time, duration
// ═══════════════════════════════════════════════════════════════════════════════
class _Step1Body extends StatelessWidget {
  final List<ParkingLot>? lots;
  final ParkingLot?       selectedLot;
  final bool              isLoading;
  final DateTime          date;
  final TimeOfDay         time;
  final int               duration;
  final ValueChanged<ParkingLot> onPickLot;
  final VoidCallback      onPickDate;
  final VoidCallback      onPickTime;
  final ValueChanged<int> onDurationChanged;

  const _Step1Body({
    required this.lots, required this.selectedLot, required this.isLoading,
    required this.date, required this.time, required this.duration,
    required this.onPickLot, required this.onPickDate, required this.onPickTime,
    required this.onDurationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Date & time row
        Row(
          children: [
            Expanded(child: _TappableTile(
              icon:    Icons.calendar_today_outlined,
              label:   'Date',
              value:   '${date.day}/${date.month}/${date.year}',
              onTap:   onPickDate,
            )),
            const SizedBox(width: 12),
            Expanded(child: _TappableTile(
              icon:    Icons.access_time_rounded,
              label:   'Time',
              value:   time.format(context),
              onTap:   onPickTime,
            )),
          ],
        ),

        const SizedBox(height: 16),

        // Duration slider
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Duration',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('$duration hour${duration > 1 ? 's' : ''}',
                      style: const TextStyle(color: AppColors.cyan,
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
              Slider(
                value:        duration.toDouble(),
                min:          1,
                max:          12,
                divisions:    11,
                activeColor:  AppColors.cyan,
                inactiveColor: AppColors.surfaceAlt,
                onChanged:    (v) => onDurationChanged(v.round()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('1h', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  Text('12h', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        const Text('Select Parking Lot',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),

        if (isLoading)
          const LoadingView()
        else if (lots == null)
          const Text('Failed to load lots.',
              style: TextStyle(color: AppColors.textMuted))
        else
          ...lots!.map((lot) => _LotOption(
                lot:        lot,
                isSelected: selectedLot?.id == lot.id,
                onTap:      () => onPickLot(lot),
              )),
      ],
    );
  }
}

class _TappableTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final VoidCallback onTap;

  const _TappableTile({
    required this.icon, required this.label,
    required this.value, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.cyan, size: 18),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LotOption extends StatelessWidget {
  final ParkingLot lot;
  final bool       isSelected;
  final VoidCallback onTap;

  const _LotOption({required this.lot, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        isSelected
                ? AppColors.cyan.withOpacity(0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.cyan : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Selection indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:  isSelected ? AppColors.cyan : Colors.transparent,
                  border: Border.all(
                      color: isSelected ? AppColors.cyan : AppColors.textMuted,
                      width: 2),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 12, color: Colors.black)
                    : null,
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lot.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('${lot.address}  ·  ${lot.distance}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    OccupancyBar(available: lot.available, total: lot.total),
                  ],
                ),
              ),

              const SizedBox(width: 12),
              Text('\$${lot.price}/hr',
                  style: const TextStyle(color: AppColors.teal,
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP 2 — Spot picker grid
// ═══════════════════════════════════════════════════════════════════════════════
class _Step2Body extends StatelessWidget {
  final List<ParkingSpot>? spots;
  final String?            selectedId;
  final bool               isLoading;
  final ValueChanged<ParkingSpot> onPickSpot;

  const _Step2Body({
    required this.spots, required this.selectedId,
    required this.isLoading, required this.onPickSpot,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading || spots == null) return const LoadingView(message: 'Loading spots...');

    // Group by floor
    final floors = {1: <ParkingSpot>[], 2: <ParkingSpot>[], 3: <ParkingSpot>[]};
    for (final s in spots!) {
      floors[s.floor]?.add(s);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Legend
        Wrap(
          spacing: 12, runSpacing: 8,
          children: const [
            _LegendItem(color: AppColors.green, label: 'Available'),
            _LegendItem(color: AppColors.red,   label: 'Occupied'),
            _LegendItem(color: AppColors.amber,  label: 'Reserved'),
            _LegendItem(color: AppColors.blue,   label: 'Selected'),
          ],
        ),
        const SizedBox(height: 20),

        // Per-floor grids
        ...floors.entries.map((entry) {
          if (entry.value.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Floor ${entry.key}',
                  style: const TextStyle(color: AppColors.textSecond,
                      fontSize: 12, fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap:  true,
                physics:     const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing:  8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.4,
                children: entry.value.map((spot) {
                  final isSelected = spot.id == selectedId;
                  final Color color = isSelected        ? AppColors.blue
                      : spot.status == 'available'      ? AppColors.green
                      : spot.status == 'occupied'       ? AppColors.red
                      : AppColors.amber; // reserved

                  return GestureDetector(
                    onTap: spot.isAvailable ? () => onPickSpot(spot) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color:        color.withOpacity(isSelected ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border:       Border.all(
                            color: color.withOpacity(isSelected ? 1 : 0.4),
                            width: isSelected ? 1.5 : 1),
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(spot.id,
                              style: TextStyle(
                                  color:      color,
                                  fontSize:   11,
                                  fontWeight: FontWeight.w700)),
                          if (spot.type == 'ev')
                            Text('⚡', style: TextStyle(fontSize: 9, color: color)),
                          if (spot.type == 'disabled')
                            Text('♿', style: TextStyle(fontSize: 9, color: color)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          );
        }),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            color:        color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(3),
            border:       Border.all(color: color.withOpacity(0.7)),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: AppColors.textSecond, fontSize: 12)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP 3 — Review & confirm
// ═══════════════════════════════════════════════════════════════════════════════
class _Step3Body extends StatelessWidget {
  final ParkingLot  lot;
  final ParkingSpot spot;
  final DateTime    date;
  final TimeOfDay   time;
  final int         duration;
  final double      totalCost;
  final bool        isLoading;

  const _Step3Body({
    required this.lot, required this.spot, required this.date,
    required this.time, required this.duration, required this.totalCost,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal    = totalCost;
    final bookingFee  = 1.50;
    final grandTotal  = subtotal + bookingFee;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Booking Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),

              InfoRow(label: 'Parking Lot', value: lot.name),
              const AppDivider(),
              InfoRow(label: 'Spot', value: spot.id,
                  valueColor: AppColors.cyan),
              const AppDivider(),
              InfoRow(label: 'Date',
                  value: '${date.day}/${date.month}/${date.year}'),
              const AppDivider(),
              InfoRow(label: 'Start Time', value: time.format(context)),
              const AppDivider(),
              InfoRow(label: 'Duration',
                  value: '$duration hour${duration > 1 ? 's' : ''}'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        AppCard(
          child: Column(
            children: [
              InfoRow(
                label: 'Hourly Rate',
                value: '\$${lot.price.toStringAsFixed(2)}/hr',
              ),
              const AppDivider(),
              InfoRow(
                label: 'Subtotal ($duration hrs)',
                value: '\$${subtotal.toStringAsFixed(2)}',
              ),
              const AppDivider(),
              InfoRow(label: 'Booking Fee', value: '\$${bookingFee.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              const AppDivider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('\$${grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                          color: AppColors.cyan)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Note about PIN
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        AppColors.cyan.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: AppColors.cyan.withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.cyan, size: 16),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'A 4-digit PIN and QR code will be generated after confirming. '
                  'Use them at the gate.',
                  style: TextStyle(color: AppColors.cyan, fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Step indicator at the top of ReserveScreen ────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: List.generate(total * 2 - 1, (i) {
          if (i.isOdd) {
            // connector line between circles
            return Expanded(
              child: Container(
                height: 2,
                color: i ~/ 2 < current - 1
                    ? AppColors.cyan
                    : AppColors.border,
              ),
            );
          }
          final step = i ~/ 2 + 1;
          final done = step < current;
          final active = step == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width:  28, height: 28,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              color:  done || active ? AppColors.cyan : AppColors.surfaceAlt,
              border: Border.all(
                  color: done || active ? AppColors.cyan : AppColors.border,
                  width: 2),
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check, size: 14, color: Colors.black)
                  : Text('$step',
                      style: TextStyle(
                          fontSize:   12,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.black : AppColors.textMuted)),
            ),
          );
        }),
      ),
    );
  }
}
