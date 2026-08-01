import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/appliance.dart';
import '../services/appliance_repository.dart';

class ApplianceStore extends ChangeNotifier {
  ApplianceStore({ApplianceRepository? repository})
      : _repository = repository ?? FileApplianceRepository();

  final ApplianceRepository _repository;
  List<Appliance> _appliances = [];
  bool _isLoading = true;
  bool _isInitialized = false;
  String? _loadError;
  Future<void>? _initialization;

  UnmodifiableListView<Appliance> get appliances =>
      UnmodifiableListView(_appliances);

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get loadError => _loadError;
  int get totalCount => _appliances.length;

  Appliance? applianceById(String applianceId) {
    for (final appliance in _appliances) {
      if (appliance.id == applianceId) {
        return appliance;
      }
    }
    return null;
  }

  Future<void> initialize({bool force = false}) {
    if (_initialization != null) {
      return _initialization!;
    }
    if (_isInitialized && !force) {
      return Future.value();
    }

    _initialization = _load();
    return _initialization!;
  }

  Future<void> _load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      _appliances = await _repository.loadAppliances();
      _isInitialized = true;
    } catch (error) {
      _loadError = error.toString();
      _isInitialized = false;
    } finally {
      _isLoading = false;
      _initialization = null;
      notifyListeners();
    }
  }

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

  Future<void> add(Appliance appliance) async {
    final updated = [..._appliances, appliance];
    await _repository.saveAppliances(updated);
    _appliances = updated;
    notifyListeners();
  }

  Future<void> update(Appliance appliance) async {
    final index = _appliances.indexWhere((item) => item.id == appliance.id);
    if (index == -1) {
      throw StateError('The appliance could not be found.');
    }

    final updated = [..._appliances];
    updated[index] = appliance;
    await _repository.saveAppliances(updated);
    _appliances = updated;
    notifyListeners();
  }

  Future<void> delete(String applianceId) async {
    final updated = _appliances
        .where((item) => item.id != applianceId)
        .toList(growable: false);

    if (updated.length == _appliances.length) {
      return;
    }

    await _repository.saveAppliances(updated);
    _appliances = updated;
    notifyListeners();
  }
}
