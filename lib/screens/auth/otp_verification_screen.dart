import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'dart:async';

import '../../providers/auth_provider.dart';
import '../driver/driver_dashboard.dart';
import '../passenger/passenger_dashboard.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String password;
  final String name;
  final String role;
  final String phone;

  const OtpVerificationScreen({
    Key? key,
    required this.email,
    required this.password,
    required this.name,
    required this.role,
    required this.phone,
  }) : super(key: key);

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with SingleTickerProviderStateMixin {

  fb_auth.User? _currentUser;
  bool _isCheckingStatus = false;
  bool _isResending = false;
  int _resendTimer = 60; // Start with 60 seconds (initial email already sent)
  Timer? _timer;
  DateTime? _lastEmailSentTime;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _currentUser = fb_auth.FirebaseAuth.instance.currentUser;

    if (_currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSnackBar('Authentication error. Please sign up again.', isError: true);
        Navigator.pop(context);
      });
      return;
    }

    // Setup animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();

    // Record that initial email was just sent (from signup screen)
    _lastEmailSentTime = DateTime.now();

    // Start the 60-second countdown immediately since email was already sent
    _startResendTimer();

    // Show confirmation message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSnackBar('Verification link sent to ${widget.email}', isError: false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer = 60;
    _timer?.cancel();

    if (mounted) {
      setState(() {});
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
      } else {
        timer.cancel();
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  Future<void> _sendVerificationEmail() async {
    if (_currentUser == null) return;

    // Check if we're within the rate limit window (60 seconds)
    if (_lastEmailSentTime != null) {
      final timeSinceLastEmail = DateTime.now().difference(_lastEmailSentTime!);
      if (timeSinceLastEmail.inSeconds < 60) {
        final remainingSeconds = 60 - timeSinceLastEmail.inSeconds;
        _showSnackBar(
          'Please wait $remainingSeconds more seconds before resending',
          isError: true,
        );
        return;
      }
    }

    // Double-check UI state
    if (_isResending || _resendTimer > 0) {
      return;
    }

    setState(() => _isResending = true);

    try {
      // Reload user to get latest verification status
      await _currentUser!.reload();
      _currentUser = fb_auth.FirebaseAuth.instance.currentUser;

      // If already verified, no need to send
      if (_currentUser!.emailVerified) {
        if (mounted) {
          _showSnackBar('Email already verified!', isError: false);
          setState(() => _isResending = false);
        }
        return;
      }

      // Send the verification email
      await _currentUser!.sendEmailVerification();

      // Record the time we sent the email
      _lastEmailSentTime = DateTime.now();

      if (!mounted) return;

      // Start the countdown timer
      _startResendTimer();

      _showSnackBar('New verification link sent successfully!', isError: false);

    } on fb_auth.FirebaseAuthException catch (e) {
      if (!mounted) return;

      String errorMessage = 'Error sending verification email';

      if (e.code == 'too-many-requests') {
        errorMessage = 'Too many requests. Please wait at least 60 seconds before trying again.';
        // Set a timer even if Firebase rejected it
        _lastEmailSentTime = DateTime.now();
        _startResendTimer();
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.message != null) {
        errorMessage = e.message!;
      }

      _showSnackBar(errorMessage, isError: true);

    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Unexpected error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _checkVerificationStatus() async {
    if (_currentUser == null || _isCheckingStatus) return;

    setState(() => _isCheckingStatus = true);

    try {
      // Reload user to get fresh verification status from Firebase
      await _currentUser!.reload();
      _currentUser = fb_auth.FirebaseAuth.instance.currentUser;

      if (_currentUser == null) {
        if (!mounted) return;
        _showSnackBar('Session expired. Please sign up again.', isError: true);
        Navigator.pop(context);
        return;
      }

      if (_currentUser!.emailVerified) {
        // Email is verified! Complete the signup process
        if (!mounted) return;

        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        bool success = await authProvider.completeSignup(
          email: widget.email,
          password: widget.password,
          name: widget.name,
          phone: widget.phone,
          role: widget.role,
        );

        if (!mounted) return;

        if (success) {
          _showSnackBar('Email verified successfully! Welcome!', isError: false);

          // Small delay to show success message
          await Future.delayed(const Duration(milliseconds: 800));

          if (mounted) {
            _navigateToDashboard();
          }
        } else {
          _showSnackBar(
            authProvider.errorMessage ?? 'Signup failed after email verification.',
            isError: true,
          );
        }
      } else {
        // Email not yet verified
        if (!mounted) return;
        _showSnackBar(
          'Email not verified yet. Please check your inbox (and spam folder), click the link, then try again.',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error checking verification: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isCheckingStatus = false);
      }
    }
  }

  void _navigateToDashboard() {
    final role = widget.role.toLowerCase();
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
        role == 'driver'
            ? const DriverDashboard()
            : const PassengerDashboard(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
          (route) => false,
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final loading = _isCheckingStatus || authProvider.isLoading;

        if (_currentUser == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0D1117), const Color(0xFF161B22)]
                    : [const Color(0xFFF0F4F8), const Color(0xFFE2E8F0)],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.secondary,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withOpacity(0.4),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.mark_email_read_rounded,
                                size: 56,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Title
                            Text(
                              'Check Your Inbox',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Subtitle
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  text: 'A verification link has been sent to\n',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: isDark
                                        ? const Color(0xFFAABBCF)
                                        : const Color(0xFF64748B),
                                  ),
                                  children: [
                                    TextSpan(
                                      text: widget.email,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const TextSpan(
                                      text: '\n\nClick the link in the email to verify your account, then return here and tap the button below.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Verification Card
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : Colors.grey.shade200,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                                    blurRadius: 30,
                                    offset: const Offset(0, 15),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  children: [
                                    // Instructions
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: theme.colorScheme.primary.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            color: theme.colorScheme.primary,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Check your spam folder if you don\'t see the email within a few minutes.',
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                color: isDark ? Colors.white70 : Colors.black87,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Check Status Button
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: loading
                                            ? null
                                            : LinearGradient(
                                          colors: [
                                            theme.colorScheme.primary,
                                            theme.colorScheme.secondary,
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        boxShadow: loading
                                            ? null
                                            : [
                                          BoxShadow(
                                            color: theme.colorScheme.primary.withOpacity(0.5),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: loading ? null : _checkVerificationStatus,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: loading
                                              ? (isDark
                                              ? const Color(0xFF334155)
                                              : Colors.grey.shade300)
                                              : Colors.transparent,
                                          foregroundColor: loading
                                              ? (isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600)
                                              : Colors.white,
                                          shadowColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(vertical: 18),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          minimumSize: const Size(double.infinity, 56),
                                        ),
                                        child: loading
                                            ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 3.0,
                                          ),
                                        )
                                            : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'I Verified My Email',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(Icons.check_circle_outline, size: 20),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Resend Link - Shows countdown or ready state
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      child: TextButton.icon(
                                        onPressed: (_resendTimer > 0 || _isResending || loading)
                                            ? null
                                            : _sendVerificationEmail,
                                        icon: _isResending
                                            ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                                          ),
                                        )
                                            : Icon(
                                          Icons.refresh_rounded,
                                          color: (_resendTimer > 0 || loading)
                                              ? Colors.grey
                                              : theme.colorScheme.primary,
                                        ),
                                        label: Text(
                                          _resendTimer > 0
                                              ? 'Resend available in ${_resendTimer}s'
                                              : 'Resend Verification Link',
                                          style: TextStyle(
                                            color: (_resendTimer > 0 || loading)
                                                ? Colors.grey
                                                : theme.colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Helper text for rate limiting
                                    if (_resendTimer > 45)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          'For security, you can only request a new email once per minute',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Back Button
                            TextButton.icon(
                              onPressed: loading
                                  ? null
                                  : () {
                                _timer?.cancel();
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.arrow_back_rounded),
                              label: const Text('Back to Signup'),
                              style: TextButton.styleFrom(
                                foregroundColor: loading
                                    ? Colors.grey
                                    : (isDark
                                    ? const Color(0xFFAABBCF)
                                    : const Color(0xFF64748B)),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}