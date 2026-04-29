import 'dart:io';

void main() {
  final file = File('pubspec.yaml');

  if (!file.existsSync()) {
    stderr.writeln('Error: pubspec.yaml was not found.');
    exitCode = 1;
    return;
  }

  final content = file.readAsStringSync();
  final versionPattern = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
    multiLine: true,
  );
  final match = versionPattern.firstMatch(content);

  if (match == null) {
    stderr.writeln(
      'Error: Could not find a valid version line in pubspec.yaml. '
      'Expected format: version: x.y.z+n',
    );
    exitCode = 1;
    return;
  }

  final semanticVersion = match.group(1)!;
  final currentBuild = int.tryParse(match.group(2)!);

  if (currentBuild == null) {
    stderr.writeln('Error: Build number is not a valid integer.');
    exitCode = 1;
    return;
  }

  final nextBuild = currentBuild + 1;
  final oldVersion = '$semanticVersion+$currentBuild';
  final newVersion = '$semanticVersion+$nextBuild';
  final updatedContent = content.replaceFirst(
    versionPattern,
    'version: $newVersion',
  );

  file.writeAsStringSync(updatedContent);

  stdout.writeln('Updated app build version:');
  stdout.writeln('  Old: $oldVersion');
  stdout.writeln('  New: $newVersion');
  stdout.writeln('Run this before your production build.');
}
