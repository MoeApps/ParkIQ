// lib/screens/login_screen.dart
//
// The first screen the user sees.
// Calls ParkingService.login() and navigates to Dashboard on success.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/parking_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  final _emailCtrl    = TextEditingController(text: 'ahmed@example.com');
  final _passwordCtrl = TextEditingController(text: '1234');
  bool  _isLoading    = false;
  bool  _obscure      = true;   // toggle password visibility
  String? _errorMsg;

  @override
  void dispose() {
    // Always clean up controllers when the screen is removed
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Login Logic ─────────────────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    setState(() { _isLoading = true; _errorMsg = null; });

    final ok = await ParkingService.instance.login(
      _emailCtrl.text.trim(),
      _passwordCtrl.text.trim(),
    );

    if (!mounted) return; // screen was closed while waiting

    if (ok) {
      // Go to Dashboard and remove Login from the back-stack
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMsg  = 'Invalid email or password. Try again.';
      });
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // ── Logo + headline ────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    // Logo icon
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        gradient:     AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.local_parking_rounded,
                          color: Colors.black, size: 36),
                    ),
                    const SizedBox(height: 20),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppColors.primaryGradient.createShader(bounds),
                      child: const Text(
                        'PARKIQ',
                        style: TextStyle(
                          fontSize:   32,
                          fontWeight: FontWeight.w900,
                          color:      Colors.white, // overridden by shader
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Smart Parking & Access Control',
                      style: TextStyle(color: AppColors.textSecond, fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // ── Form card ──────────────────────────────────────────────────
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sign In',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('Enter your credentials to continue',
                        style: TextStyle(color: AppColors.textSecond, fontSize: 13)),

                    const SizedBox(height: 24),

                    // Email field
                    const Text('Email',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecond,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    TextField(
                      controller:   _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style:        const TextStyle(color: AppColors.textPrimary),
                      decoration:   const InputDecoration(
                        hintText:    'ahmed@example.com',
                        prefixIcon:  Icon(Icons.email_outlined,
                            color: AppColors.textMuted, size: 18),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Password field
                    const Text('Password',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecond,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      style:       const TextStyle(color: AppColors.textPrimary),
                      decoration:  InputDecoration(
                        hintText:    '••••••••',
                        prefixIcon:  const Icon(Icons.lock_outline,
                            color: AppColors.textMuted, size: 18),
                        // Eye icon to show/hide password
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off_outlined
                                     : Icons.visibility_outlined,
                            color: AppColors.textMuted,
                            size:  18,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      onSubmitted: (_) => _handleLogin(), // login on keyboard "done"
                    ),

                    // Error message (shown only when login fails)
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:        AppColors.red.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:       Border.all(color: AppColors.red.withValues(alpha:0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.red, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_errorMsg!,
                                style: const TextStyle(
                                    color: AppColors.red, fontSize: 13))),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Sign In button
                    GradientButton(
                      label:     'Sign In',
                      isLoading: _isLoading,
                      onTap:     _isLoading ? null : _handleLogin,
                      icon:      Icons.arrow_forward_rounded,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Demo hint ──────────────────────────────────────────────────
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color:        AppColors.cyan.withValues(alpha:0.05),
                    borderRadius: BorderRadius.circular(10),
                    border:       Border.all(color: AppColors.cyan.withValues(alpha:0.15)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, color: AppColors.cyan, size: 14),
                      SizedBox(width: 8),
                      Text('Demo: any email + 4+ char password',
                          style: TextStyle(color: AppColors.cyan, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
