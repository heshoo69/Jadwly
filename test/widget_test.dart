import 'package:flutter_test/flutter_test.dart';
import 'package:jadwly/l10n/app_strings.dart';

void main() {
  test('Jadwly exposes Arabic and English app names', () {
    expect(const AppStrings('ar').appName, 'جدولي');
    expect(const AppStrings('en').appName, 'Jadwly');
  });
}
