import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase is not configured for web. Configure FlutterFire before '
        'running on web.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        throw UnsupportedError(
          'Firebase is not configured for Android. Add google-services.json '
          'or run FlutterFire configure for com.hafdev.jadwly.',
        );
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Firebase is only configured for iOS in this project.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC__vRDuBfrisX3loM_SP-mAl1pNT2hyKI',
    appId: '1:678126722694:ios:52dbe86ef55b22ad457b07',
    messagingSenderId: '678126722694',
    projectId: 'jadwly-7eee2',
    storageBucket: 'jadwly-7eee2.firebasestorage.app',
    iosBundleId: 'com.hafdev.jadwly',
  );
}
