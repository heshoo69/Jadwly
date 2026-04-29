import 'package:flutter/widgets.dart';

class BottomNavigationClearance extends InheritedWidget {
  const BottomNavigationClearance({
    super.key,
    required this.bottomPadding,
    this.fabOffset = 0,
    required super.child,
  });

  final double bottomPadding;
  final double? fabOffset;

  static double of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<BottomNavigationClearance>()
            ?.bottomPadding ??
        0;
  }

  static double forFab(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<BottomNavigationClearance>()
            ?.fabOffset ??
        0;
  }

  @override
  bool updateShouldNotify(BottomNavigationClearance oldWidget) {
    return bottomPadding != oldWidget.bottomPadding ||
        (fabOffset ?? 0) != (oldWidget.fabOffset ?? 0);
  }
}
