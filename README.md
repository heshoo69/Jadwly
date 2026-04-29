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
