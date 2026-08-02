import 'package:flutter/widgets.dart';

import 'profile_controller.dart';

class ProfileScope extends InheritedNotifier<ProfileController> {
  const ProfileScope({
    super.key,
    required ProfileController controller,
    required super.child,
  }) : super(notifier: controller);

  static ProfileController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ProfileScope>();
    assert(scope != null, 'ProfileScope was not found above this context.');
    return scope!.notifier!;
  }

  static ProfileController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<ProfileScope>();
    final scope = element?.widget as ProfileScope?;
    assert(scope != null, 'ProfileScope was not found above this context.');
    return scope!.notifier!;
  }
}
