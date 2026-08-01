import 'package:flutter/widgets.dart';

import 'appliance_store.dart';

class AppScope extends InheritedNotifier<ApplianceStore> {
  const AppScope({
    super.key,
    required ApplianceStore applianceStore,
    required super.child,
  }) : super(notifier: applianceStore);

  static ApplianceStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found above this context.');
    return scope!.notifier!;
  }

  static ApplianceStore read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AppScope>();
    final scope = element?.widget as AppScope?;
    assert(scope != null, 'AppScope was not found above this context.');
    return scope!.notifier!;
  }
}
