# jadwly

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Supabase Auth setup

The app uses a Supabase publishable key in `SupabaseService` for client auth.
Never put the `service_role` key in the app.

```bash
flutter run
```

If iOS builds are affected by:
`Target native_assets required define SdkRoot but it was not provided`

first collect a verbose log:

```bash
flutter clean
flutter pub get
flutter run -v
```

Do not disable native assets for this project while packages such as
`objective_c` require them. If you try disabling native assets and see
`Package(s) objective_c require the dart assets feature to be enabled`, restore
the default with:

```bash
flutter config --enable-native-assets
```

In Supabase Dashboard, also confirm:

- `jadwali://login-callback` is listed in Redirect URLs.
- Email OTP is enabled.
- Google and Apple providers are enabled before using those buttons.

For Apple Sign In, also enable the capability for the App ID
`com.hafdev.jadwly` in Apple Developer/Xcode. If the simulator returns
authorization error 1000, sign in to an Apple ID on the simulator or test on a
real iOS device.

For native iOS Apple Sign In, the Apple `id_token` audience is the Bundle ID:
`com.hafdev.jadwly`. If Supabase returns
`Unacceptable audience in id_token: [com.hafdev.jadwly]`, update Supabase
Dashboard -> Auth -> Providers -> Apple so the Apple provider accepts
`com.hafdev.jadwly` as the client ID / allowed Apple client ID for native iOS.
If you also use web OAuth, keep its Services ID and secret configured separately.

## Supabase database setup

Apply the migrations in `supabase/migrations` before testing schedule writes.
The app matches the current `weekly_schedule` schema shown in Supabase:
`class_name`, `room`, and Postgres `time` values for `start_time`/`end_time`.
The migration `20260501000000_match_weekly_schedule_schema.sql` only ensures
the `teacher_id` index exists and reloads the PostgREST schema cache.

## Release build number

Before every production build, run:

```bash
dart run tool/bump_build.dart
```

This safely increments the build number in `pubspec.yaml`, for example:
`1.0.0+1` -> `1.0.0+2`.

## App version in Settings

The Settings screen reads the app version dynamically from
`PackageInfo.fromPlatform()`. This reflects the version of the app bundle that
is currently installed on the device or simulator.

If you change `pubspec.yaml` from:
`version: 1.0.0+3`
to:
`version: 1.1.0+4`

the version inside the running app will not update immediately. To see the new
version in Settings, rebuild and reinstall the app:

```bash
flutter clean
flutter pub get
flutter run
```

If the old version still appears after a rebuild, delete the app from the
simulator or device, then run the app again.
