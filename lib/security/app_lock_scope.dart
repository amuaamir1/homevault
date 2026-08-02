import 'package:flutter/widgets.dart';

import 'app_lock_controller.dart';

class AppLockScope extends InheritedNotifier<AppLockController> {
  const AppLockScope({
    super.key,
    required AppLockController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLockController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLockScope>();
    assert(scope != null, 'AppLockScope was not found above this context.');
    return scope!.notifier!;
  }

  static AppLockController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AppLockScope>();
    final scope = element?.widget as AppLockScope?;
    assert(scope != null, 'AppLockScope was not found above this context.');
    return scope!.notifier!;
  }
}
