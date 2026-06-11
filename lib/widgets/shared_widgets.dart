// lib/widgets/shared_widgets.dart
//
// Small reusable building blocks used across screens.
// Think of these like LEGO pieces — screens snap them together.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── Gradient Button ───────────────────────────────────────────────────────────
// The main cyan→teal call-to-action button used everywhere.
class GradientButton extends StatelessWidget {
  final String   label;
  final VoidCallback? onTap;    // null = disabled (greyed out)
  final bool     isLoading;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          gradient: disabled
              ? null
              : AppColors.primaryGradient,
          color:    disabled ? AppColors.surfaceAlt : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.black,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: disabled ? AppColors.textMuted : Colors.black, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color:      disabled ? AppColors.textMuted : Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize:   16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────
// Coloured pill badge: "active", "occupied", "available", etc.
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge(this.status, {super.key});

  Color get _bgColor => switch (status.toLowerCase()) {
    'available' || 'active' || 'approved' => AppColors.green.withValues(alpha:0.15),
    'occupied'  || 'denied'               => AppColors.red.withValues(alpha:0.15),
    'reserved'  || 'pending'              => AppColors.amber.withValues(alpha:0.15),
    'ev'                                  => AppColors.cyan.withValues(alpha:0.12),
    _                                     => AppColors.textMuted.withValues(alpha:0.15),
  };

  Color get _textColor => switch (status.toLowerCase()) {
    'available' || 'active' || 'approved' => AppColors.green,
    'occupied'  || 'denied'               => AppColors.red,
    'reserved'  || 'pending'              => AppColors.amber,
    'ev'                                  => AppColors.cyan,
    _                                     => AppColors.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color:        _bgColor,
        borderRadius: BorderRadius.circular(50),
        border:       Border.all(color: _textColor.withValues(alpha:0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color:       _textColor,
          fontSize:    11,
          fontWeight:  FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Info Row ──────────────────────────────────────────────────────────────────
// A label + value row used in detail cards.
// Example:  "Spot"   |   "B3"
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color:      valueColor ?? AppColors.textPrimary,
              fontSize:   13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Divider ───────────────────────────────────────────────────────────
class AppDivider extends StatelessWidget {
  const AppDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      const Divider(color: AppColors.border, height: 1);
}

// ── Loading Overlay ───────────────────────────────────────────────────────────
// Full-screen spinner used while fetching data.
class LoadingView extends StatelessWidget {
  final String message;
  const LoadingView({super.key, this.message = 'Loading...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.cyan, strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AppColors.textSecond, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── App Card ─────────────────────────────────────────────────────────────────
// Standard dark card surface used throughout the app.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const AppCard({super.key, required this.child, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: AppColors.border),
        ),
        child: child,
      ),
    );
  }
}

// ── Live Dot ─────────────────────────────────────────────────────────────────
// Pulsing green dot that indicates real-time / live status.
class LiveDot extends StatefulWidget {
  final Color color;
  const LiveDot({super.key, this.color = AppColors.green});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          color:     widget.color.withValues(alpha:_anim.value),
          shape:     BoxShape.circle,
          boxShadow: [BoxShadow(color: widget.color.withValues(alpha:0.5), blurRadius: 6)],
        ),
      ),
    );
  }
}

// ── Occupancy Progress Bar ────────────────────────────────────────────────────
class OccupancyBar extends StatelessWidget {
  final int    available;
  final int    total;

  const OccupancyBar({super.key, required this.available, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct      = (total - available) / total;
    final barColor = pct > 0.8 ? AppColors.red
                   : pct > 0.5 ? AppColors.amber
                   : AppColors.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$available available',
                style: const TextStyle(color: AppColors.textSecond, fontSize: 12)),
            Text('${(pct * 100).round()}% full',
                style: TextStyle(color: barColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:            pct,
            backgroundColor:  AppColors.surfaceAlt,
            color:            barColor,
            minHeight:        5,
          ),
        ),
      ],
    );
  }
}
