import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/google_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

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
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(22),
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
                          width: 98,
                          height: 98,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'جدولي',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jadwali',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'سجّل دخولك لإدارة جدولك الدراسي',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _emailController,
                        enabled: !_isBusy,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isBusy ? null : _sendOtp,
                        icon: _sendingOtp
                            ? _buttonProgress(context)
                            : const Icon(Icons.mark_email_read_outlined),
                        label: const Text('إرسال رمز الدخول إلى البريد'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _otpController,
                        enabled: !_isBusy,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'رمز التحقق OTP',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                        onSubmitted: (_) {
                          if (!_isBusy) _verifyOtp();
                        },
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isBusy ? null : _verifyOtp,
                        icon: _verifyingOtp
                            ? _buttonProgress(context)
                            : const Icon(Icons.verified_user_outlined),
                        label: const Text('تحقق وتسجيل دخول'),
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
                        label: const Text('المتابعة باستخدام Google'),
                      ),
                      if (_showAppleButton) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _isBusy ? null : _signInWithApple,
                          icon: _signingInWithApple
                              ? _buttonProgress(context)
                              : const Icon(Icons.apple),
                          label: const Text('تسجيل الدخول باستخدام Apple'),
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
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      _showError('أدخل بريدًا إلكترونيًا صحيحًا.');
      return;
    }

    setState(() {
      _sendingOtp = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOtp(email: email);
      if (!mounted) return;
      setState(() => _message = 'تم إرسال رمز الدخول إلى بريدك.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال رمز الدخول إلى بريدك.')),
      );
    } catch (error) {
      _showError(_friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final otpCode = _otpController.text.trim();
    if (!_isValidEmail(email)) {
      _showError('أدخل بريدًا إلكترونيًا صحيحًا.');
      return;
    }
    if (otpCode.isEmpty) {
      _showError('أدخل رمز التحقق المرسل إلى بريدك.');
      return;
    }

    setState(() {
      _verifyingOtp = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: otpCode,
        type: OtpType.email,
      );
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
      await GoogleAuthService().signInWithGoogle();
    } on GoogleAuthException catch (error) {
      _showError(error.message);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Google sign-in error: $error');
      }
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
      final rawNonce = Supabase.instance.client.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw const AuthException('لم يتم استلام رمز Apple. حاول مرة أخرى.');
      }

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: identityToken,
        nonce: rawNonce,
      );

      final fullName =
          '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim();
      if (fullName.isNotEmpty) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            data: {
              'full_name': fullName,
              'given_name': credential.givenName,
              'family_name': credential.familyName,
            },
          ),
        );
      }
    } catch (error) {
      _showError(_friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _signingInWithApple = false);
    }
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  String _friendlyAuthError(Object error) {
    if (error is AuthException) {
      if (_isAppleAudienceError(error.message)) {
        return _appleAudienceMessage;
      }
      return error.message;
    }
    final details = error.toString();
    if (_isAppleAudienceError(details)) {
      return _appleAudienceMessage;
    }
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
      return 'تعذر تسجيل الدخول عبر Apple. تأكد من تفعيل Sign in with Apple في Apple Developer/Xcode واستخدم جهازًا أو حساب Apple صالحًا.';
    }
    return 'تعذر تسجيل الدخول. التفاصيل: $details';
  }

  bool _isAppleAudienceError(String details) {
    return details.contains('Unacceptable audience in id_token') ||
        details.contains('com.hafdev.jadwly');
  }

  String get _appleAudienceMessage {
    return 'Apple غير مضبوط في Supabase. أضف com.hafdev.jadwly في Apple Client IDs.';
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _message = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
