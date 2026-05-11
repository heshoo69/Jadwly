import 'package:flutter_test/flutter_test.dart';

import 'package:jadwly/l10n/app_strings.dart';

void main() {
  test('Arabic app strings expose the Jadwali brand', () {
    const strings = AppStrings('ar');

    expect(strings.appName, 'جدولي');
    expect(strings.settings, 'الإعدادات');
  });
}
