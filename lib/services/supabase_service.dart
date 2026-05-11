import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static const _supabaseUrl = 'https://ttdrmqxwazzoauzdyyvt.supabase.co';
  static const _supabasePublishableKey =
      'sb_publishable_eEabaLo1lgFjEYGppNRaFQ_KMtg0FoT';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabasePublishableKey,
    );

    // Deep link scheme is configured in AndroidManifest.xml and Info.plist:
    // jadwali://login-callback
    // Never put a service_role key in the app.
    // TODO: Add jadwali://login-callback to Supabase redirect URLs.
    // TODO: Enable Google and Apple auth providers in Supabase.
  }
}
