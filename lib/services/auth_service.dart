import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'google_auth_service.dart';
import 'supabase_service.dart';

class AuthService {
  AuthService({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? Supabase.instance.client;

  final SupabaseClient _supabaseClient;

  static AuthService? get instanceOrNull {
    final client = SupabaseService.clientOrNull;
    if (client == null) return null;
    return AuthService(supabaseClient: client);
  }

  User? get currentUser => _supabaseClient.auth.currentUser;
  Session? get currentSession => _supabaseClient.auth.currentSession;
  Stream<AuthState> get authStateChanges =>
      _supabaseClient.auth.onAuthStateChange;

  Future<void> sendEmailOtp(String email) {
    return _supabaseClient.auth.signInWithOtp(email: email.trim());
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String token,
  }) {
    return _supabaseClient.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
  }

  Future<bool> signInWithGoogle() {
    return GoogleAuthService(supabaseClient: _supabaseClient)
        .signInWithGoogle();
  }

  Future<void> signInWithApple() async {
    final rawNonce = _supabaseClient.auth.generateRawNonce();
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

    await _supabaseClient.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: identityToken,
      nonce: rawNonce,
    );

    final fullName =
        '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim();
    if (fullName.isNotEmpty) {
      await _supabaseClient.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': fullName,
            'given_name': credential.givenName,
            'family_name': credential.familyName,
          },
        ),
      );
    }
  }

  Future<void> signOut() {
    return _supabaseClient.auth.signOut();
  }
}
