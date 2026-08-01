import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/appliance.dart';

class ApplianceStore extends ChangeNotifier {
  final List<Appliance> _appliances = [];

  UnmodifiableListView<Appliance> get appliances =>
      UnmodifiableListView(_appliances);

  int get totalCount => _appliances.length;

  int warrantyCount(WarrantyStatus status, {DateTime? now}) {
    final referenceDate = now ?? DateTime.now();
    return _appliances
        .where((appliance) => appliance.warrantyStatusAt(referenceDate) == status)
        .length;
  }

  List<Appliance> get recentAppliances {
    final sorted = [..._appliances]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(3).toList(growable: false);
  }

  void add(Appliance appliance) {
    _appliances.add(appliance);
    notifyListeners();
  }

  void update(Appliance appliance) {
    final index = _appliances.indexWhere((item) => item.id == appliance.id);
    if (index == -1) {
      return;
    }
    _appliances[index] = appliance;
    notifyListeners();
  }

  void delete(String applianceId) {
    final previousLength = _appliances.length;
    _appliances.removeWhere((item) => item.id == applianceId);
    if (_appliances.length != previousLength) {
      notifyListeners();
    }
  }
}
