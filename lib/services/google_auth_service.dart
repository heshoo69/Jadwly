import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/google_auth_config.dart';

class GoogleAuthService {
  GoogleAuthService({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? Supabase.instance.client;

  final SupabaseClient _supabaseClient;

  Future<bool> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      scopes: GoogleAuthConfig.scopes,
      serverClientId: GoogleAuthConfig.webClientId,
      clientId: _shouldUseIosClientId ? GoogleAuthConfig.iosClientId : null,
    );

    try {
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return false;

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleAuthException(
          'لم يتم استلام رمز Google ID. حاول مرة أخرى.',
        );
      }
      if (accessToken == null || accessToken.isEmpty) {
        throw const GoogleAuthException(
          'لم يتم استلام رمز الوصول من Google. حاول مرة أخرى.',
        );
      }

      await _supabaseClient.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      return true;
    } on GoogleAuthException {
      rethrow;
    } on PlatformException catch (error, stackTrace) {
      _debugLog(error, stackTrace);
      if (_isCancellation(error)) return false;
      throw const GoogleAuthException(
        'تعذر تسجيل الدخول بحساب Google. حاول مرة أخرى.',
      );
    } on AuthException catch (error, stackTrace) {
      _debugLog(error, stackTrace);
      throw GoogleAuthException(
        'فشل تسجيل الدخول عبر Supabase: ${error.message}',
      );
    } catch (error, stackTrace) {
      _debugLog(error, stackTrace);
      throw const GoogleAuthException(
        'تعذر تسجيل الدخول بحساب Google. تحقق من الاتصال وإعدادات Google.',
      );
    }
  }

  bool get _shouldUseIosClientId {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool _isCancellation(PlatformException error) {
    return error.code == GoogleSignIn.kSignInCanceledError ||
        error.code == 'sign_in_canceled';
  }

  void _debugLog(Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      debugPrint('Google sign-in failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
