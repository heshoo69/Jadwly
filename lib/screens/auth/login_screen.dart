import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/app_controller.dart';
import '../../l10n/app_strings.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../services/google_auth_service.dart';
import '../app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static final Uri _developerWebsiteUri = Uri.parse('https://haf-dev.com');
  static final Uri _whatsAppSupportUri =
      Uri.parse('https://wa.me/966533801169');

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  late final AuthService? _authService;

  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _signingInWithGoogle = false;
  bool _signingInWithApple = false;
  String _appVersion = '...';
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
    _loadAppVersion();
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
    final iconAsset = theme.brightness == Brightness.dark
        ? 'assets/images/app_icon_dark.png'
        : 'assets/images/app_icon.png';
    return PopScope(
      canPop: false,
      child: Scaffold(
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
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.35),
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
                                iconAsset,
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
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: () => _showSupportSheet(context),
                          icon: const Icon(Icons.support_agent_outlined),
                          label: Text(strings.support),
                        ),
                        const SizedBox(height: 18),
                        _LoginFooter(
                          version: _appVersion,
                          copyright: strings.settingsFooterCopyright,
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

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = packageInfo.version);
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _appVersion = '-');
    }
  }

  Future<void> _openExternalLink(
    BuildContext context,
    Uri uri, {
    required String analyticsSource,
    required String analyticsTarget,
    required String fallbackMessage,
  }) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    await AnalyticsService.logSupportActionOpened(
      source: analyticsSource,
      target: analyticsTarget,
      opened: opened,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fallbackMessage)),
      );
    }
  }

  Future<void> _openMailApp(
    BuildContext context, {
    required String email,
    String? subject,
    required String analyticsSource,
    required String analyticsTarget,
    required String fallbackMessage,
  }) async {
    final mailSubject = subject ?? 'الدعم والاقتراحات - جدولي';
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': mailSubject},
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    await AnalyticsService.logSupportActionOpened(
      source: analyticsSource,
      target: analyticsTarget,
      opened: opened,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fallbackMessage)),
      );
    }
  }

  Future<void> _showSupportSheet(BuildContext context) {
    AnalyticsService.logSupportActionOpened(
      source: 'login',
      target: 'support_sheet',
      opened: true,
    );
    final strings = AppStrings.read(context);
    final theme = Theme.of(context);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.supportAndContact,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _LoginSupportTile(
                icon: Icons.chat_bubble_rounded,
                accentColor: const Color(0xFF25D366),
                title: strings.whatsappSupport,
                subtitle: '+966533801169',
                onTap: () => _openAfterSupportSheetCloses(
                  pageContext: context,
                  sheetContext: sheetContext,
                  action: (pageContext) => _openExternalLink(
                    pageContext,
                    _whatsAppSupportUri,
                    analyticsSource: 'login',
                    analyticsTarget: 'whatsapp',
                    fallbackMessage: '+966533801169',
                  ),
                ),
              ),
              _LoginSupportDivider(color: theme.colorScheme.outlineVariant),
              _LoginSupportTile(
                icon: Icons.alternate_email_rounded,
                title: strings.supportEmail,
                subtitle: 'support@haf-dev.com',
                onTap: () => _openAfterSupportSheetCloses(
                  pageContext: context,
                  sheetContext: sheetContext,
                  action: (pageContext) => _openMailApp(
                    pageContext,
                    email: 'support@haf-dev.com',
                    analyticsSource: 'login',
                    analyticsTarget: 'email',
                    fallbackMessage: 'support@haf-dev.com',
                  ),
                ),
              ),
              _LoginSupportDivider(color: theme.colorScheme.outlineVariant),
              _LoginSupportTile(
                icon: Icons.link_rounded,
                title: strings.website,
                subtitle: 'haf-dev.com',
                onTap: () => _openAfterSupportSheetCloses(
                  pageContext: context,
                  sheetContext: sheetContext,
                  action: (pageContext) => _openExternalLink(
                    pageContext,
                    _developerWebsiteUri,
                    analyticsSource: 'login',
                    analyticsTarget: 'website',
                    fallbackMessage: 'haf-dev.com',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAfterSupportSheetCloses({
    required BuildContext pageContext,
    required BuildContext sheetContext,
    required Future<void> Function(BuildContext context) action,
  }) async {
    Navigator.of(sheetContext).pop();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!pageContext.mounted) return;
    await action(pageContext);
  }

  Future<void> _sendOtp() async {
    final strings = AppStrings.read(context);
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      await AnalyticsService.logAuthAction(action: 'send_otp', success: false);
      _showError(strings.invalidEmail);
      return;
    }
    if (_isLocalReviewEmail(email)) {
      await AnalyticsService.logAuthAction(
        action: 'send_local_review_otp',
        success: true,
      );
      if (!mounted) return;
      setState(() => _message = strings.localReviewOtpHelp);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.localReviewOtpHelp)),
      );
      return;
    }

    setState(() {
      _sendingOtp = true;
      _message = null;
    });
    try {
      await _requireAuthService().sendEmailOtp(email);
      await AnalyticsService.logAuthAction(action: 'send_otp', success: true);
      if (!mounted) return;
      setState(() => _message = strings.otpSent);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.otpSent)),
      );
    } catch (error) {
      await AnalyticsService.logAuthAction(action: 'send_otp', success: false);
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
      await AnalyticsService.logAuthAction(
          action: 'verify_otp', success: false);
      _showError(strings.invalidEmail);
      return;
    }
    if (otpCode.isEmpty) {
      await AnalyticsService.logAuthAction(
          action: 'verify_otp', success: false);
      _showError(strings.enterOtp);
      return;
    }
    if (_isLocalReviewEmail(email)) {
      if (otpCode == AppController.localReviewOtp) {
        final controller = context.read<AppController>();
        await AnalyticsService.logAuthAction(
          action: 'local_review_sign_in',
          success: true,
        );
        await AnalyticsService.logLogin(method: 'local_review');
        await controller.signInLocalReviewAccount();
        _closeAfterSignIn();
      } else {
        await AnalyticsService.logAuthAction(
          action: 'local_review_sign_in',
          success: false,
        );
        _showError(strings.invalidLocalReviewOtp);
      }
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
      await AnalyticsService.logAuthAction(action: 'verify_otp', success: true);
      await AnalyticsService.logLogin(method: 'email_otp');
      _closeAfterSignIn();
    } catch (error) {
      await AnalyticsService.logAuthAction(
          action: 'verify_otp', success: false);
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
      if (signedIn) {
        await AnalyticsService.logAuthAction(
          action: 'google_sign_in',
          success: true,
        );
        await AnalyticsService.logLogin(method: 'google');
        _closeAfterSignIn();
      } else {
        await AnalyticsService.logAuthAction(
          action: 'google_sign_in',
          success: false,
        );
      }
    } on GoogleAuthException catch (error) {
      await AnalyticsService.logAuthAction(
        action: 'google_sign_in',
        success: false,
      );
      _showError(error.message);
    } catch (error) {
      await AnalyticsService.logAuthAction(
        action: 'google_sign_in',
        success: false,
      );
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
      await AnalyticsService.logAuthAction(
        action: 'apple_sign_in',
        success: true,
      );
      await AnalyticsService.logLogin(method: 'apple');
      _closeAfterSignIn();
    } catch (error) {
      await AnalyticsService.logAuthAction(
        action: 'apple_sign_in',
        success: false,
      );
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

  bool _isLocalReviewEmail(String value) {
    return value.toLowerCase() == AppController.localReviewEmail;
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
    context.read<AppController>().refreshAuthState();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (_) => false,
    );
  }
}

class _LoginSupportTile extends StatelessWidget {
  const _LoginSupportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = accentColor ?? theme.colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.north_west_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginSupportDivider extends StatelessWidget {
  const _LoginSupportDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: color.withValues(alpha: 0.18),
    );
  }
}

class _LoginFooter extends StatelessWidget {
  const _LoginFooter({
    required this.version,
    required this.copyright,
  });

  final String version;
  final String copyright;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'v$version',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          copyright,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
