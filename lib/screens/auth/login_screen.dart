import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../services/google_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  late final AuthService? _authService;

  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _signingInWithGoogle = false;
  bool _signingInWithApple = false;
  String? _message;

  bool get _isBusy =>
      _sendingOtp ||
      _verifyingOtp ||
      _signingInWithGoogle ||
      _signingInWithApple;

  bool get _showAppleButton =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _authService = AuthService.instanceOrNull;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(strings.signIn)),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.95),
              colorScheme.surface,
              colorScheme.secondaryContainer.withValues(alpha: 0.70),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.14),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        strings.loginTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.loginSubtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _emailController,
                        enabled: !_isBusy,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: strings.email,
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _isBusy ? null : _sendOtp,
                        icon: _sendingOtp
                            ? _buttonProgress(context)
                            : const Icon(Icons.mark_email_read_outlined),
                        label: Text(strings.sendOtp),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _otpController,
                        enabled: !_isBusy,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: strings.emailOtp,
                          prefixIcon: const Icon(Icons.pin_outlined),
                        ),
                        onSubmitted: (_) {
                          if (!_isBusy) _verifyOtp();
                        },
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _isBusy ? null : _verifyOtp,
                        icon: _verifyingOtp
                            ? _buttonProgress(context)
                            : const Icon(Icons.verified_user_outlined),
                        label: Text(strings.verifyOtp),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _message!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: _isBusy ? null : _signInWithGoogle,
                        icon: _signingInWithGoogle
                            ? _buttonProgress(context)
                            : const Icon(Icons.g_mobiledata_rounded),
                        label: Text(strings.continueWithGoogle),
                      ),
                      if (_showAppleButton) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _isBusy ? null : _signInWithApple,
                          icon: _signingInWithApple
                              ? _buttonProgress(context)
                              : const Icon(Icons.apple),
                          label: Text(strings.continueWithApple),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buttonProgress(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Future<void> _sendOtp() async {
    final strings = AppStrings.read(context);
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      _showError(strings.invalidEmail);
      return;
    }

    setState(() {
      _sendingOtp = true;
      _message = null;
    });
    try {
      await _requireAuthService().sendEmailOtp(email);
      if (!mounted) return;
      setState(() => _message = strings.otpSent);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.otpSent)),
      );
    } catch (error) {
      _showError(_friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _verifyOtp() async {
    final strings = AppStrings.read(context);
    final email = _emailController.text.trim();
    final otpCode = _otpController.text.trim();
    if (!_isValidEmail(email)) {
      _showError(strings.invalidEmail);
      return;
    }
    if (otpCode.isEmpty) {
      _showError(strings.enterOtp);
      return;
    }

    setState(() {
      _verifyingOtp = true;
      _message = null;
    });
    try {
      await _requireAuthService().verifyEmailOtp(
        email: email,
        token: otpCode,
      );
      _closeAfterSignIn();
    } catch (error) {
      _showError(_friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _verifyingOtp = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _signingInWithGoogle = true;
      _message = null;
    });
    try {
      final signedIn = await _requireAuthService().signInWithGoogle();
      if (signedIn) _closeAfterSignIn();
    } on GoogleAuthException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(_friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _signingInWithGoogle = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _signingInWithApple = true;
      _message = null;
    });
    try {
      await _requireAuthService().signInWithApple();
      _closeAfterSignIn();
    } catch (error) {
      _showError(_friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _signingInWithApple = false);
    }
  }

  AuthService _requireAuthService() {
    final authService = _authService;
    if (authService == null) {
      throw const AuthException('Supabase is not initialized.');
    }
    return authService;
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  String _friendlyAuthError(Object error) {
    if (error is AuthException) return error.message;
    final details = error.toString();
    if (details.contains('Invalid API key') ||
        details.contains('JWT') ||
        details.contains('401')) {
      return 'مفتاح Supabase غير صحيح. استخدم publishable أو anon/public key فقط.';
    }
    if (details.contains('SocketException') ||
        details.contains('ClientException') ||
        details.contains('Failed host lookup')) {
      return 'تعذر الاتصال بـ Supabase. تحقق من اتصال الإنترنت وإعدادات المشروع.';
    }
    if (details.contains('SignInWithAppleAuthorizationException') ||
        details.contains('AuthorizationErrorCode.unknown') ||
        details.contains('AuthorizationError error 1000')) {
      return 'تعذر تسجيل الدخول عبر Apple. تأكد من تفعيل Sign in with Apple.';
    }
    return 'تعذر تسجيل الدخول. التفاصيل: $details';
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _message = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _closeAfterSignIn() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}
