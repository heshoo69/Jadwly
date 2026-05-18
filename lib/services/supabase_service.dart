import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static const supabaseUrl = 'https://ttdrmqxwazzoauzdyyvt.supabase.co';
  static const supabasePublishableKey =
      'sb_publishable_eEabaLo1lgFjEYGppNRaFQ_KMtg0FoT';

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static SupabaseClient? get clientOrNull {
    if (!_initialized) return null;
    return Supabase.instance.client;
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabasePublishableKey,
    );
    _initialized = true;

    // Deep link callbacks are configured as jadwali://login-callback.
    // Never put a service_role key in the client app.
  }
}
