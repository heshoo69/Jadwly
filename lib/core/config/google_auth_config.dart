class GoogleAuthConfig {
  GoogleAuthConfig._();

  static const webClientId =
      '225241958264-smihlkntjnn4shd4j4k9sa68alisfg09.apps.googleusercontent.com';

  static const iosClientId =
      '225241958264-2aaorhvpnv130d8mgecg1jaopa0a7si6.apps.googleusercontent.com';

  // Kept for configuration reference only. Android uses the package name,
  // SHA-1 fingerprint, and webClientId/serverClientId for this flow.
  static const androidClientId =
      '225241958264-35mfpq93c6tk2nhjpadjqrdq0b9f0dhb.apps.googleusercontent.com';

  static const scopes = <String>[
    'email',
    'profile',
  ];
}
