import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/state/appliance_store.dart';

class _DelayedOwnerRepository
    implements ApplianceRepository, OwnerScopedApplianceRepository {
  final Completer<void> bindRelease = Completer<void>();

  int bindCalls = 0;
  int loadCalls = 0;
  String? _ownerUid;

  @override
  String? get ownerUid => _ownerUid;

  @override
  Future<void> bindOwner(String? uid) async {
    bindCalls += 1;
    _ownerUid = uid;
    await bindRelease.future;
  }

  @override
  Future<List<Appliance>> loadAppliances() async {
    loadCalls += 1;
    return const [];
  }

  @override
  Future<void> saveAppliances(List<Appliance> appliances) async {}
}

void main() {
  test(
    'same owner bind is coalesced while startup binding is in progress',
    () async {
      final repository = _DelayedOwnerRepository();
      final store = ApplianceStore(repository: repository);
      addTearDown(store.dispose);

      final firstBind = store.bindOwner('user-1');
      final secondBind = store.bindOwner('user-1');

      await Future<void>.delayed(Duration.zero);
      expect(repository.bindCalls, 1);

      repository.bindRelease.complete();
      await Future.wait([firstBind, secondBind]);

      expect(repository.bindCalls, 1);
      expect(repository.loadCalls, 1);
      expect(store.ownerUid, 'user-1');
      expect(store.isLoading, isFalse);
      expect(store.isInitialized, isTrue);
    },
  );
}
