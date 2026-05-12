// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:jadwly/main.dart';
import 'package:jadwly/services/storage_service.dart';

void main() {
  testWidgets('Jadwly shows Arabic home tab', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tempDir = await Directory.systemTemp.createTemp('jadwly_test_');
    await StorageService.init(testPath: tempDir.path);

    await tester.pumpWidget(const JadwaliApp());
    await tester.pump();

    expect(find.text('جدولي'), findsOneWidget);
    expect(find.text('Jadwly'), findsOneWidget);

    await Hive.close();
    await tempDir.delete(recursive: true);
  });
}
